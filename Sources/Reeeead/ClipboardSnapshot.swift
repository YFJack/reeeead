import AppKit

// Preserve every advertised representation, without decoding screenshots or retaining
// multiple large images in memory. Temporary data is private and scoped to one copy.
@MainActor final class ClipboardSnapshot {
    private enum Storage { case memory(Data), file(URL) }
    private var items: [[NSPasteboard.PasteboardType: Storage]] = []
    private var directory: URL?
    let changeCount: Int

    init(_ board: NSPasteboard, memoryLimit: Int = 1_024 * 1_024,
         totalLimit: Int = 256 * 1_024 * 1_024,
         temporaryRoot: URL = FileManager.default.temporaryDirectory) throws {
        changeCount = board.changeCount
        var total = 0
        var resident = 0
        do {
            for item in board.pasteboardItems ?? [] {
                var contents: [NSPasteboard.PasteboardType: Storage] = [:]
                for type in item.types {
                    try autoreleasepool {
                        guard let data = item.data(forType: type) else {
                            throw LumaError.message(L("暂时无法完整保存剪贴板，未修改原内容。请稍后重试。"))
                        }
                        guard data.count <= totalLimit - total else {
                            throw LumaError.message(L("剪贴板内容超过 256 MB，已保留原内容。请先保存剪贴板内容，再复制要朗读的文字。"))
                        }
                        total += data.count
                        if data.count <= memoryLimit - resident {
                            contents[type] = .memory(data)
                            resident += data.count
                        } else {
                            if directory == nil {
                                let url = temporaryRoot.appendingPathComponent("Reeeead-clipboard-\(UUID().uuidString)", isDirectory: true)
                                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
                                directory = url
                            }
                            let url = directory!.appendingPathComponent(UUID().uuidString)
                            try data.write(to: url, options: .atomic)
                            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
                            contents[type] = .file(url)
                        }
                    }
                }
                items.append(contents)
            }
            guard board.changeCount == changeCount else {
                throw LumaError.message(L("剪贴板刚刚发生变化，请重新按朗读快捷键。"))
            }
        } catch {
            if let directory { try? FileManager.default.removeItem(at: directory) }
            throw error
        }
    }

    // A later copy belongs to the user: never overwrite it with our earlier snapshot.
    @discardableResult func restore(to board: NSPasteboard, ifUnchangedSince expected: Int) throws -> Bool {
        guard board.changeCount == expected else { return false }
        let restored = try items.map { contents in
            let item = NSPasteboardItem()
            for (type, storage) in contents {
                let data: Data
                switch storage {
                case .memory(let bytes): data = bytes
                case .file(let url): data = try Data(contentsOf: url, options: .mappedIfSafe)
                }
                guard item.setData(data, forType: type) else {
                    throw LumaError.message(L("无法恢复剪贴板格式，请重试。"))
                }
            }
            return item
        }
        guard board.changeCount == expected else { return false }
        board.clearContents()
        if !restored.isEmpty && !board.writeObjects(restored) {
            throw LumaError.message(L("系统未能恢复剪贴板，请检查剪贴板管理工具。"))
        }
        return true
    }

    deinit {
        if let directory { try? FileManager.default.removeItem(at: directory) }
    }
}
