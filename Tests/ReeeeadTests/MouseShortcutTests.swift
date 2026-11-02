import XCTest
import Carbon
@testable import Reeeead

final class MouseShortcutTests: XCTestCase {
    func testLegacyKeyboardPreferencesStillDecode() throws {
        let data = Data(#"{"keyCode":15,"modifiers":6144,"label":"R"}"#.utf8)
        let shortcut = try JSONDecoder().decode(Shortcut.self, from: data)
        XCTAssertEqual(shortcut, .read)
        XCTAssertNil(shortcut.mouseButton)
    }
    func testSideButtonRoundTripAndConflicts() throws {
        let shortcut = try XCTUnwrap(Shortcut.mouse(button: 3, modifiers: UInt32(optionKey)))
        XCTAssertEqual(try JSONDecoder().decode(Shortcut.self, from: JSONEncoder().encode(shortcut)), shortcut)
        XCTAssertEqual(shortcut.display, "⌥" + L("鼠标 %@", "4"))
        XCTAssertTrue(shortcut.conflicts(with: shortcut))
        XCTAssertFalse(shortcut.conflicts(with: Shortcut.mouse(button: 4, modifiers: UInt32(optionKey))!))
        XCTAssertFalse(shortcut.conflicts(with: Shortcut.mouse(button: 3)!))
        XCTAssertFalse(shortcut.conflicts(with: Shortcut(keyCode: 0, modifiers: UInt32(optionKey), label: "A")))
    }
    func testNormalClicksAndUnboundModifiersPassThrough() {
        var router = MouseShortcutRouter()
        let bindings: [UInt32: Shortcut] = [1: .mouse(button: 3)!]
        for button in [0, 1, 2, 4, 32] {
            XCTAssertFalse(router.route(button: button, modifiers: 0, phase: .down, bindings: bindings, recording: false).consume)
            XCTAssertFalse(router.route(button: button, modifiers: 0, phase: .up, bindings: bindings, recording: false).consume)
        }
        XCTAssertFalse(router.route(button: 3, modifiers: UInt32(cmdKey), phase: .down, bindings: bindings, recording: false).consume)
        XCTAssertFalse(router.route(button: 3, modifiers: 0, phase: .up, bindings: bindings, recording: false).consume)
    }
    func testConsumesWholePressAndFiresOnlyOnceOnRelease() {
        var router = MouseShortcutRouter()
        let bindings: [UInt32: Shortcut] = [2: .mouse(button: 4, modifiers: UInt32(optionKey))!]
        for _ in 0..<2 {
            let down = router.route(button: 4, modifiers: UInt32(optionKey), phase: .down, bindings: bindings, recording: false)
            XCTAssertTrue(down.consume)
            XCTAssertNil(down.action)
        }
        XCTAssertTrue(router.route(button: 4, modifiers: 0, phase: .drag, bindings: bindings, recording: false).consume)
        let release = router.route(button: 4, modifiers: 0, phase: .up, bindings: bindings, recording: false)
        XCTAssertTrue(release.consume)
        XCTAssertEqual(release.action, 2)
        let again = router.route(button: 4, modifiers: 0, phase: .up, bindings: bindings, recording: false)
        XCTAssertFalse(again.consume)
        XCTAssertNil(again.action)
    }
    func testRecordingWaitsForReleaseAndPreservesPressModifiers() {
        var router = MouseShortcutRouter()
        let down = router.route(button: 3, modifiers: UInt32(shiftKey), phase: .down, bindings: [:], recording: true)
        XCTAssertTrue(down.consume)
        XCTAssertNil(down.captured)
        let up = router.route(button: 3, modifiers: 0, phase: .up, bindings: [:], recording: true)
        XCTAssertTrue(up.consume)
        XCTAssertEqual(up.captured, .mouse(button: 3, modifiers: UInt32(shiftKey)))
        XCTAssertNil(up.action)
        XCTAssertFalse(router.route(button: 0, modifiers: 0, phase: .down, bindings: [:], recording: true).consume)
    }
    func testTwoButtonsMaintainIndependentPressState() {
        var router = MouseShortcutRouter()
        let bindings: [UInt32: Shortcut] = [1: .mouse(button: 3)!, 2: .mouse(button: 4)!]
        _ = router.route(button: 3, modifiers: 0, phase: .down, bindings: bindings, recording: false)
        _ = router.route(button: 4, modifiers: 0, phase: .down, bindings: bindings, recording: false)
        XCTAssertEqual(router.route(button: 4, modifiers: 0, phase: .up, bindings: bindings, recording: false).action, 2)
        XCTAssertEqual(router.route(button: 3, modifiers: 0, phase: .up, bindings: bindings, recording: false).action, 1)
    }
    func testModifierConversionIgnoresCapsLockAndFunction() {
        XCTAssertEqual(Shortcut.modifiers(from: [.maskAlphaShift, .maskSecondaryFn]), 0)
        XCTAssertEqual(Shortcut.modifiers(from: [.maskCommand, .maskAlternate, .maskControl, .maskShift, .maskAlphaShift]), UInt32(cmdKey | optionKey | controlKey | shiftKey))
    }
    func testMiddleAndAdditionalButtonsCanBeRecorded() throws {
        for button in [2, 3, 4, 5, 10, 31] {
            var router = MouseShortcutRouter()
            XCTAssertTrue(router.route(button: button, modifiers: 0, phase: .down, bindings: [:], recording: true).consume)
            let captured = try XCTUnwrap(router.route(button: button, modifiers: 0, phase: .up, bindings: [:], recording: true).captured)
            XCTAssertEqual(captured.mouseButton, button)
            XCTAssertEqual(try JSONDecoder().decode(Shortcut.self, from: JSONEncoder().encode(captured)), captured)
        }
    }
    func testModifiedPrimaryClicksKeepReleaseAfterModifierIsReleased() {
        for button in [0, 1] {
            var router = MouseShortcutRouter()
            let shortcut = Shortcut.mouse(button: button, modifiers: UInt32(controlKey))!
            XCTAssertTrue(router.route(button: button, modifiers: UInt32(controlKey), phase: .down, bindings: [1: shortcut], recording: false).consume)
            XCTAssertTrue(router.route(button: button, modifiers: 0, phase: .drag, bindings: [:], recording: false).consume)
            let release = router.route(button: button, modifiers: 0, phase: .up, bindings: [:], recording: false)
            XCTAssertTrue(release.consume)
            XCTAssertEqual(release.action, 1)
            XCTAssertFalse(router.route(button: button, modifiers: 0, phase: .down, bindings: [1: shortcut], recording: false).consume)
        }
    }
    func testLosingRecordingFocusDoesNotSaveOrFireAction() {
        var router = MouseShortcutRouter()
        _ = router.route(button: 2, modifiers: 0, phase: .down, bindings: [:], recording: true)
        let release = router.route(button: 2, modifiers: 0, phase: .up, bindings: [:], recording: false)
        XCTAssertTrue(release.consume)
        XCTAssertNil(release.captured)
        XCTAssertNil(release.action)
    }
}
