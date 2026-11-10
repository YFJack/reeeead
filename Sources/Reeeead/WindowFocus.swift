import AppKit
import ApplicationServices
import Combine
import QuartzCore
import SwiftUI

// AX uses a top-left origin on the primary display, including negative
// coordinates for displays above or to the left. AppKit uses bottom-left.
enum WindowFocusGeometry {
    static func appKitRect(_ rect: CGRect, primaryHeight: CGFloat) -> CGRect? {
        guard [rect.minX, rect.minY, rect.width, rect.height, primaryHeight].allSatisfy(\.isFinite),
              rect.width > 0, rect.height > 0 else { return nil }
        return CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }
    static func cutout(window: CGRect, screen: CGRect) -> CGRect? {
        let intersection = window.intersection(screen)
        guard !intersection.isNull, !intersection.isEmpty else { return nil }
        // Preserve the entire rounded rectangle; the view clips it at display edges.
        // Rounding an intersection would create false corners between displays.
        return window.offsetBy(dx: -screen.minX, dy: -screen.minY)
    }
}

final class WindowFocusController: ObservableObject {
    @Published private(set) var active = false
    var onMessage: ((String) -> Void)?
    @Published private(set) var locked = false
    @Published private(set) var addingWindow = false
    @Published private(set) var cycleState = FocusCycle.Snapshot()
    @Published private(set) var brightness = 0.38
    @Published private(set) var dailyGoal = max(1, min(20, UserDefaults.standard.object(forKey: "focus.dailyGoal") as? Int ?? 10))
    @Published private(set) var completedToday = 0
    @Published private(set) var completionEvent = 0
    var onBrightnessChange: ((Double) -> Void)?
    private var creditedRounds = 0
    private var cycleWallStart = Date()
    private var selectedWindows: Set<CGWindowID> = []
    private var pendingAdd = false
    private var lastRegions: [FocusRegion] = []
    private var controls: FocusControlsPanel?
    private var cycle = FocusCycle()
    private var cycleTimer: Timer?
    private var panels: [RulerPanel] = []
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var lastRect: CGRect?
    private var cornerRadius: CGFloat = 12
    private var axObserver: AXObserver?
    private var trackedApp: AXUIElement?
    private var trackedWindow: AXUIElement?
    private var trackedPID: pid_t?
    private var trackedWindowID: CGWindowID?
    private var mouseMonitors: [Any] = []
    private var dragTimer: Timer?
    private var scheduledRefresh: DispatchWorkItem?
    private var lastRefresh: CFTimeInterval = 0
    private var needsReselect = false

    init() {
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in self?.stop() })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in self?.stop() })
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.activeSpaceDidChangeNotification] {
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                guard let self, self.active else { return }
                self.requestRefresh(reselect: true)
            })
        }
    }
    func start(opacity: Double, cornerRadius: CGFloat = 12) {
        guard !active else { return }
        guard AXIsProcessTrusted() else {
            onMessage?(L("窗口聚焦需要辅助功能权限。请在「快捷键」页开启权限。")); return
        }
        self.cornerRadius = cornerRadius
        brightness = 1 - opacity
        completionEvent = 0
        refreshDailyCount()
        guard let rect = focusedWindowRect(reselect: true) else {
            clearTracking()
            onMessage?(L("未能读取当前窗口，请切换到要阅读的窗口后重试。")); return
        }
        for screen in NSScreen.screens {
            let panel = RulerPanel(screenFrame: screen.frame)
            panel.ignoresMouseEvents = true
            panel.setAccessibilityElement(false)
            panel.acceptsMouseMovedEvents = false
            panel.contentView = WindowFocusCanvas(frame: NSRect(origin: .zero, size: screen.frame.size), opacity: opacity)
            panels.append(panel)
        }
        active = true
        let controls = FocusControlsPanel()
        controls.contentView = NSHostingView(rootView: FocusFloatingControls(controller: self))
        self.controls = controls
        render(rect)
        // Notifications handle normal changes; a low-rate fallback covers apps
        // with incomplete AX support. Fast polling exists only during a mouse press.
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.refreshDailyCount()
            self.requestRefresh(reselect: self.dragTimer == nil)
        }
        timer.tolerance = 0.025
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
        installMouseMonitoring()
        onMessage?(L("窗口聚焦已开启。自动跟随当前窗口，Esc 退出。"))
    }
    func toggleLock() {
        guard active else { return }
        if locked {
            locked = false; addingWindow = false; pendingAdd = false
            selectedWindows.removeAll()
            onMessage?(L("已恢复跟随当前窗口。"))
            requestRefresh(reselect: true)
        } else if pinCurrentWindow() {
            locked = true; onMessage?(L("高亮窗口已锁定。")); requestRefresh()
        }
    }
    func toggleAdding() {
        if addingWindow { addingWindow = false; pendingAdd = false; onMessage?(L("已取消添加窗口。")); return }
        if !locked {
            guard pinCurrentWindow() else { return }
            locked = true
        }
        addingWindow = true
        onMessage?(L("点击要添加的窗口。Esc 取消添加。"))
    }
    func handleEscape() {
        if addingWindow { addingWindow = false; pendingAdd = false; onMessage?(L("已取消添加窗口。")) }
        else { stop() }
    }
    private func pinCurrentWindow() -> Bool {
        guard let rect = focusedWindowRect(reselect: true), let pid = trackedPID,
              let primary = NSScreen.screens.first else { return false }
        let candidate = FocusWindowInfo.matching(pid: pid, rect: rect,
            windows: FocusWindowInfo.visibleWindows(primaryHeight: primary.frame.height))
        guard let candidate else {
            onMessage?(L("未能读取当前窗口，请切换到要阅读的窗口后重试。")); return false
        }
        selectedWindows.insert(candidate.id)
        return true
    }
    func toggleCycle() {
        guard active else { return }
        if cycle.startedAt != nil {
            updateCycle()
            cycle.stop(); cycleTimer?.invalidate(); cycleTimer = nil
        } else {
            creditedRounds = 0
            cycleWallStart = Date()
            cycle.start(at: ProcessInfo.processInfo.systemUptime)
            let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.updateCycle() }
            timer.tolerance = 0.05
            cycleTimer = timer
            RunLoop.main.add(timer, forMode: .common)
        }
        updateCycle()
    }
    private func updateCycle() {
        let now = ProcessInfo.processInfo.systemUptime
        let total = cycle.completions(at: now)
        if total > creditedRounds {
            for round in creditedRounds..<total {
                let date = cycleWallStart.addingTimeInterval(Double(round * 1800 + 1500))
                let key = dailyKey(date)
                UserDefaults.standard.set(UserDefaults.standard.integer(forKey: key) + 1, forKey: key)
            }
            creditedRounds = total
            completionEvent += 1
        }
        refreshDailyCount()
        let next = cycle.snapshot(at: now)
        if next.phase != cycleState.phase {
            for panel in panels { (panel.contentView as? WindowFocusCanvas)?.setResting(next.phase == .rest) }
        }
        cycleState = next
    }
    private func dailyKey(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "focus.completed.\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }
    private func refreshDailyCount() {
        let count = UserDefaults.standard.integer(forKey: dailyKey(Date()))
        if completedToday != count { completedToday = count }
    }
    func setDailyGoal(_ count: Int) {
        dailyGoal = max(1, min(20, count))
        UserDefaults.standard.set(dailyGoal, forKey: "focus.dailyGoal")
    }
    func setBrightness(_ value: Double) {
        let value = min(1, max(0, value))
        updateOpacity(1 - value)
        onBrightnessChange?(value)
    }
    func updateOpacity(_ opacity: Double) {
        brightness = 1 - opacity
        for panel in panels {
            (panel.contentView as? WindowFocusCanvas)?.opacity = opacity
        }
    }
    func updateCornerRadius(_ radius: CGFloat) {
        cornerRadius = radius
        let regions = lastRegions; lastRegions = []; renderRegions(regions)
    }
    func stop() {
        if active { updateCycle() }
        timer?.invalidate(); timer = nil
        cycleTimer?.invalidate(); cycleTimer = nil; cycle.stop(); cycleState = .init()
        controls?.orderOut(nil); controls?.contentView = nil; controls = nil
        selectedWindows.removeAll(); locked = false; addingWindow = false; pendingAdd = false; lastRegions = []
        dragTimer?.invalidate(); dragTimer = nil
        scheduledRefresh?.cancel(); scheduledRefresh = nil
        needsReselect = false
        mouseMonitors.forEach { NSEvent.removeMonitor($0) }; mouseMonitors.removeAll()
        clearTracking()
        for panel in panels { panel.orderOut(nil); panel.contentView = nil }
        panels.removeAll(); lastRect = nil
        let wasActive = active
        active = false
        if wasActive { onMessage?(L("窗口聚焦已收起。")) }
    }
    private func requestRefresh(reselect: Bool = false) {
        guard active else { return }
        needsReselect = needsReselect || reselect
        guard scheduledRefresh == nil else { return }
        let delay = max(0, 1.0 / 60.0 - (CACurrentMediaTime() - lastRefresh))
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.scheduledRefresh = nil
            let reselect = self.needsReselect
            self.needsReselect = false
            self.refresh(reselect: reselect)
        }
        scheduledRefresh = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
    private func refresh(reselect: Bool) {
        guard active else { return }
        guard AXIsProcessTrusted() else { stop(); return }
        lastRefresh = CACurrentMediaTime()
        if pendingAdd {
            pendingAdd = false
            if pinCurrentWindow() { addingWindow = false; onMessage?(L("窗口已加入高亮。")) }
        }
        if locked, let primary = NSScreen.screens.first {
            let windows = FocusWindowInfo.visibleWindows(primaryHeight: primary.frame.height)
            renderRegions(FocusWindowInfo.regions(selected: selectedWindows, windows: windows))
            return
        }
        guard let rect = focusedWindowRect(reselect: reselect) else {
            // Never leave an opaque desktop or a stale hole over another app.
            for panel in panels { panel.orderOut(nil) }
            controls?.orderOut(nil)
            lastRect = nil; lastRegions = []
            return
        }
        render(rect)
    }
    private func render(_ rect: CGRect) {
        renderRegions([FocusRegion(rect: rect)])
    }
    private func renderRegions(_ regions: [FocusRegion]) {
        guard regions != lastRegions else { return }
        lastRegions = regions
        lastRect = regions.first?.rect
        guard !regions.isEmpty else {
            for panel in panels { panel.orderOut(nil) }
            // Keep the controls available to unlock or stop when all selected
            // windows are minimized, closed or on another Space.
            return
        }
        for panel in panels {
            guard let canvas = panel.contentView as? WindowFocusCanvas else { continue }
            canvas.cornerRadius = cornerRadius
            canvas.cutout = nil
            canvas.regions = regions.filter { $0.rect.intersects(panel.frame) }.map { $0.local(to: panel.frame) }
            canvas.updateShape()
            if !panel.isVisible { panel.orderFrontRegardless() }
        }
        if let anchor = regions.first?.rect,
           let screen = NSScreen.screens.max(by: { $0.frame.intersection(anchor).area < $1.frame.intersection(anchor).area }),
           let controls {
            let frame = FocusControlsPlacement.frame(window: anchor, screen: screen.visibleFrame)
            if controls.frame != frame { controls.setFrame(frame, display: true) }
            if !controls.isVisible { controls.orderFrontRegardless() }
        }
    }
    private func installMouseMonitoring() {
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in self?.mouseEvent(event) }) { mouseMonitors.append(global) }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in self?.mouseEvent(event); return event }) { mouseMonitors.append(local) }
    }
    private func mouseEvent(_ event: NSEvent) {
        guard active, event.window !== controls else { return }
        if addingWindow && event.type == .leftMouseUp { pendingAdd = true }
        requestRefresh(reselect: event.type == .leftMouseDown || event.type == .leftMouseUp)
        if event.type == .leftMouseUp {
            dragTimer?.invalidate(); dragTimer = nil
        } else if dragTimer == nil {
            let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
                guard let self else { return }
                if NSEvent.pressedMouseButtons & 1 == 0 {
                    self.dragTimer?.invalidate(); self.dragTimer = nil
                    self.requestRefresh(reselect: true)
                } else { self.requestRefresh() }
            }
            timer.tolerance = 0.001
            dragTimer = timer
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    private func clearTracking() {
        if let axObserver { CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(axObserver), .commonModes) }
        axObserver = nil; trackedApp = nil; trackedWindow = nil; trackedPID = nil; trackedWindowID = nil
    }
    private func track(_ pid: pid_t) {
        clearTracking()
        trackedPID = pid
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.01)
        trackedApp = app
        var observer: AXObserver?
        guard AXObserverCreate(pid, { _, _, name, context in
            guard let context else { return }
            let controller = Unmanaged<WindowFocusController>.fromOpaque(context).takeUnretainedValue()
            let reselect = name as String == kAXFocusedWindowChangedNotification || name as String == kAXMainWindowChangedNotification
            controller.requestRefresh(reselect: reselect)
        }, &observer) == .success, let observer else { return }
        axObserver = observer
        let context = Unmanaged.passUnretained(self).toOpaque()
        for name in [kAXFocusedWindowChangedNotification, kAXMainWindowChangedNotification] {
            AXObserverAddNotification(observer, app, name as CFString, context)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
    }
    private func focusedWindowRect(reselect: Bool) -> CGRect? {
        guard let front = NSWorkspace.shared.frontmostApplication, !front.isTerminated,
              let primary = NSScreen.screens.first else { return nil }
        if trackedPID != front.processIdentifier { track(front.processIdentifier) }
        guard let app = trackedApp else { return nil }
        // AX identifies the focused window; WindowServer supplies live geometry.
        // Avoid two synchronous cross-process AX requests on every drag frame.
        if !reselect, let id = trackedWindowID {
            let windows = FocusWindowInfo.visibleWindows(primaryHeight: primary.frame.height)
            if let live = windows.first(where: { $0.id == id && $0.pid == trackedPID }) {
                return live.rect
            }
            trackedWindowID = nil
        }
        if reselect || trackedWindow == nil {
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &value) == .success,
                  let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { trackedWindow = nil; trackedWindowID = nil; return nil }
            let next = unsafeBitCast(value, to: AXUIElement.self)
            if trackedWindow == nil || !CFEqual(trackedWindow!, next) {
                if let observer = axObserver {
                    let names = [kAXMovedNotification, kAXResizedNotification, kAXUIElementDestroyedNotification]
                    if let old = trackedWindow {
                        for name in names { AXObserverRemoveNotification(observer, old, name as CFString) }
                    }
                    for name in names { AXObserverAddNotification(observer, next, name as CFString, Unmanaged.passUnretained(self).toOpaque()) }
                }
                trackedWindow = next
                trackedWindowID = nil
                AXUIElementSetMessagingTimeout(next, 0.01)
            }
        }
        guard let window = trackedWindow else { return nil }
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionValue, let sizeValue,
              CFGetTypeID(positionValue) == AXValueGetTypeID(), CFGetTypeID(sizeValue) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(unsafeBitCast(positionValue, to: AXValue.self), .cgPoint, &point),
              AXValueGetValue(unsafeBitCast(sizeValue, to: AXValue.self), .cgSize, &size) else { return nil }
        guard let rect = WindowFocusGeometry.appKitRect(CGRect(origin: point, size: size), primaryHeight: primary.frame.height) else { return nil }
        let windows = FocusWindowInfo.visibleWindows(primaryHeight: primary.frame.height)
        trackedWindowID = FocusWindowInfo.matching(pid: front.processIdentifier, rect: rect, windows: windows)?.id
        return rect
    }
    deinit {
        timer?.invalidate(); dragTimer?.invalidate(); cycleTimer?.invalidate(); scheduledRefresh?.cancel()
        controls?.orderOut(nil)
        mouseMonitors.forEach { NSEvent.removeMonitor($0) }
        clearTracking()
        for panel in panels { panel.orderOut(nil) }
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
}

final class WindowFocusCanvas: NSView {
    var cutout: CGRect?
    var regions: [FocusRegion] = []
    private var resting = false
    private let glass = CAShapeLayer()
    private let glassHalo = CAShapeLayer()
    private let glassClips = [CAShapeLayer(), CAShapeLayer()]
    var cornerRadius: CGFloat = 12
    var opacity: Double {
        didSet { needsDisplay = true; updateShape(); configureBreathing() }
    }
    override var wantsUpdateLayer: Bool { true }
    override func makeBackingLayer() -> CALayer { CAShapeLayer() }
    init(frame: NSRect, opacity: Double) {
        self.opacity = min(1, max(0, opacity))
        super.init(frame: frame)
        wantsLayer = true
        for (index, style) in [(glassHalo, CGFloat(4), CGFloat(0.12)), (glass, CGFloat(0.9), CGFloat(0.75))].enumerated() {
            let (line, width, alpha) = style
            line.mask = glassClips[index]
            line.fillColor = nil; line.strokeColor = NSColor.white.withAlphaComponent(alpha).cgColor
            line.lineWidth = width; line.lineCap = .round; line.lineJoin = .round
            layer?.addSublayer(line)
        }
        setAccessibilityElement(false)
        updateShape()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    private var effectiveRegions: [FocusRegion] {
        regions.isEmpty ? cutout.map { [FocusRegion(rect: $0)] } ?? [] : regions
    }
    private func radius(for rect: CGRect) -> CGFloat {
        abs(rect.minX - bounds.minX) < 1 && abs(rect.minY - bounds.minY) < 1 && abs(rect.width - bounds.width) < 1 && abs(rect.height - bounds.height) < 1 ? 0 : cornerRadius
    }
    func visiblePath() -> CGPath? {
        var result: CGPath?
        for region in effectiveRegions {
            let path = region.visiblePath(radius: radius(for: region.rect))
            result = result.map { $0.union(path) } ?? path
        }
        return result
    }
    func maskPath() -> CGPath {
        let path = CGMutablePath()
        path.addRect(bounds)
        if let holes = visiblePath() { path.addPath(holes) }
        return path
    }
    private func cornerPath() -> CGPath {
        let result = CGMutablePath()
        for region in effectiveRegions {
            let rect = region.rect.insetBy(dx: 0.8, dy: 0.8)
            let length = min(28, min(rect.width, rect.height) / 3)
            guard length > 0 else { continue }
            let radius = min(max(0, radius(for: region.rect) - 0.8), length)
            let corner = CGMutablePath()
            corner.move(to: CGPoint(x: length, y: 0))
            if radius > 0 {
                corner.addLine(to: CGPoint(x: radius, y: 0))
                corner.addArc(tangent1End: .zero, tangent2End: CGPoint(x: 0, y: length), radius: radius)
            } else { corner.addLine(to: .zero) }
            corner.addLine(to: CGPoint(x: 0, y: length))
            let regionCorners = CGMutablePath()
            for (x, y, sx, sy) in [(rect.minX, rect.minY, CGFloat(1), CGFloat(1)), (rect.maxX, rect.minY, -1, 1), (rect.minX, rect.maxY, 1, -1), (rect.maxX, rect.maxY, -1, -1)] {
                let transform = CGAffineTransform(a: sx, b: 0, c: 0, d: sy, tx: x, ty: y)
                regionCorners.addPath(corner, transform: transform)
            }
            // Without occlusion these inset corner strokes already lie in the hole.
            // Skip the expensive path intersection for the common single-window case.
            if region.occluders.contains(where: { $0.intersects(region.rect) }) {
                result.addPath(regionCorners.lineIntersection(region.visiblePath(radius: self.radius(for: region.rect))))
            } else {
                result.addPath(regionCorners)
            }
        }
        return result
    }
    func setResting(_ value: Bool) {
        guard resting != value else { return }
        resting = value
        configureBreathing()
    }
    private func configureBreathing() {
        guard let shape = layer as? CAShapeLayer else { return }
        shape.removeAnimation(forKey: "restBreathing")
        let alpha = min(1, max(0, opacity))
        CATransaction.begin(); CATransaction.setDisableActions(true)
        shape.fillColor = NSColor.black.withAlphaComponent(resting && NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? alpha * 0.45 : alpha).cgColor
        CATransaction.commit()
        guard resting, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        let breath = CABasicAnimation(keyPath: "fillColor")
        breath.fromValue = NSColor.black.withAlphaComponent(alpha).cgColor
        breath.toValue = NSColor.black.withAlphaComponent(alpha * 0.22).cgColor
        breath.duration = 4; breath.autoreverses = true; breath.repeatCount = .infinity
        breath.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        shape.add(breath, forKey: "restBreathing")
    }
    func updateShape() {
        guard let shape = layer as? CAShapeLayer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shape.masksToBounds = true
        shape.fillRule = .evenOdd
        let alpha = min(1, max(0, opacity))
        shape.fillColor = NSColor.black.withAlphaComponent(resting && NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? alpha * 0.45 : alpha).cgColor
        let visible = visiblePath()
        let mask = CGMutablePath()
        mask.addRect(bounds)
        if let visible { mask.addPath(visible) }
        shape.path = mask
        let corners = cornerPath()
        for (line, clipping) in zip([glassHalo, glass], glassClips) {
            line.frame = bounds; line.path = corners
            clipping.frame = bounds; clipping.path = visible; clipping.fillColor = NSColor.white.cgColor
        }
        CATransaction.commit()
    }
    override func updateLayer() { updateShape() }
    override func layout() { super.layout(); updateShape() }
    // Same path for bitmap/export tests; live display uses the shape layer,
    // avoiding a full-screen bitmap repaint for every movement.
    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill(); bounds.fill(using: .copy)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.setFillColor(NSColor.black.withAlphaComponent(min(1, max(0, opacity))).cgColor)
        context.addPath(maskPath())
        context.drawPath(using: .eoFill)
    }
}

private extension CGRect {
    var area: CGFloat { isNull || isEmpty ? 0 : width * height }
}
