import AppKit
import ApplicationServices

enum SelectionReader {
    static var permitted: Bool { AXIsProcessTrusted() }
    static func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") { NSWorkspace.shared.open(url) }
    }
    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &result) == .success else { return nil }
        return result
    }
    static func accessibleText(pid: pid_t) -> String? {
        let application = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(application, 0.4)
        guard let focused = attribute(application, kAXFocusedUIElementAttribute), CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        let element = unsafeBitCast(focused, to: AXUIElement.self)
        if let text = attribute(element, kAXSelectedTextAttribute) as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return text }
        if let raw = attribute(element, kAXSelectedTextRangeAttribute), CFGetTypeID(raw) == AXValueGetTypeID(),
           let text = attribute(element, kAXValueAttribute) as? String {
            var range = CFRange()
            let value = unsafeBitCast(raw, to: AXValue.self)
            if AXValueGetValue(value, .cfRange, &range), range.location >= 0, range.length > 0,
               range.location <= (text as NSString).length, range.length <= (text as NSString).length - range.location {
                return (text as NSString).substring(with: NSRange(location: range.location, length: range.length))
            }
        }
        return nil
    }
    @MainActor static func read(useCopyFallback: Bool) async throws -> String {
        guard permitted else { throw LumaError.message("还差一步：在「快捷键」页开启辅助功能权限，才能读取其他应用中的选中文字。") }
        guard let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            throw LumaError.message("请先切换到要阅读的应用、选中文字，再按朗读快捷键。")
        }
        let pid = app.processIdentifier
        if let text = accessibleText(pid: pid) { return text }
        guard useCopyFallback else { throw LumaError.message("此应用没有提供选中文字。可以在「快捷键」页开启复制兼容模式。") }
        try Task.checkCancellation()
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { throw LumaError.message("前台应用已切换，请重新选择文字。") }
        let board = NSPasteboard.general
        var bytes = 0
        var backup: [[NSPasteboard.PasteboardType: Data]] = []
        for item in board.pasteboardItems ?? [] {
            if item.types.contains(.tiff) || item.types.contains(.png) || item.types.contains(.fileURL) {
                throw LumaError.message("剪贴板中有图片或文件，已保留原内容。请手动粘贴文字到试读区，或换用支持选区读取的应用。")
            }
            var copy: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                guard let data = item.data(forType: type) else { continue }
                bytes += data.count
                guard bytes <= 8 * 1024 * 1024 else { throw LumaError.message("剪贴板内容较大，已保留原内容。请换用支持选区读取的应用，或手动粘贴到试读区。") }
                copy[type] = data
            }
            backup.append(copy)
        }
        let originalChange = board.changeCount
        let source = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.postToPid(pid)
        up?.postToPid(pid)
        // Wait for a fresh copy. Never read the pre-existing clipboard as a selection.
        for _ in 0..<14 {
            // Clipboard cleanup must finish even when playback is canceled mid-copy.
            await withCheckedContinuation { continuation in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { continuation.resume() }
            }
            if board.changeCount != originalChange {
                let copiedChange = board.changeCount
                let text = board.string(forType: .string)
                let sameApp = NSWorkspace.shared.frontmostApplication?.processIdentifier == pid
                // Restore only if no subsequent writer has touched the clipboard.
                if sameApp && board.changeCount == copiedChange {
                    board.clearContents()
                    let items = backup.map { contents -> NSPasteboardItem in
                        let item = NSPasteboardItem()
                        for (type, data) in contents { item.setData(data, forType: type) }
                        return item
                    }
                    if !items.isEmpty { board.writeObjects(items) }
                }
                try Task.checkCancellation()
                guard sameApp else { throw LumaError.message("前台应用已切换，已取消本次朗读。") }
                if let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return text }
                break
            }
        }
        try Task.checkCancellation()
        throw LumaError.message("没有读到选中文字。请确认已选中可复制的文字；图片和扫描件暂不支持。")
    }
}
