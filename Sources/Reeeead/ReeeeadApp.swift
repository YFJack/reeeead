import AppKit
import SwiftUI
import Combine

@main struct ReeeeadApp {
    static func main() {
        if CommandLine.arguments.contains("--configure-voice-stdin") { exit(VoiceConfiguration.importFromStandardInput()) }
        if CommandLine.arguments.contains("--voice-status") { exit(VoiceConfiguration.status()) }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
        withExtendedLifetime(delegate) {}
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    private var model: AppModel!
    private var window: NSWindow!
    private var statusItem: NSStatusItem!
    private var subscription: AnyCancellable?
    private var languageSubscription: AnyCancellable?
    private var toast: NSPanel?
    private var toastDismiss: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Brand.registerFont()
        model = AppModel()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 570), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.title = "Reeeead"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor(Ink.paper)
        window.minSize = NSSize(width: 460, height: 540)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = NSHostingView(rootView: MainView(model: model, speech: model.speech, ruler: model.ruler))
        window.center()
        self.window = window
        buildMainMenu()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = Self.statusImage()
        statusItem.button?.toolTip = "Reeeead"
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        subscription = model.speech.$message.dropFirst().receive(on: DispatchQueue.main).sink { [weak self] text in
            guard let self else { return }
            self.statusItem.button?.toolTip = "Reeeead · \(text)"
            if !NSApp.isActive && !self.model.ruler.active && !self.model.focus.active { self.showToast(text) }
        }
        languageSubscription = model.$language.dropFirst().receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.buildMainMenu()
        }
        showWindow()
    }
    private func buildMainMenu() {
        let main = NSMenu()
        let appMenu = NSMenu()
        let appItem = NSMenuItem(); appItem.submenu = appMenu; main.addItem(appItem)
        appMenu.addItem(withTitle: L("关于Reeeead"), action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L("设置…"), action: #selector(showSettings), keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L("隐藏 Reeeead"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: L("退出 Reeeead"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let edit = NSMenu(title: L("编辑"))
        let editItem = NSMenuItem(title: L("编辑"), action: nil, keyEquivalent: ""); editItem.submenu = edit; main.addItem(editItem)
        edit.addItem(withTitle: L("撤销"), action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: L("重做"), action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: L("剪切"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: L("复制"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: L("粘贴"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: L("全选"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        NSApp.mainMenu = main
    }
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let heading = NSMenuItem(title: "Reeeead", action: nil, keyEquivalent: ""); heading.isEnabled = false; menu.addItem(heading)
        add(menu, L("打开 Reeeead"), #selector(showWindow))
        menu.addItem(.separator())
        add(menu, model.speech.busy ? L("停止朗读") : L("朗读选中文字  %@", String(model.preferences.readShortcut.display)), #selector(readSelection))
        if model.speech.state == .speaking || model.speech.state == .paused { add(menu, model.speech.state == .paused ? L("继续朗读") : L("暂停朗读"), #selector(pauseSpeech)) }
        add(menu, model.ruler.active ? L("收起标尺") : L("开启阅读标尺  %@", String(model.preferences.rulerShortcut.display)), #selector(toggleRuler))
        add(menu, model.focus.active ? L("收起窗口聚焦") : L("聚焦当前窗口  %@", model.preferences.focusShortcut.display), #selector(toggleFocus))
        menu.addItem(.separator())
        add(menu, L("设置与权限…"), #selector(showSettings))
        add(menu, L("退出 Reeeead"), #selector(quit))
    }
    private func add(_ menu: NSMenu, _ title: String, _ action: Selector) { let item = NSMenuItem(title: title, action: action, keyEquivalent: ""); item.target = self; menu.addItem(item) }
    @objc func showWindow() { NSApp.setActivationPolicy(.regular); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); model.refreshPermission() }
    @objc private func showSettings() { model.page = .shortcuts; showWindow() }
    @objc private func showAbout() { NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "Reeeead", .applicationVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "", .credits: NSAttributedString(string: L("开源阅读辅助工具 · MIT License"))]) }
    @objc private func readSelection() { DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { self.model.speech.selection(preferences: self.model.preferences) } }
    @objc private func pauseSpeech() { model.speech.togglePause() }
    @objc private func toggleRuler() { DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { self.model.toggleRuler() } }
    @objc private func toggleFocus() { DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { self.model.toggleFocus() } }
    @objc private func quit() { NSApp.terminate(nil) }
    func applicationDidBecomeActive(_ notification: Notification) { model?.refreshPermission() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showWindow(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func windowWillClose(_ notification: Notification) { NSApp.setActivationPolicy(.accessory) }
    func applicationWillTerminate(_ notification: Notification) { model.ruler.stop(); model.focus.stop(); model.speech.stop(); model.hotKeys.unregisterAll(); toastDismiss?.cancel() }
    private func showToast(_ text: String) {
        toastDismiss?.cancel(); toast?.orderOut(nil)
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main else { return }
        let panel = NSPanel(contentRect: NSRect(x: screen.visibleFrame.maxX - 390, y: screen.visibleFrame.maxY - 105, width: 365, height: 76), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = true
        panel.level = .floating; panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: HStack(spacing: 13) {
            ReaderMark().frame(width: 27, height: 27)
            Text(text).font(.system(size: 12, weight: .medium)).foregroundStyle(Ink.dark).lineLimit(3).frame(maxWidth: .infinity, alignment: .leading)
        }.padding(16).frame(width: 365, height: 76).background(Ink.paper, in: RoundedRectangle(cornerRadius: 10)))
        toast = panel; panel.orderFrontRegardless()
        let work = DispatchWorkItem { [weak self, weak panel] in panel?.orderOut(nil); self?.toast = nil }
        toastDismiss = work; DispatchQueue.main.asyncAfter(deadline: .now() + 4.5, execute: work)
    }
    private static func statusImage() -> NSImage {
        PixelMark.image(size: NSSize(width: 16, height: 14), template: true)
    }
}
