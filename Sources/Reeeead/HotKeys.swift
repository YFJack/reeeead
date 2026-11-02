import AppKit
import Carbon

final class HotKeyCenter {
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var handler: EventHandlerRef?
    private var mouseBindings: [UInt32: Shortcut] = [:]
    private var mouseTap: CFMachPort?
    var mouseTapReady: Bool { mouseTap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false }
    private var mouseSource: CFRunLoopSource?
    private var mouseRouter = MouseShortcutRouter()
    private var keyboardBindings: [UInt32: Shortcut] = [:]
    private var keyboardTap: CFMachPort?
    private var keyboardSource: CFRunLoopSource?
    private var keyboardRouter = KeyboardShortcutRouter()
    var keyboardTapReady: Bool { keyboardTap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false }
    private var generation = UUID()
    private(set) var registrationError = ""
    var onRead: (() -> Void)?
    var onRuler: (() -> Void)?
    private let signature: OSType = 0x4C554D41

    init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context -> OSStatus in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            guard status == noErr else { return status }
            let center = Unmanaged<HotKeyCenter>.fromOpaque(context).takeUnretainedValue()
            if id.id == 1 { center.onRead?() }
            if id.id == 2 { center.onRuler?() }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }
    func register(_ shortcut: Shortcut, id: UInt32) -> Bool {
        registrationError = ""
        if let button = shortcut.mouseButton {
            guard Shortcut.mouse(button: button, modifiers: shortcut.modifiers) != nil, installMouseTap() else {
                registrationError = L("鼠标快捷键需要辅助功能权限。开启后点「重新检查」。")
                return false
            }
            if let old = refs.removeValue(forKey: id) { UnregisterEventHotKey(old) }
            mouseBindings[id] = shortcut
            keyboardBindings.removeValue(forKey: id)
            return true
        }
        if shortcut.shiftSide != nil {
            guard installKeyboardTap() else {
                registrationError = L("区分左右 Shift 需要辅助功能权限。开启后点「重新检查」。")
                return false
            }
            if let old = refs.removeValue(forKey: id) { UnregisterEventHotKey(old) }
            keyboardBindings[id] = shortcut
            mouseBindings.removeValue(forKey: id)
            return true
        }
        var ref: EventHotKeyRef?
        let result = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, EventHotKeyID(signature: signature, id: id), GetApplicationEventTarget(), 0, &ref)
        guard result == noErr, let ref else {
            registrationError = L("快捷键被其他应用占用，请换一组。")
            return false
        }
        if let old = refs[id] { UnregisterEventHotKey(old) }
        refs[id] = ref
        mouseBindings.removeValue(forKey: id)
        keyboardBindings.removeValue(forKey: id)
        return true
    }
    private func installKeyboardTap() -> Bool {
        if let keyboardTap {
            CGEvent.tapEnable(tap: keyboardTap, enable: true)
            return keyboardTapReady
        }
        let mask = CGEventMask((1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue))
        keyboardTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: mask, callback: { _, type, event, info in
                guard let info else { return Unmanaged.passUnretained(event) }
                let center = Unmanaged<HotKeyCenter>.fromOpaque(info).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    center.keyboardRouter = KeyboardShortcutRouter()
                    if let tap = center.keyboardTap { CGEvent.tapEnable(tap: tap, enable: true) }
                    return Unmanaged.passUnretained(event)
                }
                guard type == .keyDown || type == .keyUp else { return Unmanaged.passUnretained(event) }
                let decision = center.keyboardRouter.route(keyCode: UInt32(event.getIntegerValueField(.keyboardEventKeycode)),
                    flags: event.flags, down: type == .keyDown, repeatKey: event.getIntegerValueField(.keyboardEventAutorepeat) != 0,
                    bindings: center.keyboardBindings)
                if let action = decision.action {
                    let generation = center.generation
                    DispatchQueue.main.async { [weak center] in
                        guard let center, center.generation == generation else { return }
                        if action == 1 { center.onRead?() }
                        if action == 2 { center.onRuler?() }
                    }
                }
                return decision.consume ? nil : Unmanaged.passUnretained(event)
            }, userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let keyboardTap else { return false }
        keyboardSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, keyboardTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), keyboardSource, .commonModes)
        CGEvent.tapEnable(tap: keyboardTap, enable: true)
        return keyboardTapReady
    }
    private func installMouseTap() -> Bool {
        if let mouseTap {
            CGEvent.tapEnable(tap: mouseTap, enable: true)
            return mouseTapReady
        }
        let mask = [CGEventType.leftMouseDown, .leftMouseUp, .leftMouseDragged,
                    .rightMouseDown, .rightMouseUp, .rightMouseDragged,
                    .otherMouseDown, .otherMouseUp, .otherMouseDragged].reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        mouseTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask, callback: { _, type, event, info in
            guard let info else { return Unmanaged.passUnretained(event) }
            let center = Unmanaged<HotKeyCenter>.fromOpaque(info).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = center.mouseTap { CGEvent.tapEnable(tap: tap, enable: true) }
                return Unmanaged.passUnretained(event)
            }
            let phase: MouseShortcutRouter.Phase
            switch type {
            case .leftMouseDown, .rightMouseDown, .otherMouseDown: phase = .down
            case .leftMouseUp, .rightMouseUp, .otherMouseUp: phase = .up
            case .leftMouseDragged, .rightMouseDragged, .otherMouseDragged: phase = .drag
            default: return Unmanaged.passUnretained(event)
            }
            let decision = center.mouseRouter.route(button: Int(event.getIntegerValueField(.mouseEventButtonNumber)), modifiers: Shortcut.modifiers(from: event.flags), phase: phase, bindings: center.mouseBindings, recording: false, shiftSide: ShiftSide.from(event.flags))
            if decision.action != nil {
                let generation = center.generation
                DispatchQueue.main.async { [weak center] in
                    guard let center, center.generation == generation else { return }
                    if decision.action == 1 { center.onRead?() }
                    else if decision.action == 2 { center.onRuler?() }
                }
            }
            return decision.consume ? nil : Unmanaged.passUnretained(event)
        }, userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let mouseTap else { return false }
        mouseSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, mouseTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), mouseSource, .commonModes)
        CGEvent.tapEnable(tap: mouseTap, enable: true)
        return true
    }
    func unregisterAll() {
        generation = UUID()
        refs.values.forEach { UnregisterEventHotKey($0) }
        refs.removeAll()
        mouseBindings.removeAll()
        mouseRouter = MouseShortcutRouter()
        keyboardBindings.removeAll()
        keyboardRouter = KeyboardShortcutRouter()
        if let keyboardTap { CGEvent.tapEnable(tap: keyboardTap, enable: false); CFMachPortInvalidate(keyboardTap) }
        if let keyboardSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), keyboardSource, .commonModes) }
        keyboardTap = nil; keyboardSource = nil
        if let mouseTap { CGEvent.tapEnable(tap: mouseTap, enable: false); CFMachPortInvalidate(mouseTap) }
        if let mouseSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), mouseSource, .commonModes) }
        mouseTap = nil; mouseSource = nil
    }
    deinit {
        unregisterAll()
        if let handler { RemoveEventHandler(handler) }
    }
}

final class ShortcutRecorderView: NSView {
    var onShortcut: ((Shortcut) -> Void)?
    var onCancel: (() -> Void)?
    private var monitor: Any?
    private var resignObserver: NSObjectProtocol?
    private var pending: Shortcut?
    private var mouseRouter = MouseShortcutRouter()

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        stopMonitoring()
        guard let window else { return }
        resignObserver = NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: window, queue: .main) { [weak self] _ in
            self?.pending = nil
            self?.mouseRouter = MouseShortcutRouter()
        }
        // Monitor the sheet before responder/menu dispatch. SwiftUI may focus its
        // Cancel button after presentation or a click; recording still works.
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp,
            .leftMouseDown, .leftMouseUp, .leftMouseDragged,
            .rightMouseDown, .rightMouseUp, .rightMouseDragged,
            .otherMouseDown, .otherMouseUp, .otherMouseDragged]) { [weak self] event in
            guard let self, let window = self.window, window.isKeyWindow,
                  event.window == nil || event.window === window else { return event }
            return self.capture(event)
        }
    }
    // Save on release, before registering the new global shortcut. This avoids
    // autorepeat firing the action while the same key is still held down.
    func capture(_ event: NSEvent) -> NSEvent? {
        let phase: MouseShortcutRouter.Phase?
        switch event.type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown: phase = .down
        case .leftMouseUp, .rightMouseUp, .otherMouseUp: phase = .up
        case .leftMouseDragged, .rightMouseDragged, .otherMouseDragged: phase = .drag
        default: phase = nil
        }
        if let phase {
            let modifiers = Shortcut.modifiers(from: CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue)))
            let decision = mouseRouter.route(button: event.buttonNumber, modifiers: modifiers, phase: phase, bindings: [:], recording: true,
                shiftSide: ShiftSide.from(CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue))))
            if let shortcut = decision.captured { onShortcut?(shortcut) }
            return decision.consume ? nil : event
        }
        if event.type == .keyDown {
            guard !event.isARepeat else { return nil }
            pending = Shortcut.from(event)
            return nil
        }
        guard event.type == .keyUp, let shortcut = pending,
              shortcut.keyCode == UInt32(event.keyCode) else { return nil }
        pending = nil
        if shortcut.keyCode == 53 && shortcut.modifiers == 0 { onCancel?() }
        else { onShortcut?(shortcut) }
        return nil
    }
    func stopMonitoring() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
        monitor = nil
        resignObserver = nil
        pending = nil
        mouseRouter = MouseShortcutRouter()
    }
    deinit { stopMonitoring() }
}
