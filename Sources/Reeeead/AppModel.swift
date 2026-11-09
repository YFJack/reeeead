import AppKit
import SwiftUI
import AVFoundation

enum Page: String, CaseIterable { case home, voice, ruler, shortcuts }

@MainActor final class AppModel: ObservableObject {
    @Published var preferences = Preferences.load() {
        didSet {
            preferences.save()
            if oldValue.focusOpacity != preferences.focusOpacity { focus.updateOpacity(preferences.focusOpacity) }
            if oldValue.focusCornerRadius != preferences.focusCornerRadius { focus.updateCornerRadius(preferences.focusCornerRadius) }
        }
    }
    @Published var language = Localization.language {
        didSet {
            let wasDefault = sample == Localization.text("选中文字，按下快捷键，就能听到朗读。", language: oldValue)
            Localization.language = language
            if wasDefault { sample = L("选中文字，按下快捷键，就能听到朗读。") }
        }
    }
    @Published var page: Page = .home
    @Published var permission = SelectionReader.permitted
    @Published var notice = ""
    @Published var sample = L("选中文字，按下快捷键，就能听到朗读。")
    @Published var recording: UInt32?
    @Published var recordingError = ""
    let speech = SpeechEngine()
    let ruler = RulerController()
    let focus = WindowFocusController()
    let hotKeys = HotKeyCenter()
    lazy var voices: [AVSpeechSynthesisVoice] = AVSpeechSynthesisVoice.speechVoices().sorted { $0.language + $0.name < $1.language + $1.name }

    init() {
        hotKeys.onRead = { [weak self] in
            guard let self else { return }
            self.speech.selection(preferences: self.preferences)
        }
        hotKeys.onRuler = { [weak self] in
            guard let self else { return }
            self.toggleRuler()
        }
        hotKeys.onFocus = { [weak self] in self?.toggleFocus() }
        hotKeys.onEscape = { [weak self] in
            guard let self, self.focus.active else { return false }
            self.focus.stop()
            return true
        }
        focus.onMessage = { [weak self] text in self?.speech.show(text) }
        ruler.onMessage = { [weak self] text in self?.speech.show(text) }
        registerShortcuts()
    }
    func registerShortcuts() {
        hotKeys.unregisterAll()
        let read = hotKeys.register(preferences.readShortcut, id: 1)
        let readError = hotKeys.registrationError
        let ruler = hotKeys.register(preferences.rulerShortcut, id: 2)
        let rulerError = hotKeys.registrationError
        let conflict = [preferences.readShortcut, preferences.rulerShortcut].contains { $0.conflicts(with: preferences.focusShortcut) }
        let focus = !conflict && hotKeys.register(preferences.focusShortcut, id: 3)
        let focusError = conflict ? L("窗口聚焦快捷键与已有功能重复，请换一组。") : hotKeys.registrationError
        notice = !read ? readError : (!ruler ? rulerError : (!focus ? focusError : ""))
        if self.focus.active { _ = hotKeys.enableEscapeHandling() }
        PermissionReport.write(mouseTapReady: hotKeys.mouseTapReady, keyboardTapReady: hotKeys.keyboardTapReady)
    }
    func beginRecording(_ id: UInt32) {
        ruler.stop(); focus.stop()
        hotKeys.unregisterAll(); recording = id; notice = ""; recordingError = ""
        PermissionReport.write(mouseTapReady: hotKeys.mouseTapReady, keyboardTapReady: hotKeys.keyboardTapReady)
    }
    func acceptShortcut(_ shortcut: Shortcut, id: UInt32) -> String? {
        let bindings: [UInt32: Shortcut] = [1: preferences.readShortcut, 2: preferences.rulerShortcut, 3: preferences.focusShortcut]
        if bindings.contains(where: { $0.key != id && shortcut.conflicts(with: $0.value) }) { return L("不同功能不能使用同一组快捷键，请换一组。") }
        guard hotKeys.register(shortcut, id: id) else { return hotKeys.registrationError }
        hotKeys.unregisterAll()
        if id == 1 { preferences.readShortcut = shortcut } else if id == 2 { preferences.rulerShortcut = shortcut } else { preferences.focusShortcut = shortcut }
        recording = nil
        return nil
    }
    func toggleRuler() {
        focus.stop()
        ruler.toggle(preferences: preferences)
    }
    func toggleFocus() {
        if focus.active { focus.stop(); return }
        guard hotKeys.enableEscapeHandling() else {
            speech.show(L("窗口聚焦需要辅助功能权限。请在「快捷键」页开启权限。"))
            return
        }
        ruler.stop()
        focus.start(opacity: preferences.focusOpacity, cornerRadius: preferences.focusCornerRadius)
    }
    func refreshPermission() {
        let changed = permission != SelectionReader.permitted
        permission = SelectionReader.permitted
        if recording == nil && (changed || preferences.readShortcut.mouseButton != nil || preferences.rulerShortcut.mouseButton != nil || preferences.readShortcut.shiftSide != nil || preferences.rulerShortcut.shiftSide != nil || preferences.focusShortcut.shiftSide != nil || preferences.focusShortcut.mouseButton != nil) { registerShortcuts() }
        PermissionReport.write(mouseTapReady: hotKeys.mouseTapReady, keyboardTapReady: hotKeys.keyboardTapReady)
    }
}
