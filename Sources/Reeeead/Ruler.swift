import AppKit
import Combine

final class RulerPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init(screenFrame: NSRect) {
        super.init(contentRect: screenFrame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        isMovable = false
        ignoresMouseEvents = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        acceptsMouseMovedEvents = true
    }
}

final class RulerController: ObservableObject {
    @Published private(set) var active = false
    @Published private(set) var locked = false
    var onMessage: ((String) -> Void)?
    private var panel: RulerPanel?
    private var canvas: RulerCanvas?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var observers: [NSObjectProtocol] = []

    init() {
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in self?.stop() })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in self?.stop() })
    }
    func toggle(preferences: Preferences) {
        if active { stop(); return }
        start(preferences: preferences)
    }
    func start(preferences: Preferences) {
        guard !active else { return }
        guard installEscapeTap() else {
            onMessage?(L("标尺需要辅助功能权限，以便在任何应用中按 Esc 退出。请在「快捷键」页开启权限。"))
            return
        }
        let point = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) }) ?? NSScreen.main else { removeTap(); return }
        let panel = RulerPanel(screenFrame: screen.frame)
        let canvas = RulerCanvas(frame: NSRect(origin: .zero, size: screen.frame.size), preferences: preferences)
        canvas.geometry.move(to: screen.frame.maxY - point.y)
        canvas.onLock = { [weak self, weak panel, weak canvas] in
            // Called on mouse UP: the positioning click must not leak to the underlying app.
            panel?.ignoresMouseEvents = true
            if let canvas { panel?.invalidateCursorRects(for: canvas) }
            NSCursor.arrow.set()
            self?.locked = true
            self?.onMessage?(L("阅读区域已固定。正常滚动文档，按 Esc 或标尺快捷键退出。"))
        }
        panel.contentView = canvas
        self.panel = panel; self.canvas = canvas
        active = true; locked = false
        panel.orderFrontRegardless()
        onMessage?(L("点击确定上边界，再向下移动，点击固定下边界。Esc 随时退出。"))
    }
    func stop() {
        panel?.orderOut(nil)
        panel?.contentView = nil
        canvas?.onLock = nil
        panel = nil; canvas = nil
        removeTap()
        let wasActive = active
        active = false; locked = false
        NSCursor.arrow.set()
        if wasActive { onMessage?(L("标尺已收起。")) }
    }
    private func installEscapeTap() -> Bool {
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask, callback: { _, type, event, info in
            guard let info else { return Unmanaged.passUnretained(event) }
            let controller = Unmanaged<RulerController>.fromOpaque(info).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = controller.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                return Unmanaged.passUnretained(event)
            }
            if type == .keyDown && event.getIntegerValueField(.keyboardEventKeycode) == 53 && Shortcut.modifiers(from: event.flags) == 0 && controller.active {
                DispatchQueue.main.async { controller.stop() }
                return nil
            }
            return Unmanaged.passUnretained(event)
        }, userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let tap else { return false }
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }
    private func removeTap() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil; source = nil
    }
    deinit {
        removeTap()
        for o in observers { NotificationCenter.default.removeObserver(o); NSWorkspace.shared.notificationCenter.removeObserver(o) }
    }
}

final class RulerCanvas: NSView {
    var geometry: RulerGeometry
    let preferences: Preferences
    var onLock: (() -> Void)?
    private var area: NSTrackingArea?
    private var pendingLock = false
    override var isFlipped: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
    init(frame: NSRect, preferences: Preferences) {
        geometry = RulerGeometry(height: frame.height)
        self.preferences = preferences
        super.init(frame: frame)
        setAccessibilityElement(false)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area { removeTrackingArea(area) }
        let new = NSTrackingArea(rect: bounds, options: [.activeAlways, .mouseMoved, .inVisibleRect], owner: self, userInfo: nil)
        area = new; addTrackingArea(new)
    }
    override func resetCursorRects() {
        if geometry.phase != .locked {
            let image = NSImage(size: NSSize(width: 1, height: 1))
            addCursorRect(bounds, cursor: NSCursor(image: image, hotSpot: .zero))
        }
    }
    override func mouseMoved(with event: NSEvent) {
        geometry.move(to: convert(event.locationInWindow, from: nil).y)
        needsDisplay = true
    }
    override func mouseDown(with event: NSEvent) {
        pendingLock = geometry.click(at: convert(event.locationInWindow, from: nil).y)
        needsDisplay = true
    }
    override func mouseUp(with event: NSEvent) {
        if pendingLock { pendingLock = false; onLock?(); needsDisplay = true }
    }
    override func rightMouseDown(with event: NSEvent) {}
    override func scrollWheel(with event: NSEvent) {} // Only consumes scrolling while placing boundaries.
    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill(); bounds.fill(using: .copy)
        // WindowServer hit testing skips fully transparent pixels. Keep a nearly
        // invisible surface across the display until the second click is released.
        // The locked band is truly clear and the panel then explicitly passes input through.
        if geometry.phase != .locked || pendingLock {
            NSColor.black.withAlphaComponent(0.01).setFill()
            bounds.fill()
        }
        let line = preferences.lineColor == "amber" ? NSColor(red: 0.91, green: 0.57, blue: 0.29, alpha: 1) : NSColor(red: 0.68, green: 0.84, blue: 0.62, alpha: 1)
        if geometry.phase != .tracking {
            NSColor.black.withAlphaComponent(preferences.dimOpacity).setFill()
            NSRect(x: 0, y: 0, width: bounds.width, height: geometry.anchor).fill()
            NSRect(x: 0, y: geometry.cursor, width: bounds.width, height: max(0, bounds.height - geometry.cursor)).fill()
        }
        NSGraphicsContext.current?.shouldAntialias = false
        line.setFill()
        func drawLine(_ y: CGFloat) {
            NSRect(x: 0, y: round(y), width: bounds.width, height: preferences.lineWidth).fill()
            NSRect(x: 16, y: round(y) - 3, width: 6, height: 8).fill()
            NSRect(x: bounds.width - 22, y: round(y) - 3, width: 6, height: 8).fill()
        }
        if geometry.phase != .tracking { drawLine(geometry.anchor) }
        drawLine(geometry.cursor)
        NSGraphicsContext.current?.shouldAntialias = true
        if geometry.phase != .locked {
            let title = geometry.phase == .tracking ? L("① 点击固定上边界   ·   Esc 退出") : L("② 向下移动，点击固定下边界   ·   Esc 退出")
            let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13, weight: .medium), .foregroundColor: NSColor.white]
            let size = (title as NSString).size(withAttributes: attrs)
            let y = geometry.cursor > bounds.height - 65 ? geometry.cursor - 48 : geometry.cursor + 20
            let rect = NSRect(x: (bounds.width - size.width) / 2 - 16, y: max(8, y), width: size.width + 32, height: 32)
            NSColor(red: 0.12, green: 0.19, blue: 0.15, alpha: 0.96).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6).fill()
            (title as NSString).draw(at: NSPoint(x: rect.minX + 16, y: rect.minY + 7), withAttributes: attrs)
        }
    }
}
