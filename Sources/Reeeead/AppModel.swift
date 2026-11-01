import AppKit
import SwiftUI
import AVFoundation

enum Page: String, CaseIterable { case home = "阅读", voice = "语音", ruler = "标尺", shortcuts = "快捷键" }

@MainActor final class AppModel: ObservableObject {
    @Published var preferences = Preferences.load() { didSet { preferences.save() } }
    @Published var page: Page = .home
    @Published var permission = SelectionReader.permitted
    @Published var notice = ""
    @Published var sample = "选中文字，按下快捷键，就能听到朗读。"
    @Published var recording: UInt32?
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
        let ruler = hotKeys.register(preferences.rulerShortcut, id: 2)
        if !read || !ruler { notice = "快捷键被其他应用占用，请在「快捷键」中重新设置。" }
    }
    func beginRecording(_ id: UInt32) { hotKeys.unregisterAll(); recording = id; notice = "" }
    func acceptShortcut(_ shortcut: Shortcut, id: UInt32) -> String? {
        let other = id == 1 ? preferences.rulerShortcut : preferences.readShortcut
        if shortcut.keyCode == other.keyCode && shortcut.modifiers == other.modifiers { return "两个功能不能使用同一组快捷键，请换一组。" }
        guard hotKeys.register(shortcut, id: id) else { return "这组快捷键已被系统或其他应用占用，请换一组。" }
        hotKeys.unregisterAll()
        if id == 1 { preferences.readShortcut = shortcut } else { preferences.rulerShortcut = shortcut }
        recording = nil
        return nil
    }
    func refreshPermission() { permission = SelectionReader.permitted }
}
