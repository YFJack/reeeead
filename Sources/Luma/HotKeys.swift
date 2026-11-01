import AppKit
import Carbon

final class HotKeyCenter {
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var handler: EventHandlerRef?
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
        var ref: EventHotKeyRef?
        let result = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, EventHotKeyID(signature: signature, id: id), GetApplicationEventTarget(), 0, &ref)
        guard result == noErr, let ref else { return false }
        if let old = refs[id] { UnregisterEventHotKey(old) }
        refs[id] = ref
        return true
    }
    func unregisterAll() {
        refs.values.forEach { UnregisterEventHotKey($0) }
        refs.removeAll()
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
