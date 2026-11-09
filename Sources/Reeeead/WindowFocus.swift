import AppKit
import ApplicationServices
import Combine
import QuartzCore

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
    private var panels: [RulerPanel] = []
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var lastRect: CGRect?
    private var cornerRadius: CGFloat = 12
    private var axObserver: AXObserver?
    private var trackedApp: AXUIElement?
    private var trackedWindow: AXUIElement?
    private var trackedPID: pid_t?
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
        guard let rect = focusedWindowRect(reselect: true) else {
            clearTracking()
            onMessage?(L("未能读取当前窗口，请切换到要阅读的窗口后重试。")); return
        }
        for screen in NSScreen.screens {
            let panel = RulerPanel(screenFrame: screen.frame)
            panel.ignoresMouseEvents = true
            panel.acceptsMouseMovedEvents = false
            panel.contentView = WindowFocusCanvas(frame: NSRect(origin: .zero, size: screen.frame.size), opacity: opacity)
            panels.append(panel)
        }
        active = true
        render(rect)
        // Notifications handle normal changes; a low-rate fallback covers apps
        // with incomplete AX support. Fast polling exists only during a mouse press.
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.requestRefresh(reselect: true)
        }
        timer.tolerance = 0.025
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
        installMouseMonitoring()
        onMessage?(L("窗口聚焦已开启。自动跟随当前窗口，Esc 退出。"))
    }
    func updateOpacity(_ opacity: Double) {
        for panel in panels {
            (panel.contentView as? WindowFocusCanvas)?.opacity = opacity
        }
    }
    func updateCornerRadius(_ radius: CGFloat) {
        cornerRadius = radius
        if let rect = lastRect { lastRect = nil; render(rect) }
    }
    func stop() {
        timer?.invalidate(); timer = nil
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
        guard let rect = focusedWindowRect(reselect: reselect) else {
            // Never leave an opaque desktop or a stale hole over another app.
            for panel in panels { panel.orderOut(nil) }
            lastRect = nil
            return
        }
        render(rect)
    }
    private func render(_ rect: CGRect) {
        guard rect != lastRect else { return }
        lastRect = rect
        for panel in panels {
            guard let canvas = panel.contentView as? WindowFocusCanvas else { continue }
            let fillsScreen = abs(rect.minX - panel.frame.minX) < 1 && abs(rect.minY - panel.frame.minY) < 1 && abs(rect.width - panel.frame.width) < 1 && abs(rect.height - panel.frame.height) < 1
            canvas.cornerRadius = fillsScreen ? 0 : cornerRadius
            canvas.cutout = WindowFocusGeometry.cutout(window: rect, screen: panel.frame)
            canvas.updateShape()
            if !panel.isVisible { panel.orderFrontRegardless() }
        }
    }
    private func installMouseMonitoring() {
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in self?.mouseEvent(event) }) { mouseMonitors.append(global) }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in self?.mouseEvent(event); return event }) { mouseMonitors.append(local) }
    }
    private func mouseEvent(_ event: NSEvent) {
        guard active else { return }
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
        axObserver = nil; trackedApp = nil; trackedWindow = nil; trackedPID = nil
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
        if reselect || trackedWindow == nil {
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &value) == .success,
                  let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { trackedWindow = nil; return nil }
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
        return WindowFocusGeometry.appKitRect(CGRect(origin: point, size: size), primaryHeight: primary.frame.height)
    }
    deinit {
        timer?.invalidate(); dragTimer?.invalidate(); scheduledRefresh?.cancel()
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
    var cornerRadius: CGFloat = 12
    var opacity: Double {
        didSet { needsDisplay = true; updateShape() }
    }
    override var wantsUpdateLayer: Bool { true }
    override func makeBackingLayer() -> CALayer { CAShapeLayer() }
    init(frame: NSRect, opacity: Double) {
        self.opacity = min(1, max(0, opacity))
        super.init(frame: frame)
        wantsLayer = true
        setAccessibilityElement(false)
        updateShape()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    func maskPath() -> CGPath {
        let path = CGMutablePath()
        path.addRect(bounds)
        if let cutout {
            let radius = min(max(0, cornerRadius), min(cutout.width, cutout.height) / 2)
            path.addRoundedRect(in: cutout, cornerWidth: radius, cornerHeight: radius)
        }
        return path
    }
    func updateShape() {
        guard let shape = layer as? CAShapeLayer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shape.masksToBounds = true
        shape.fillRule = .evenOdd
        shape.fillColor = NSColor.black.withAlphaComponent(min(1, max(0, opacity))).cgColor
        shape.path = maskPath()
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
