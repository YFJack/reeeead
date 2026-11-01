import XCTest
@testable import Luma

final class CoreTests: XCTestCase {
    func testRulerTwoClicksAndLockedPosition() {
        var r = RulerGeometry(height: 900)
        r.move(to: 200)
        XCTAssertEqual(r.phase, .tracking)
        XCTAssertFalse(r.click(at: 200))
        r.move(to: 360)
        XCTAssertEqual(r.anchor, 200)
        XCTAssertEqual(r.cursor, 360)
        XCTAssertTrue(r.click(at: 360))
        r.move(to: 600)
        XCTAssertEqual(r.cursor, 360)
        XCTAssertEqual(r.phase, .locked)
    }
    func testRulerDoesNotInvertOrLockEmptyBand() {
        var r = RulerGeometry(height: 500)
        r.click(at: 200)
        r.move(to: 100)
        XCTAssertEqual(r.cursor, 200)
        XCTAssertFalse(r.click(at: 200))
        XCTAssertFalse(r.click(at: 207))
        XCTAssertTrue(r.click(at: 208))
    }
    func testRulerScreenBounds() {
        var r = RulerGeometry(height: 500)
        r.move(to: -50); XCTAssertEqual(r.cursor, 0)
        r.click(at: 600); XCTAssertEqual(r.anchor, 492)
        XCTAssertTrue(r.click(at: 900)); XCTAssertEqual(r.cursor, 500)
    }
    func testRequestBodyAndSpeed() throws {
        var p = Preferences(); p.speed = 1.35; p.model = "custom-model"; p.voice = "custom-voice"
        let request = try SpeechRequest.make(text: "  你好，世界  ", preferences: p, key: "test-only")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-only")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: request.httpBody!) as? [String: Any])
        XCTAssertEqual(body["input"] as? String, "你好，世界")
        XCTAssertEqual(body["speed"] as? Double, 1.35)
        XCTAssertEqual(body["model"] as? String, "custom-model")
        XCTAssertEqual(body["voice"] as? String, "custom-voice")
        XCTAssertEqual(body["response_format"] as? String, "mp3")
    }
    func testEndpointAndInputValidation() throws {
        for value in ["http://example.com/speech", "https://user:pass@example.com/speech", "file:///tmp/audio", "https://example.com/speech?key=secret", "https://example.com/speech#key"] {
            XCTAssertThrowsError(try SpeechRequest.validatedURL(value), value)
        }
        XCTAssertNoThrow(try SpeechRequest.validatedURL("http://127.0.0.1:8642/speech"))
        XCTAssertNoThrow(try SpeechRequest.validatedURL("https://example.com/speech"))
        XCTAssertThrowsError(try SpeechRequest.make(text: "\n ", preferences: Preferences(), key: ""))
        XCTAssertThrowsError(try SpeechRequest.make(text: String(repeating: "字", count: 4001), preferences: Preferences(), key: ""))
        let request = try SpeechRequest.make(text: "hello", preferences: Preferences(), key: "")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
    }
    func testPreferencesRoundTrip() throws {
        let name = "LumaTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        var p = Preferences(); p.speed = 1.5; p.provider = "api"; p.dimOpacity = 0.7
        p.save(to: defaults)
        let loaded = Preferences.load(from: defaults)
        XCTAssertEqual(loaded.speed, 1.5)
        XCTAssertEqual(loaded.provider, "api")
        XCTAssertEqual(loaded.dimOpacity, 0.7)
        XCTAssertEqual(loaded.readShortcut, .read)
    }
}
