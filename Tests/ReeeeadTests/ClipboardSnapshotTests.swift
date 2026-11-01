import AppKit
import XCTest
@testable import Reeeead

final class ClipboardSnapshotTests: XCTestCase {
    @MainActor func testScreenshotLargerThanOldLimitRestoresEveryRepresentation() throws {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let image = Data(repeating: 0xA5, count: 10 * 1_024 * 1_024)
        let png = Data([137, 80, 78, 71, 13, 10, 26, 10])
        let metadata = NSPasteboard.PasteboardType("app.reeeead.test-screenshot-metadata")
        let item = NSPasteboardItem()
        item.setData(image, forType: .tiff)
        item.setData(png, forType: .png)
        item.setString("capture metadata", forType: metadata)
        XCTAssertTrue(board.writeObjects([item]))
        let snapshot = try ClipboardSnapshot(board)
        board.clearContents(); board.setString("only selected sentence", forType: .string)
        let copied = board.changeCount
        XCTAssertEqual(board.string(forType: .string), "only selected sentence")
        XCTAssertTrue(try snapshot.restore(to: board, ifUnchangedSince: copied))
        XCTAssertEqual(board.data(forType: .tiff), image)
        XCTAssertEqual(board.data(forType: .png), png)
        XCTAssertEqual(board.string(forType: metadata), "capture metadata")
        XCTAssertNil(board.string(forType: .string))
    }

    @MainActor func testFileURLsAndMultipleItemsSurviveTemporaryTextCopy() throws {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let originals = ["file:///tmp/example-one.png", "file:///tmp/example-two.pdf"]
        let items = originals.map { value in
            let item = NSPasteboardItem(); item.setString(value, forType: .fileURL); return item
        }
        XCTAssertTrue(board.writeObjects(items))
        let snapshot = try ClipboardSnapshot(board)
        board.clearContents(); board.setString("new selected text", forType: .string)
        XCTAssertTrue(try snapshot.restore(to: board, ifUnchangedSince: board.changeCount))
        XCTAssertEqual(board.pasteboardItems?.compactMap { $0.string(forType: .fileURL) }, originals)
    }

    @MainActor func testLaterUserCopyIsNeverOverwritten() throws {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setData(Data([1, 2, 3]), forType: .png)
        let snapshot = try ClipboardSnapshot(board)
        board.clearContents(); board.setString("selected text", forType: .string)
        let copied = board.changeCount
        board.clearContents(); board.setString("user copied this later", forType: .string)
        XCTAssertFalse(try snapshot.restore(to: board, ifUnchangedSince: copied))
        XCTAssertEqual(board.string(forType: .string), "user copied this later")
    }

    @MainActor func testEmptyClipboardRestoresToEmpty() throws {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let snapshot = try ClipboardSnapshot(board)
        board.setString("selected text", forType: .string)
        XCTAssertTrue(try snapshot.restore(to: board, ifUnchangedSince: board.changeCount))
        XCTAssertTrue(board.pasteboardItems?.isEmpty ?? true)
    }

    @MainActor func testTemporaryBackupIsPrivateAndRemovedAfterUse() throws {
        let board = NSPasteboard.withUniqueName()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { board.releaseGlobally(); try? FileManager.default.removeItem(at: root) }
        board.setData(Data(repeating: 4, count: 100), forType: .png)
        var snapshot: ClipboardSnapshot? = try ClipboardSnapshot(board, memoryLimit: 0, temporaryRoot: root)
        let folder = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).first)
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: folder.path)[.posixPermissions] as? Int, 0o700)
        let file = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil).first)
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? Int, 0o600)
        XCTAssertNotNil(snapshot)
        snapshot = nil
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).isEmpty)
    }

    @MainActor func testOverBudgetBackupLeavesOriginalUntouchedAndCleansPartialFiles() throws {
        let board = NSPasteboard.withUniqueName()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { board.releaseGlobally(); try? FileManager.default.removeItem(at: root) }
        let items = (0..<2).map { n in
            let item = NSPasteboardItem(); item.setData(Data(repeating: UInt8(n), count: 60), forType: .png); return item
        }
        board.writeObjects(items)
        let count = board.changeCount
        XCTAssertThrowsError(try ClipboardSnapshot(board, memoryLimit: 0, totalLimit: 100, temporaryRoot: root))
        XCTAssertEqual(board.changeCount, count)
        XCTAssertEqual(board.pasteboardItems?.count, 2)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).isEmpty)
    }
}
