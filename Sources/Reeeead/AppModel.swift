import AppKit
import SwiftUI
import AVFoundation

enum Page: String, CaseIterable { case home, voice, ruler, shortcuts }

@MainActor final class AppModel: ObservableObject {
    @Published var preferences = Preferences.load() { didSet { preferences.save() } }
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
    let hotKeys = HotKeyCenter()
    lazy var voices: [AVSpeechSynthesisVoice] = AVSpeechSynthesisVoice.speechVoices().sorted { $0.language + $0.name < $1.language + $1.name }

    init() {
        hotKeys.onRead = { [weak self] in
            guard let self else { return }
            self.speech.selection(preferences: self.preferences)
        }
        hotKeys.onRuler = { [weak self] in
            guard let self else { return }
            self.ruler.toggle(preferences: self.preferences)
        }
        ruler.onMessage = { [weak self] text in self?.speech.show(text) }
        registerShortcuts()
    }
    func registerShortcuts() {
        hotKeys.unregisterAll()
        let read = hotKeys.register(preferences.readShortcut, id: 1)
        let readError = hotKeys.registrationError
        let ruler = hotKeys.register(preferences.rulerShortcut, id: 2)
        notice = !read ? readError : (!ruler ? hotKeys.registrationError : "")
        PermissionReport.write(mouseTapReady: hotKeys.mouseTapReady, keyboardTapReady: hotKeys.keyboardTapReady)
    }
    func beginRecording(_ id: UInt32) {
        ruler.stop()
        hotKeys.unregisterAll(); recording = id; notice = ""; recordingError = ""
        PermissionReport.write(mouseTapReady: hotKeys.mouseTapReady, keyboardTapReady: hotKeys.keyboardTapReady)
    }
    func acceptShortcut(_ shortcut: Shortcut, id: UInt32) -> String? {
        let other = id == 1 ? preferences.rulerShortcut : preferences.readShortcut
        if shortcut.conflicts(with: other) { return L("两个功能不能使用同一组快捷键，请换一组。") }
        guard hotKeys.register(shortcut, id: id) else { return hotKeys.registrationError }
        hotKeys.unregisterAll()
        if id == 1 { preferences.readShortcut = shortcut } else { preferences.rulerShortcut = shortcut }
        recording = nil
        return nil
    }
    func refreshPermission() {
        let changed = permission != SelectionReader.permitted
        permission = SelectionReader.permitted
        if recording == nil && (changed || preferences.readShortcut.mouseButton != nil || preferences.rulerShortcut.mouseButton != nil || preferences.readShortcut.shiftSide != nil || preferences.rulerShortcut.shiftSide != nil) { registerShortcuts() }
        PermissionReport.write(mouseTapReady: hotKeys.mouseTapReady, keyboardTapReady: hotKeys.keyboardTapReady)
    }
}
