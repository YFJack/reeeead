import AppKit
import SwiftUI
import Combine

@main struct LumaApp {
    static func main() {
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
    private var toast: NSPanel?
    private var toastDismiss: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        model = AppModel()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1040, height: 790), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.title = "一行 · Luma"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor(Ink.paper)
        window.minSize = NSSize(width: 940, height: 700)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = NSHostingView(rootView: MainView(model: model, speech: model.speech, ruler: model.ruler))
        window.center()
        self.window = window
        buildMainMenu()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = Self.statusImage()
        statusItem.button?.toolTip = "一行 · Luma"
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        subscription = model.speech.$message.dropFirst().receive(on: DispatchQueue.main).sink { [weak self] text in
            guard let self else { return }
            self.statusItem.button?.toolTip = "Luma · \(text)"
            if !NSApp.isActive && !self.model.ruler.active { self.showToast(text) }
        }
        showWindow()
    }
    private func buildMainMenu() {
        let main = NSMenu()
        let appMenu = NSMenu()
        let appItem = NSMenuItem(); appItem.submenu = appMenu; main.addItem(appItem)
        appMenu.addItem(withTitle: "关于一行 · Luma", action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "设置…", action: #selector(showSettings), keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "隐藏 Luma", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "退出 Luma", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let edit = NSMenu(title: "编辑")
        let editItem = NSMenuItem(title: "编辑", action: nil, keyEquivalent: ""); editItem.submenu = edit; main.addItem(editItem)
        edit.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "重做", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        NSApp.mainMenu = main
    }
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let heading = NSMenuItem(title: "一行 · Luma", action: nil, keyEquivalent: ""); heading.isEnabled = false; menu.addItem(heading)
        add(menu, "打开阅读空间", #selector(showWindow))
        menu.addItem(.separator())
        add(menu, model.speech.busy ? "停止朗读" : "朗读选中文字  \(model.preferences.readShortcut.display)", #selector(readSelection))
        if model.speech.state == .speaking || model.speech.state == .paused { add(menu, model.speech.state == .paused ? "继续朗读" : "暂停朗读", #selector(pauseSpeech)) }
        add(menu, model.ruler.active ? "收起标尺" : "开启阅读标尺  \(model.preferences.rulerShortcut.display)", #selector(toggleRuler))
        menu.addItem(.separator())
        add(menu, "设置与权限…", #selector(showSettings))
        add(menu, "退出 Luma", #selector(quit))
    }
    private func add(_ menu: NSMenu, _ title: String, _ action: Selector) { let item = NSMenuItem(title: title, action: action, keyEquivalent: ""); item.target = self; menu.addItem(item) }
    @objc func showWindow() { NSApp.setActivationPolicy(.regular); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); model.refreshPermission() }
    @objc private func showSettings() { model.page = .shortcuts; showWindow() }
    @objc private func showAbout() { NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "一行 · Luma", .applicationVersion: "0.1.0", .credits: NSAttributedString(string: "一次一行，也在向前。\n开源阅读辅助工具 · MIT License")]) }
    @objc private func readSelection() { DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { self.model.speech.selection(preferences: self.model.preferences) } }
    @objc private func pauseSpeech() { model.speech.togglePause() }
    @objc private func toggleRuler() { DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { self.model.ruler.toggle(preferences: self.model.preferences) } }
    @objc private func quit() { NSApp.terminate(nil) }
    func applicationDidBecomeActive(_ notification: Notification) { model?.refreshPermission() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showWindow(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func windowWillClose(_ notification: Notification) { NSApp.setActivationPolicy(.accessory) }
    func applicationWillTerminate(_ notification: Notification) { model.ruler.stop(); model.speech.stop(); model.hotKeys.unregisterAll(); toastDismiss?.cancel() }
    private func showToast(_ text: String) {
        toastDismiss?.cancel(); toast?.orderOut(nil)
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main else { return }
        let panel = NSPanel(contentRect: NSRect(x: screen.visibleFrame.maxX - 390, y: screen.visibleFrame.maxY - 105, width: 365, height: 76), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = true
        panel.level = .floating; panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: HStack(spacing: 13) {
            PixelIcon(kind: "book").frame(width: 27, height: 27)
            Text(text).font(.system(size: 12, weight: .medium)).foregroundStyle(Ink.dark).lineLimit(3).frame(maxWidth: .infinity, alignment: .leading)
        }.padding(16).frame(width: 365, height: 76).background(Ink.paper, in: RoundedRectangle(cornerRadius: 10)))
        toast = panel; panel.orderFrontRegardless()
        let work = DispatchWorkItem { [weak self, weak panel] in panel?.orderOut(nil); self?.toast = nil }
        toastDismiss = work; DispatchQueue.main.asyncAfter(deadline: .now() + 4.5, execute: work)
    }
    private static func statusImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setFill()
            for (y, row) in PixelIcon.patterns["book"]!.enumerated() { for (x, p) in row.enumerated() where p == "1" { NSRect(x: CGFloat(x) + 3, y: 15 - CGFloat(y), width: 1, height: 1).fill() } }
            return true
        }
        image.isTemplate = true
        return image
    }
}
