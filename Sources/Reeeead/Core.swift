import AppKit
import Carbon

struct Shortcut: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
    var label: String
    var mouseButton: Int? = nil
    static let read = Shortcut(keyCode: 15, modifiers: UInt32(controlKey | optionKey), label: "R")
    static let ruler = Shortcut(keyCode: 37, modifiers: UInt32(controlKey | optionKey), label: "L")
    var display: String {
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { s += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { s += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { s += "⌘" }
        return s + (mouseButton.map { "鼠标 \($0 + 1)" } ?? label)
    }
    func conflicts(with other: Shortcut) -> Bool {
        modifiers == other.modifiers && mouseButton == other.mouseButton && (mouseButton != nil || keyCode == other.keyCode)
    }
    static func mouse(button: Int, modifiers: UInt32 = 0) -> Shortcut? {
        guard (3...31).contains(button) else { return nil } // Preserve left, right and middle click.
        return Shortcut(keyCode: 0, modifiers: modifiers, label: "鼠标 \(button + 1)", mouseButton: button)
    }
    static func modifiers(from flags: CGEventFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.maskControl) { result |= UInt32(controlKey) }
        if flags.contains(.maskAlternate) { result |= UInt32(optionKey) }
        if flags.contains(.maskShift) { result |= UInt32(shiftKey) }
        if flags.contains(.maskCommand) { result |= UInt32(cmdKey) }
        return result
    }
    static func from(_ event: NSEvent) -> Shortcut? {
        let f = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !f.intersection([.command, .control, .option]).isEmpty else { return nil }
        let letters: [UInt16: String] = [0:"A",1:"S",2:"D",3:"F",4:"H",5:"G",6:"Z",7:"X",8:"C",9:"V",11:"B",12:"Q",13:"W",14:"E",15:"R",16:"Y",17:"T",18:"1",19:"2",20:"3",21:"4",22:"6",23:"5",24:"=",25:"9",26:"7",27:"−",28:"8",29:"0",30:"]",31:"O",32:"U",33:"[",34:"I",35:"P",37:"L",38:"J",39:"'",40:"K",41:";",42:"\\",43:",",44:"/",45:"N",46:"M",47:".",49:"Space",50:"`"]
        guard let name = letters[event.keyCode] else { return nil }
        var mods: UInt32 = 0
        if f.contains(.control) { mods |= UInt32(controlKey) }
        if f.contains(.option) { mods |= UInt32(optionKey) }
        if f.contains(.shift) { mods |= UInt32(shiftKey) }
        if f.contains(.command) { mods |= UInt32(cmdKey) }
        return Shortcut(keyCode: UInt32(event.keyCode), modifiers: mods, label: name)
    }
}

// Keep a press/release pair together even if modifiers change before release.
struct MouseShortcutRouter {
    enum Phase { case down, up, drag }
    struct Decision {
        var consume = false
        var action: UInt32?
        var captured: Shortcut?
    }
    private struct Press { let shortcut: Shortcut; let action: UInt32? }
    private var presses: [Int: Press] = [:]
    mutating func route(button: Int, modifiers: UInt32, phase: Phase, bindings: [UInt32: Shortcut], recording: Bool) -> Decision {
        guard let shortcut = Shortcut.mouse(button: button, modifiers: modifiers) else { return Decision() }
        switch phase {
        case .down:
            if presses[button] != nil { return Decision(consume: true) }
            let action = bindings.first { $0.value.conflicts(with: shortcut) }?.key
            guard recording || action != nil else { return Decision() }
            presses[button] = Press(shortcut: shortcut, action: action)
            return Decision(consume: true)
        case .drag:
            return Decision(consume: presses[button] != nil)
        case .up:
            guard let press = presses.removeValue(forKey: button) else { return Decision() }
            return Decision(consume: true, action: press.action, captured: recording ? press.shortcut : nil)
        }
    }
}

struct VoiceProfile: Codable {
    var endpoint: String
    var model: String
    var voice: String
}

struct Preferences: Codable {
    var provider = "system"
    var speed = 1.0
    var systemVoice = ""
    var endpoint = "https://api.openai.com/v1/audio/speech"
    var model = "tts-1"
    var voice = "alloy"
    var readShortcut = Shortcut.read
    var rulerShortcut = Shortcut.ruler
    var dimOpacity = 0.62
    var lineWidth = 2.0
    var lineColor = "sage"
    var copyFallback = true
    var voiceProfiles: [String: VoiceProfile]? = nil
    mutating func selectProvider(_ next: String) {
        guard next != provider else { return }
        var profiles = voiceProfiles ?? [:]
        if provider != "system" { profiles[provider] = VoiceProfile(endpoint: endpoint, model: model, voice: voice) }
        provider = next
        if next != "system" {
            let profile = profiles[next] ?? (next == "minimax"
                ? VoiceProfile(endpoint: "https://api.minimax.cn/v1/t2a_v2", model: "speech-2.8-hd", voice: "male-qn-qingse")
                : VoiceProfile(endpoint: "https://api.openai.com/v1/audio/speech", model: "tts-1", voice: "alloy"))
            endpoint = profile.endpoint; model = profile.model; voice = profile.voice
        }
        voiceProfiles = profiles
    }
    static func load(from defaults: UserDefaults = .standard) -> Preferences {
        guard let data = defaults.data(forKey: "preferences.v1"),
              var value = try? JSONDecoder().decode(Preferences.self, from: data) else { return Preferences() }
        value.speed = min(2, max(0.5, value.speed))
        value.dimOpacity = min(0.9, max(0.2, value.dimOpacity))
        value.lineWidth = min(4, max(1, value.lineWidth))
        return value
    }
    func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: "preferences.v1") }
    }
}

struct RulerGeometry: Equatable {
    enum Phase { case tracking, extending, locked }
    private(set) var phase: Phase = .tracking
    private(set) var anchor: CGFloat = 0
    private(set) var cursor: CGFloat = 0
    let height: CGFloat
    mutating func move(to y: CGFloat) {
        guard phase != .locked else { return }
        cursor = min(height, max(0, y))
        if phase == .extending { cursor = max(anchor, cursor) }
    }
    @discardableResult mutating func click(at y: CGFloat) -> Bool {
        move(to: y)
        switch phase {
        case .tracking:
            anchor = min(cursor, max(0, height - 8))
            cursor = anchor
            phase = .extending
        case .extending:
            guard cursor - anchor >= 8 else { return false }
            phase = .locked
        case .locked: break
        }
        return phase == .locked
    }
}

enum LumaError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case let .message(m) = self { return m }; return nil }
}

enum SpeechRequest {
    static let maximumCharacters = 4000
    static func validatedURL(_ endpoint: String) throws -> URL {
        guard let url = URL(string: endpoint.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = url.host, !host.isEmpty, url.user == nil, url.password == nil,
              url.query == nil, url.fragment == nil,
              url.scheme == "https" || (url.scheme == "http" && ["localhost", "127.0.0.1", "[::1]", "::1"].contains(host)) else {
            throw LumaError.message("请输入完整 HTTPS 语音接口地址；本机 localhost 可使用 HTTP。地址不能包含密码、查询参数或片段。")
        }
        return url
    }
    static func make(text: String, preferences: Preferences, key: String) throws -> URLRequest {
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { throw LumaError.message("先选中一段文字，再开始朗读。") }
        guard content.count <= maximumCharacters else { throw LumaError.message("这段文字超过 4,000 字，请分段选择后朗读。") }
        guard !preferences.model.trimmingCharacters(in: .whitespaces).isEmpty,
              !preferences.voice.trimmingCharacters(in: .whitespaces).isEmpty else { throw LumaError.message("请填写模型和音色。") }
        var request = URLRequest(url: try validatedURL(preferences.endpoint))
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !key.isEmpty { request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization") }
        let body: [String: Any]
        if preferences.provider == "minimax" {
            body = ["model": preferences.model, "text": content, "stream": false, "output_format": "hex", "language_boost": "auto",
                    "voice_setting": ["voice_id": preferences.voice, "speed": min(2, max(0.5, preferences.speed)), "vol": 1, "pitch": 0],
                    "audio_setting": ["sample_rate": 32000, "bitrate": 128000, "format": "mp3", "channel": 1]]
        } else {
            body = ["model": preferences.model, "voice": preferences.voice, "input": content, "speed": min(2, max(0.5, preferences.speed)), "response_format": "mp3"]
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }
}

enum SpeechResponse {
    static func audio(_ data: Data, provider: String) throws -> Data {
        guard provider == "minimax" else { return data }
        struct Payload: Decodable {
            struct Status: Decodable { let status_code: Int }
            struct Audio: Decodable { let audio: String?; let status: Int? }
            let base_resp: Status
            let data: Audio?
        }
        guard let response = try? JSONDecoder().decode(Payload.self, from: data) else { throw LumaError.message("MiniMax 返回了无法识别的响应。") }
        guard response.base_resp.status_code == 0 else {
            let code = response.base_resp.status_code
            // Never echo provider messages: custom endpoints may reflect credentials or text.
            let hint: String
            switch code {
            case 1004, 2049: hint = "请检查 API Key 及其所属地区的接口地址。"
            case 1008: hint = "账户余额不足，请检查 MiniMax 账户。"
            case 1002: hint = "请求过于频繁，请稍后重试。"
            default: hint = "请检查模型、音色和账户权限。"
            }
            throw LumaError.message("MiniMax 错误 \(code)。\(hint)")
        }
        guard let encoded = response.data?.audio, response.data?.status == 2,
              !encoded.isEmpty, encoded.utf8.count <= 48 * 1024 * 1024, encoded.utf8.count % 2 == 0 else {
            throw LumaError.message("MiniMax 没有返回完整的音频，请缩短文字后重试。")
        }
        var audio = Data(capacity: encoded.utf8.count / 2)
        var high: UInt8?
        for c in encoded.utf8 {
            let value: UInt8
            switch c {
            case 48...57: value = c - 48
            case 65...70: value = c - 55
            case 97...102: value = c - 87
            default: throw LumaError.message("MiniMax 音频编码无效。")
            }
            if let h = high { audio.append(h << 4 | value); high = nil } else { high = value }
        }
        return audio
    }
}
