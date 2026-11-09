import XCTest
import AppKit
import Carbon
import QuartzCore
@testable import Reeeead

final class WindowFocusTests: XCTestCase {
    func testDefaultRequiresOnlyLeftShiftAndSurvivesEarlyModifierRelease() {
        var router = KeyboardShortcutRouter()
        let bindings: [UInt32: Shortcut] = [3: .focus]
        for flags in [CGEventFlags.maskShift, CGEventFlags(rawValue: CGEventFlags.maskShift.rawValue | 4), CGEventFlags(rawValue: CGEventFlags.maskShift.rawValue | 6), []] {
            XCTAssertFalse(router.route(keyCode: 53, flags: flags, down: true, bindings: bindings).consume)
        }
        let left = CGEventFlags(rawValue: CGEventFlags.maskShift.rawValue | 2)
        XCTAssertTrue(router.route(keyCode: 53, flags: left, down: true, bindings: bindings).consume)
        XCTAssertNil(router.route(keyCode: 53, flags: left, down: true, repeatKey: true, bindings: bindings).action)
        XCTAssertEqual(router.route(keyCode: 53, flags: [], down: false, bindings: bindings).action, 3)
        XCTAssertFalse(router.route(keyCode: 53, flags: [], down: false, bindings: bindings).consume)
    }

    func testOldPreferencesKeepVoiceAndShortcutsAndReceiveFocusDefault() throws {
        var old = Preferences()
        old.provider = "api"; old.speed = 1.75; old.voice = "existing-voice"
        old.rulerShortcut = Shortcut(keyCode: 18, modifiers: UInt32(cmdKey | optionKey), label: "1")
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as? [String: Any])
        object.removeValue(forKey: "windowFocusShortcut")
        let decoded = try JSONDecoder().decode(Preferences.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(decoded.focusShortcut, .focus)
        XCTAssertEqual(decoded.rulerShortcut, old.rulerShortcut)
        XCTAssertEqual(decoded.voice, old.voice)
        XCTAssertEqual(decoded.speed, old.speed)
        XCTAssertEqual(decoded.provider, old.provider)
        var custom = decoded
        custom.focusShortcut = .mouse(button: 4)!
        XCTAssertEqual(try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(custom)).focusShortcut, custom.focusShortcut)
    }

    func testPrimaryAndExternalDisplayCoordinatesIncludingAboveAndLeft() throws {
        let primary = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let window = try XCTUnwrap(WindowFocusGeometry.appKitRect(CGRect(x: 100, y: 40, width: 800, height: 600), primaryHeight: 900))
        XCTAssertEqual(window, CGRect(x: 100, y: 260, width: 800, height: 600))
        XCTAssertEqual(WindowFocusGeometry.cutout(window: window, screen: primary), window)
        let above = CGRect(x: 0, y: 900, width: 1920, height: 1080)
        let upperWindow = try XCTUnwrap(WindowFocusGeometry.appKitRect(CGRect(x: 50, y: -1000, width: 900, height: 700), primaryHeight: 900))
        XCTAssertEqual(WindowFocusGeometry.cutout(window: upperWindow, screen: above), CGRect(x: 50, y: 300, width: 900, height: 700))
        XCTAssertNil(WindowFocusGeometry.cutout(window: upperWindow, screen: primary))
        let left = CGRect(x: -1920, y: 0, width: 1920, height: 1080)
        let spanning = CGRect(x: -200, y: 100, width: 700, height: 500)
        XCTAssertEqual(WindowFocusGeometry.cutout(window: spanning, screen: left), CGRect(x: 1720, y: 100, width: 700, height: 500))
        XCTAssertEqual(WindowFocusGeometry.cutout(window: spanning, screen: primary), CGRect(x: -200, y: 100, width: 700, height: 500))
    }

    func testInvalidWindowsNeverProduceAHole() {
        XCTAssertNil(WindowFocusGeometry.appKitRect(.zero, primaryHeight: 900))
        XCTAssertNil(WindowFocusGeometry.appKitRect(CGRect(x: CGFloat.infinity, y: 0, width: 30, height: 40), primaryHeight: 900))
        XCTAssertNil(WindowFocusGeometry.cutout(window: CGRect(x: 1500, y: 0, width: 30, height: 40), screen: CGRect(x: 0, y: 0, width: 1440, height: 900)))
    }

    @MainActor func testMaskLeavesWindowClearAndClearsOldHoleWhenItMoves() throws {
        let canvas = WindowFocusCanvas(frame: CGRect(x: 0, y: 0, width: 100, height: 100), opacity: 0.62)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 100, pixelsHigh: 100,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let context = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap))
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = context
        canvas.cutout = CGRect(x: 20, y: 20, width: 60, height: 60)
        canvas.draw(canvas.bounds)
        XCTAssertEqual(try XCTUnwrap(bitmap.colorAt(x: 50, y: 50)).alphaComponent, 0, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(bitmap.colorAt(x: 5, y: 5)).alphaComponent, 0.62, accuracy: 0.01)
        canvas.cutout = nil // Window moved to another display.
        canvas.draw(canvas.bounds)
        XCTAssertEqual(try XCTUnwrap(bitmap.colorAt(x: 50, y: 50)).alphaComponent, 0.62, accuracy: 0.01)
    }
    func testFocusOpacityPersistsFullRangeWithoutChangingRuler() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "ReeeeadOpacityTest"))
        defer { defaults.removePersistentDomain(forName: "ReeeeadOpacityTest") }
        var preferences = Preferences()
        preferences.dimOpacity = 0.62
        XCTAssertEqual(preferences.focusOpacity, 0.62)
        for opacity in [0.0, 0.01, 0.5, 0.99, 1.0] {
            preferences.focusOpacity = opacity
            preferences.save(to: defaults)
            let restored = Preferences.load(from: defaults)
            XCTAssertEqual(restored.focusOpacity, opacity, accuracy: 0.0001)
            XCTAssertEqual(restored.dimOpacity, 0.62)
        }
    }

    @MainActor func testOpacityChangesRepaintAndAllowFullyClearOrOpaque() throws {
        let canvas = WindowFocusCanvas(frame: CGRect(x: 0, y: 0, width: 100, height: 100), opacity: 1)
        canvas.cutout = CGRect(x: 25, y: 25, width: 50, height: 50)
        let panel = RulerPanel(screenFrame: canvas.frame)
        panel.ignoresMouseEvents = true
        panel.contentView = canvas
        panel.orderFrontRegardless()
        defer { panel.orderOut(nil); panel.contentView = nil }
        let bitmap = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 100, pixelsHigh: 100,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap))
        for opacity in [1.0, 0.0, 0.37] {
            canvas.needsDisplay = false
            canvas.opacity = opacity
            XCTAssertTrue(canvas.needsDisplay)
            canvas.draw(canvas.bounds)
            XCTAssertEqual(try XCTUnwrap(bitmap.colorAt(x: 5, y: 5)).alphaComponent, opacity, accuracy: 0.01)
            XCTAssertEqual(try XCTUnwrap(bitmap.colorAt(x: 50, y: 50)).alphaComponent, 0, accuracy: 0.01)
        }
    }
    @MainActor func testRoundedHoleDoesNotLeakAtCornersOrRoundDisplaySeams() throws {
        let canvas = WindowFocusCanvas(frame: CGRect(x: 0, y: 0, width: 100, height: 100), opacity: 1)
        canvas.cutout = CGRect(x: 20, y: 20, width: 60, height: 60)
        canvas.cornerRadius = 12
        let path = canvas.maskPath()
        XCTAssertTrue(path.contains(CGPoint(x: 21, y: 21), using: .evenOdd))
        XCTAssertFalse(path.contains(CGPoint(x: 32, y: 21), using: .evenOdd))
        XCTAssertFalse(path.contains(CGPoint(x: 50, y: 50), using: .evenOdd))
        canvas.cutout = WindowFocusGeometry.cutout(window: CGRect(x: -80, y: 20, width: 160, height: 60), screen: canvas.bounds)
        XCTAssertFalse(canvas.maskPath().contains(CGPoint(x: 1, y: 21), using: .evenOdd), "A display edge is not a window corner")
        canvas.cornerRadius = 0
        canvas.cutout = canvas.bounds
        XCTAssertFalse(canvas.maskPath().contains(CGPoint(x: 1, y: 1), using: .evenOdd))
    }

    @MainActor func testLiveLayerUsesCurrentPathWithoutTrailingAnimation() throws {
        let canvas = WindowFocusCanvas(frame: CGRect(x: 0, y: 0, width: 100, height: 100), opacity: 0.6)
        canvas.cutout = CGRect(x: 20, y: 20, width: 40, height: 40)
        canvas.updateShape()
        let layer = try XCTUnwrap(canvas.layer as? CAShapeLayer)
        XCTAssertEqual(layer.fillRule, .evenOdd)
        XCTAssertTrue(layer.masksToBounds)
        canvas.cutout = CGRect(x: 60, y: 20, width: 40, height: 40)
        canvas.updateShape()
        XCTAssertTrue(try XCTUnwrap(layer.path).contains(CGPoint(x: 40, y: 40), using: .evenOdd))
        XCTAssertFalse(try XCTUnwrap(layer.path).contains(CGPoint(x: 80, y: 40), using: .evenOdd))
        XCTAssertTrue(layer.animationKeys()?.isEmpty ?? true)
    }

    func testLegacyCornerDefaultAndCustomRadiusPersistence() throws {
        let preferences = Preferences()
        XCTAssertEqual(preferences.focusCornerRadius, 12)
        var custom = preferences
        custom.focusCornerRadius = 0
        XCTAssertEqual(try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(custom)).focusCornerRadius, 0)
        custom.focusCornerRadius = 24
        XCTAssertEqual(try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(custom)).focusCornerRadius, 24)
    }
}
