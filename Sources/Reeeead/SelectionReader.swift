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
        guard permitted else { throw LumaError.message(L("还差一步：在「快捷键」页开启辅助功能权限，才能读取其他应用中的选中文字。")) }
        guard let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            throw LumaError.message(L("请先切换到要阅读的应用、选中文字，再按朗读快捷键。"))
        }
        let pid = app.processIdentifier
        if let text = accessibleText(pid: pid) { return text }
        guard useCopyFallback else { throw LumaError.message(L("此应用没有提供选中文字。可以在「快捷键」页开启复制兼容模式。")) }
        try Task.checkCancellation()
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { throw LumaError.message(L("前台应用已切换，请重新选择文字。")) }
        let board = NSPasteboard.general
        let backup = try ClipboardSnapshot(board)
        let originalChange = backup.changeCount
        try Task.checkCancellation()
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else {
            throw LumaError.message(L("前台应用已切换，请重新选择文字。"))
        }
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
                if sameApp { try backup.restore(to: board, ifUnchangedSince: copiedChange) }
                try Task.checkCancellation()
                guard sameApp else { throw LumaError.message(L("前台应用已切换，已取消本次朗读。")) }
                if let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return text }
                break
            }
        }
        try Task.checkCancellation()
        throw LumaError.message(L("没有读到选中文字。请确认已选中可复制的文字；图片和扫描件暂不支持。"))
    }
}
