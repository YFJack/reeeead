import XCTest
@testable import Reeeead

// Run scripts/mock-tts.py, then LUMA_LOCAL_API_TESTS=1 swift test -j 1.
// These tests exercise real HTTP, audio decoding, cancellation and redirect handling.
final class IntegrationTests: XCTestCase {
    @MainActor func testMiniMaxJSONAudioAndAPIError() async throws {
        try requireFixture()
        let engine = SpeechEngine()
        var p = Preferences(); p.selectProvider("minimax"); p.endpoint = "http://127.0.0.1:8642/minimax"
        engine.speak("minimax fixture", preferences: p)
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(engine.state, .speaking, engine.message)
        try await Task.sleep(nanoseconds: 2_500_000_000)
        XCTAssertEqual(engine.state, .idle)
        XCTAssertEqual(engine.message, L("朗读完成"))
        p.endpoint = "http://127.0.0.1:8642/minimax-error"
        engine.speak("error fixture", preferences: p)
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(engine.state, .idle)
        XCTAssertTrue(engine.message.contains("1008"))
        XCTAssertFalse(engine.message.contains("do not echo"))
    }
    private func requireFixture() throws {
        guard ProcessInfo.processInfo.environment["LUMA_LOCAL_API_TESTS"] == "1" else { throw XCTSkip("Local API fixture is opt-in. See scripts/mock-tts.py.") }
    }
    @MainActor func testAPIAudioCompletes() async throws {
        try requireFixture()
        let engine = SpeechEngine()
        var p = Preferences(); p.provider = "api"; p.endpoint = "http://127.0.0.1:8642/speech"
        engine.speak("fixture", preferences: p)
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(engine.state, .speaking)
        engine.togglePause(); XCTAssertEqual(engine.state, .paused)
        engine.togglePause(); XCTAssertEqual(engine.state, .speaking)
        try await Task.sleep(nanoseconds: 2_500_000_000)
        XCTAssertEqual(engine.state, .idle)
        XCTAssertEqual(engine.message, L("朗读完成"))
    }
    @MainActor func testCancelPreventsLatePlayback() async throws {
        try requireFixture()
        let engine = SpeechEngine()
        var p = Preferences(); p.provider = "api"; p.endpoint = "http://127.0.0.1:8642/slow"
        engine.speak("cancel fixture", preferences: p)
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(engine.state, .loading)
        engine.stop()
        let stopped = engine.message
        try await Task.sleep(nanoseconds: 5_500_000_000)
        XCTAssertEqual(engine.state, .idle)
        XCTAssertEqual(engine.message, stopped)
    }
    @MainActor func testUnauthorizedAndRedirectAreExplained() async throws {
        try requireFixture()
        let engine = SpeechEngine()
        var p = Preferences(); p.provider = "api"
        p.endpoint = "http://127.0.0.1:8642/unauthorized"
        engine.speak("error fixture", preferences: p)
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(engine.state, .idle)
        XCTAssertTrue(engine.message.contains("401"), engine.message)
        p.endpoint = "http://127.0.0.1:8642/redirect"
        engine.speak("redirect fixture", preferences: p)
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(engine.state, .idle)
        XCTAssertTrue(engine.message == L("接口发生重定向，已停止以保护密钥。请填写最终语音接口地址。"), engine.message)
    }
}
