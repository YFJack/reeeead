import AppKit
import Carbon

final class HotKeyCenter {
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var handler: EventHandlerRef?
    private var mouseBindings: [UInt32: Shortcut] = [:]
    private var mouseTap: CFMachPort?
    var mouseTapReady: Bool { mouseTap != nil }
    private var mouseSource: CFRunLoopSource?
    private var mouseRouter = MouseShortcutRouter()
    private var onCapture: ((Shortcut) -> Void)?
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
            guard (3...31).contains(button), installMouseTap() else {
                registrationError = "鼠标侧键需要辅助功能权限。开启后点「重新检查」。"
                return false
            }
            if let old = refs.removeValue(forKey: id) { UnregisterEventHotKey(old) }
            mouseBindings[id] = shortcut
            return true
        }
        var ref: EventHotKeyRef?
        let result = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, EventHotKeyID(signature: signature, id: id), GetApplicationEventTarget(), 0, &ref)
        guard result == noErr, let ref else {
            registrationError = "快捷键被其他应用占用，请换一组。"
            return false
        }
        if let old = refs[id] { UnregisterEventHotKey(old) }
        refs[id] = ref
        mouseBindings.removeValue(forKey: id)
        return true
    }
    func beginMouseRecording(_ capture: @escaping (Shortcut) -> Void) -> Bool {
        onCapture = capture
        return installMouseTap()
    }
    private func installMouseTap() -> Bool {
        if mouseTap != nil { return true }
        let mask = [CGEventType.otherMouseDown, .otherMouseUp, .otherMouseDragged].reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        mouseTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask, callback: { _, type, event, info in
            guard let info else { return Unmanaged.passUnretained(event) }
            let center = Unmanaged<HotKeyCenter>.fromOpaque(info).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = center.mouseTap { CGEvent.tapEnable(tap: tap, enable: true) }
                return Unmanaged.passUnretained(event)
            }
            let phase: MouseShortcutRouter.Phase
            switch type {
            case .otherMouseDown: phase = .down
            case .otherMouseUp: phase = .up
            case .otherMouseDragged: phase = .drag
            default: return Unmanaged.passUnretained(event)
            }
            let decision = center.mouseRouter.route(button: Int(event.getIntegerValueField(.mouseEventButtonNumber)), modifiers: Shortcut.modifiers(from: event.flags), phase: phase, bindings: center.mouseBindings, recording: center.onCapture != nil)
            if decision.action != nil || decision.captured != nil {
                let generation = center.generation
                DispatchQueue.main.async { [weak center] in
                    guard let center, center.generation == generation else { return }
                    if let shortcut = decision.captured { center.onCapture?(shortcut) }
                    else if decision.action == 1 { center.onRead?() }
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
        onCapture = nil
        mouseRouter = MouseShortcutRouter()
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
    override var acceptsFirstResponder: Bool { true }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); window?.makeFirstResponder(self) }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onCancel?(); return }
        if let shortcut = Shortcut.from(event) { onShortcut?(shortcut) } else { NSSound.beep() }
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if let shortcut = Shortcut.from(event) { onShortcut?(shortcut); return true }
        return super.performKeyEquivalent(with: event)
    }
}
