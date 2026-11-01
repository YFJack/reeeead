import XCTest
@testable import Reeeead

final class MiniMaxTests: XCTestCase {
    func testRequestUsesNativeMiniMaxProtocol() throws {
        var p = Preferences(); p.selectProvider("minimax"); p.speed = 1.3
        let request = try SpeechRequest.make(text: "  你好  ", preferences: p, key: "test-only")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: request.httpBody!) as? [String: Any])
        XCTAssertEqual(request.url?.absoluteString, "https://api.minimax.cn/v1/t2a_v2")
        XCTAssertEqual(body["text"] as? String, "你好")
        XCTAssertEqual(body["output_format"] as? String, "hex")
        XCTAssertEqual(body["stream"] as? Bool, false)
        XCTAssertNil(body["input"])
        let voice = try XCTUnwrap(body["voice_setting"] as? [String: Any])
        XCTAssertEqual(voice["voice_id"] as? String, "male-qn-qingse")
        XCTAssertEqual(voice["speed"] as? Double, 1.3)
    }
    func testSwitchingProvidersPreservesIndependentConfiguration() {
        var p = Preferences(); p.provider = "api"; p.endpoint = "https://example.com/speech"; p.model = "custom"; p.voice = "my-voice"
        p.selectProvider("minimax"); p.voice = "minimax-voice"
        p.selectProvider("system"); p.selectProvider("api")
        XCTAssertEqual(p.endpoint, "https://example.com/speech")
        XCTAssertEqual(p.model, "custom")
        XCTAssertEqual(p.voice, "my-voice")
        p.selectProvider("minimax")
        XCTAssertEqual(p.voice, "minimax-voice")
    }
    func testDecodeCompleteHexAudio() throws {
        let data = Data(#"{"base_resp":{"status_code":0},"data":{"audio":"49443300ffAB","status":2}}"#.utf8)
        XCTAssertEqual(try SpeechResponse.audio(data, provider: "minimax"), Data([0x49,0x44,0x33,0,255,171]))
        XCTAssertEqual(try SpeechResponse.audio(Data([1,2]), provider: "api"), Data([1,2]))
    }
    func testRejectsMissingPartialEmptyAndMalformedAudio() {
        for body in [#"{"base_resp":{"status_code":0},"data":null}"#,
                     #"{"base_resp":{"status_code":0},"data":{"audio":"00","status":1}}"#,
                     #"{"base_resp":{"status_code":0},"data":{"audio":"","status":2}}"#,
                     #"{"base_resp":{"status_code":0},"data":{"audio":"xyz","status":2}}"#,
                     #"{"base_resp":{"status_code":0},"data":{"audio":"zz","status":2}}"#,
                     #"{"data":{"audio":"00","status":2}}"#] {
            XCTAssertThrowsError(try SpeechResponse.audio(Data(body.utf8), provider: "minimax"))
        }
    }
    func testAPIErrorInsideHTTP200DoesNotExposeProviderMessage() {
        let data = Data(#"{"base_resp":{"status_code":1004,"status_msg":"private credential echo"},"data":null}"#.utf8)
        XCTAssertThrowsError(try SpeechResponse.audio(data, provider: "minimax")) { error in
            XCTAssertTrue(error.localizedDescription.contains("1004"))
            XCTAssertFalse(error.localizedDescription.contains("private"))
        }
    }
}
