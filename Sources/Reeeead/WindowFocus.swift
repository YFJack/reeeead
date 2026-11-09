import AppKit
import ApplicationServices
import Combine

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
        return intersection.offsetBy(dx: -screen.minX, dy: -screen.minY)
    }
}

final class WindowFocusController: ObservableObject {
    @Published private(set) var active = false
    var onMessage: ((String) -> Void)?
    private var panels: [RulerPanel] = []
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var lastRect: CGRect?

    init() {
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in self?.stop() })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in self?.stop() })
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.activeSpaceDidChangeNotification] {
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                guard let self, self.active else { return }
                self.refresh()
            })
        }
    }
    func start(opacity: Double) {
        guard !active else { return }
        guard AXIsProcessTrusted() else {
            onMessage?(L("窗口聚焦需要辅助功能权限。请在「快捷键」页开启权限。")); return
        }
        guard let rect = focusedWindowRect() else {
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
        // Poll only while enabled. This covers moves/resizes and same-app window
        // switches, including applications that don't emit reliable AX notifications.
        let timer = Timer(timeInterval: 0.15, repeats: true) { [weak self] _ in self?.refresh() }
        timer.tolerance = 0.04
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
        onMessage?(L("窗口聚焦已开启。自动跟随当前窗口，Esc 退出。"))
    }
    func updateOpacity(_ opacity: Double) {
        for panel in panels {
            (panel.contentView as? WindowFocusCanvas)?.opacity = opacity
        }
    }
    func stop() {
        timer?.invalidate(); timer = nil
        for panel in panels { panel.orderOut(nil); panel.contentView = nil }
        panels.removeAll(); lastRect = nil
        let wasActive = active
        active = false
        if wasActive { onMessage?(L("窗口聚焦已收起。")) }
    }
    private func refresh() {
        guard active else { return }
        guard AXIsProcessTrusted() else { stop(); return }
        guard let rect = focusedWindowRect() else {
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
            canvas.cutout = WindowFocusGeometry.cutout(window: rect, screen: panel.frame)
            canvas.needsDisplay = true
            panel.orderFrontRegardless()
        }
    }
    private func focusedWindowRect() -> CGRect? {
        guard let front = NSWorkspace.shared.frontmostApplication, !front.isTerminated,
              let primary = NSScreen.screens.first else { return nil }
        let app = AXUIElementCreateApplication(front.processIdentifier)
        // A stalled target must not block the overlay's escape key indefinitely.
        AXUIElementSetMessagingTimeout(app, 0.05)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        let window = unsafeBitCast(value, to: AXUIElement.self)
        AXUIElementSetMessagingTimeout(window, 0.05)
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
        timer?.invalidate()
        for panel in panels { panel.orderOut(nil) }
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
}

final class WindowFocusCanvas: NSView {
    var cutout: CGRect?
    var opacity: Double {
        didSet { needsDisplay = true }
    }
    init(frame: NSRect, opacity: Double) {
        self.opacity = min(1, max(0, opacity))
        super.init(frame: frame)
        setAccessibilityElement(false)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill(); bounds.fill(using: .copy)
        let path = NSBezierPath(rect: bounds)
        if let cutout { path.appendRect(cutout) }
        path.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(min(1, max(0, opacity))).setFill()
        path.fill()
    }
}
