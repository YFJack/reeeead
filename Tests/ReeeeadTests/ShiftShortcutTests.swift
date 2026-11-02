import XCTest
import AppKit
import Carbon
@testable import Reeeead

final class ShiftShortcutTests: XCTestCase {
    private let left = CGEventFlags(rawValue: CGEventFlags.maskShift.rawValue | 0x2)
    private let right = CGEventFlags(rawValue: CGEventFlags.maskShift.rawValue | 0x4)
    private let both = CGEventFlags(rawValue: CGEventFlags.maskShift.rawValue | 0x6)
    private func shortcut(_ side: ShiftSide?) -> Shortcut {
        Shortcut(keyCode: 50, modifiers: UInt32(shiftKey), label: "`", shiftSide: side)
    }
    private func key(_ flags: CGEventFlags, up: Bool = false) -> NSEvent {
        NSEvent.keyEvent(with: up ? .keyUp : .keyDown, location: .zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(flags.rawValue)), timestamp: 0,
            windowNumber: 0, context: nil, characters: "~", charactersIgnoringModifiers: "~",
            isARepeat: false, keyCode: 50)!
    }

    func testPhysicalShiftFlagsAndRecordedLabels() throws {
        for (flags, side) in [(left, ShiftSide.left), (right, .right), (both, .both)] {
            let recorded = try XCTUnwrap(Shortcut.from(key(flags)))
            XCTAssertEqual(recorded.shiftSide, side)
            XCTAssertEqual(recorded.display, side.display + "`")
            XCTAssertEqual(try JSONDecoder().decode(Shortcut.self, from: JSONEncoder().encode(recorded)), recorded)
        }
        XCTAssertNil(ShiftSide.from([.maskShift]))
        XCTAssertNil(ShiftSide.from(CGEventFlags(rawValue: 0x6)))
        XCTAssertNil(ShiftSide.from([.maskAlphaShift, .maskSecondaryFn]))
    }

    func testLegacyShiftRemainsEitherSideButConflictsWithBothSpecificBindings() throws {
        let old = try JSONDecoder().decode(Shortcut.self, from: Data(#"{"keyCode":50,"modifiers":512,"label":"`"}"#.utf8))
        XCTAssertNil(old.shiftSide)
        for side in [ShiftSide.left, .right, .both] {
            XCTAssertTrue(old.matches(shortcut(side)))
            XCTAssertTrue(old.conflicts(with: shortcut(side)))
            XCTAssertTrue(shortcut(side).conflicts(with: old))
            XCTAssertFalse(shortcut(side).matches(old), "Unknown event side must not satisfy a specific binding")
        }
        XCTAssertFalse(shortcut(.left).conflicts(with: shortcut(.right)))
        XCTAssertFalse(shortcut(.left).matches(shortcut(.both)))
    }

    func testLeftAndRightDispatchDifferentActionsAndIgnoreRepeat() {
        var router = KeyboardShortcutRouter()
        let bindings: [UInt32: Shortcut] = [1: shortcut(.left), 2: shortcut(.right)]
        for (flags, action) in [(left, UInt32(1)), (right, UInt32(2))] {
            let down = router.route(keyCode: 50, flags: flags, down: true, bindings: bindings)
            XCTAssertTrue(down.consume)
            XCTAssertNil(down.action)
            let repeated = router.route(keyCode: 50, flags: flags, down: true, repeatKey: true, bindings: bindings)
            XCTAssertTrue(repeated.consume)
            XCTAssertNil(repeated.action)
            // Shift may already be released by the time the base key is released.
            let up = router.route(keyCode: 50, flags: [], down: false, bindings: bindings)
            XCTAssertTrue(up.consume)
            XCTAssertEqual(up.action, action)
            XCTAssertFalse(router.route(keyCode: 50, flags: [], down: false, bindings: bindings).consume)
        }
    }

    func testUnmatchedSideAndTypingPassThroughWithoutLateRepeatCapture() {
        var router = KeyboardShortcutRouter()
        let bindings: [UInt32: Shortcut] = [1: shortcut(.left)]
        for flags in [right, both, .maskShift, [], left.union(.maskCommand)] {
            XCTAssertFalse(router.route(keyCode: 50, flags: flags, down: true, bindings: bindings).consume)
            XCTAssertFalse(router.route(keyCode: 50, flags: [], down: false, bindings: bindings).consume)
        }
        XCTAssertFalse(router.route(keyCode: 0, flags: left, down: true, bindings: bindings).consume)
        XCTAssertFalse(router.route(keyCode: 50, flags: left, down: true, repeatKey: true, bindings: bindings).consume)
    }

    func testMouseSidesAreMatchedAtPressAndPreservedUntilRelease() {
        let bindings: [UInt32: Shortcut] = [1: .mouse(button: 3, modifiers: UInt32(shiftKey), shiftSide: .left)!,
                                           2: .mouse(button: 3, modifiers: UInt32(shiftKey), shiftSide: .right)!]
        var router = MouseShortcutRouter()
        for (side, action) in [(ShiftSide.left, UInt32(1)), (.right, UInt32(2))] {
            XCTAssertTrue(router.route(button: 3, modifiers: UInt32(shiftKey), phase: .down, bindings: bindings, recording: false, shiftSide: side).consume)
            XCTAssertEqual(router.route(button: 3, modifiers: 0, phase: .up, bindings: bindings, recording: false).action, action)
        }
        XCTAssertFalse(router.route(button: 3, modifiers: UInt32(shiftKey), phase: .down, bindings: bindings, recording: false).consume)
    }

    func testRecorderSavesOriginalShiftSideWhenModifiersAreReleasedFirst() {
        let recorder = ShortcutRecorderView()
        var captured: [Shortcut] = []
        recorder.onShortcut = { captured.append($0) }
        _ = recorder.capture(key(left))
        _ = recorder.capture(key([], up: true))
        _ = recorder.capture(key(right))
        _ = recorder.capture(key([], up: true))
        XCTAssertEqual(captured.map(\.shiftSide), [.left, .right])
    }

    func testMouseRecorderPreservesRightShift() throws {
        let recorder = ShortcutRecorderView()
        var captured: Shortcut?
        recorder.onShortcut = { captured = $0 }
        let down = try XCTUnwrap(CGEvent(mouseEventSource: nil, mouseType: .otherMouseDown, mouseCursorPosition: .zero, mouseButton: .center))
        down.flags = right
        let up = try XCTUnwrap(CGEvent(mouseEventSource: nil, mouseType: .otherMouseUp, mouseCursorPosition: .zero, mouseButton: .center))
        _ = recorder.capture(try XCTUnwrap(NSEvent(cgEvent: down)))
        _ = recorder.capture(try XCTUnwrap(NSEvent(cgEvent: up)))
        XCTAssertEqual(captured?.shiftSide, .right)
        XCTAssertEqual(captured?.mouseButton, 2)
    }
}
