import XCTest
import AppKit
import Carbon
@testable import Reeeead

final class ShortcutRecorderTests: XCTestCase {
    private func event(_ code: UInt16, _ flags: NSEvent.ModifierFlags = [], up: Bool = false, repeatKey: Bool = false, characters: String = "") -> NSEvent {
        NSEvent.keyEvent(with: up ? .keyUp : .keyDown, location: .zero, modifierFlags: flags, timestamp: 0,
                        windowNumber: 0, context: nil, characters: characters, charactersIgnoringModifiers: characters,
                        isARepeat: repeatKey, keyCode: code)!
    }

    func testKeysPreviouslySilentlyRejected() throws {
        for (code, name) in [(122, "F1"), (90, "F20"), (123, "←"), (126, "↑"), (36, "↩"), (48, "⇥"), (51, "⌫"), (115, "Home"), (82, "Num 0"), (76, "Num ↩"), (0, "A")] {
            let shortcut = try XCTUnwrap(Shortcut.from(event(UInt16(code))))
            XCTAssertEqual(shortcut.label, name)
            XCTAssertEqual(shortcut.modifiers, 0)
        }
        XCTAssertEqual(Shortcut.from(event(123, [.shift]))?.modifiers, UInt32(shiftKey))
        XCTAssertEqual(Shortcut.from(event(10, [.command], characters: "§"))?.label, "§")
    }

    func testSaveOnlyOnceOnReleaseWithOriginalModifiers() {
        let recorder = ShortcutRecorderView()
        var captured: [Shortcut] = []
        recorder.onShortcut = { captured.append($0) }
        _ = recorder.capture(event(122, [.command, .shift]))
        _ = recorder.capture(event(122, [.command, .shift], repeatKey: true))
        XCTAssertTrue(captured.isEmpty)
        _ = recorder.capture(event(122, up: true))
        _ = recorder.capture(event(122, up: true))
        XCTAssertEqual(captured.count, 1)
        XCTAssertEqual(captured.first?.modifiers, UInt32(cmdKey | shiftKey))
    }

    func testEscapeCancelsButModifiedEscapeCanBeAssigned() {
        let recorder = ShortcutRecorderView()
        var cancelled = 0
        var captured: Shortcut?
        recorder.onCancel = { cancelled += 1 }
        recorder.onShortcut = { captured = $0 }
        _ = recorder.capture(event(53))
        _ = recorder.capture(event(53, up: true))
        XCTAssertEqual(cancelled, 1)
        XCTAssertNil(captured)
        _ = recorder.capture(event(53, [.control]))
        _ = recorder.capture(event(53, up: true))
        XCTAssertEqual(cancelled, 1)
        XCTAssertEqual(captured?.modifiers, UInt32(controlKey))
    }

    func testTeardownDiscardsHeldKey() {
        let recorder = ShortcutRecorderView()
        var captured = false
        recorder.onShortcut = { _ in captured = true }
        _ = recorder.capture(event(0))
        recorder.stopMonitoring()
        _ = recorder.capture(event(0, up: true))
        XCTAssertFalse(captured)
    }

    func testLocalMouseRecordingAndNormalCancelClickPassthrough() throws {
        let recorder = ShortcutRecorderView()
        var captured: [Shortcut] = []
        recorder.onShortcut = { captured.append($0) }
        for button in [0, 1, 2, 3, 4, 8] {
            let downType: CGEventType = button == 0 ? .leftMouseDown : button == 1 ? .rightMouseDown : .otherMouseDown
            let upType: CGEventType = button == 0 ? .leftMouseUp : button == 1 ? .rightMouseUp : .otherMouseUp
            let down = try XCTUnwrap(CGEvent(mouseEventSource: nil, mouseType: downType, mouseCursorPosition: .zero, mouseButton: CGMouseButton(rawValue: UInt32(button))!))
            down.flags = button < 2 ? [.maskControl] : []
            let up = try XCTUnwrap(CGEvent(mouseEventSource: nil, mouseType: upType, mouseCursorPosition: .zero, mouseButton: CGMouseButton(rawValue: UInt32(button))!))
            XCTAssertNil(recorder.capture(try XCTUnwrap(NSEvent(cgEvent: down))))
            XCTAssertNil(recorder.capture(try XCTUnwrap(NSEvent(cgEvent: up))))
            XCTAssertEqual(captured.last, Shortcut.mouse(button: button, modifiers: button < 2 ? UInt32(controlKey) : 0))
        }
        XCTAssertEqual(captured.count, 6)
        let normal = try XCTUnwrap(CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: .zero, mouseButton: .left))
        XCTAssertNotNil(recorder.capture(try XCTUnwrap(NSEvent(cgEvent: normal))))
    }
}
