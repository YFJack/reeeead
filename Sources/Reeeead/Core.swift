import AppKit
import Carbon

enum ShiftSide: String, Codable {
    case left, right, both

    static func from(_ flags: CGEventFlags) -> ShiftSide? {
        guard flags.contains(.maskShift) else { return nil }
        // Public device flags from IOKit/hidsystem/IOLLEvent.h:
        // NX_DEVICELSHIFTKEYMASK = 0x2, NX_DEVICERSHIFTKEYMASK = 0x4.
        switch flags.rawValue & 0x6 {
        case 0x2: return .left
        case 0x4: return .right
        case 0x6: return .both
        default: return nil // Legacy/synthetic events may only carry generic Shift.
        }
    }

    var display: String {
        switch self {
        case .left: return L("左 ⇧")
        case .right: return L("右 ⇧")
        case .both: return L("左右 ⇧")
        }
    }
}

struct Shortcut: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
    var label: String
    var mouseButton: Int? = nil
    var shiftSide: ShiftSide? = nil // Missing in old preferences: either Shift remains valid.
    static let read = Shortcut(keyCode: 15, modifiers: UInt32(controlKey | optionKey), label: "R")
    static let ruler = Shortcut(keyCode: 37, modifiers: UInt32(controlKey | optionKey), label: "L")
    static let focus = Shortcut(keyCode: 53, modifiers: UInt32(shiftKey), label: "⎋", shiftSide: .left)
    var display: String {
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { s += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { s += shiftSide?.display ?? "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { s += "⌘" }
        return s + (mouseButton.map { L("鼠标 %@", String($0 + 1)) } ?? label)
    }
    func conflicts(with other: Shortcut) -> Bool {
        sameInput(as: other) && (shiftSide == nil || other.shiftSide == nil || shiftSide == other.shiftSide)
    }
    func matches(_ input: Shortcut) -> Bool {
        sameInput(as: input) && (shiftSide == nil || shiftSide == input.shiftSide)
    }
    private func sameInput(as other: Shortcut) -> Bool {
        modifiers == other.modifiers && mouseButton == other.mouseButton && (mouseButton != nil || keyCode == other.keyCode)
    }
    static func mouse(button: Int, modifiers: UInt32 = 0, shiftSide: ShiftSide? = nil) -> Shortcut? {
        // Plain primary/secondary clicks remain available for ordinary UI interaction.
        guard (0...31).contains(button), button >= 2 || modifiers != 0 else { return nil }
        return Shortcut(keyCode: 0, modifiers: modifiers, label: L("鼠标 %@", String(button + 1)), mouseButton: button, shiftSide: shiftSide)
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
        guard event.type == .keyDown || event.type == .keyUp else { return nil }
        let letters: [UInt16: String] = [0:"A",1:"S",2:"D",3:"F",4:"H",5:"G",6:"Z",7:"X",8:"C",9:"V",11:"B",12:"Q",13:"W",14:"E",15:"R",16:"Y",17:"T",18:"1",19:"2",20:"3",21:"4",22:"6",23:"5",24:"=",25:"9",26:"7",27:"−",28:"8",29:"0",30:"]",31:"O",32:"U",33:"[",34:"I",35:"P",37:"L",38:"J",39:"'",40:"K",41:";",42:"\\",43:",",44:"/",45:"N",46:"M",47:".",49:"Space",50:"`"]
        let special: [UInt16: String] = [36:"↩",48:"⇥",51:"⌫",53:"⎋",64:"F17",65:"Num .",67:"Num *",69:"Num +",71:"Clear",75:"Num /",76:"Num ↩",78:"Num −",79:"F18",80:"F19",81:"Num =",82:"Num 0",83:"Num 1",84:"Num 2",85:"Num 3",86:"Num 4",87:"Num 5",88:"Num 6",89:"Num 7",90:"F20",91:"Num 8",92:"Num 9",96:"F5",97:"F6",98:"F7",99:"F3",100:"F8",101:"F9",103:"F11",105:"F13",106:"F16",107:"F14",109:"F10",111:"F12",113:"F15",114:"Help",115:"Home",116:"Page ↑",117:"⌦",118:"F4",119:"End",120:"F2",121:"Page ↓",122:"F1",123:"←",124:"→",125:"↓",126:"↑"]
        let printable = event.charactersIgnoringModifiers?.uppercased().filter { character in
            character.unicodeScalars.allSatisfy { !CharacterSet.controlCharacters.contains($0) && !(0xF700...0xF8FF).contains($0.value) }
        }
        guard let name = special[event.keyCode] ?? letters[event.keyCode] ?? printable, !name.isEmpty else { return nil }
        var mods: UInt32 = 0
        if f.contains(.control) { mods |= UInt32(controlKey) }
        if f.contains(.option) { mods |= UInt32(optionKey) }
        if f.contains(.shift) { mods |= UInt32(shiftKey) }
        if f.contains(.command) { mods |= UInt32(cmdKey) }
        return Shortcut(keyCode: UInt32(event.keyCode), modifiers: mods, label: name,
                        shiftSide: ShiftSide.from(CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue))))
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
    mutating func route(button: Int, modifiers: UInt32, phase: Phase, bindings: [UInt32: Shortcut], recording: Bool, shiftSide: ShiftSide? = nil) -> Decision {
        switch phase {
        case .down:
            if presses[button] != nil { return Decision(consume: true) }
            guard let shortcut = Shortcut.mouse(button: button, modifiers: modifiers, shiftSide: shiftSide) else { return Decision() }
            let action = bindings.first { $0.value.matches(shortcut) }?.key
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

// Side-specific keyboard combinations cannot use Carbon's generic Shift flag.
// Keep matched down/up pairs together even when Shift is released before the key.
struct KeyboardShortcutRouter {
    struct Decision { var consume = false; var action: UInt32? }
    private var presses: [UInt32: UInt32] = [:]

    mutating func route(keyCode: UInt32, flags: CGEventFlags, down: Bool, repeatKey: Bool = false,
                        bindings: [UInt32: Shortcut]) -> Decision {
        if !down {
            guard let action = presses.removeValue(forKey: keyCode) else { return Decision() }
            return Decision(consume: true, action: action)
        }
        if presses[keyCode] != nil { return Decision(consume: true) }
        guard !repeatKey else { return Decision() }
        let input = Shortcut(keyCode: keyCode, modifiers: Shortcut.modifiers(from: flags), label: "",
                             shiftSide: ShiftSide.from(flags))
        guard let action = bindings.first(where: { $0.value.matches(input) })?.key else { return Decision() }
        presses[keyCode] = action
        return Decision(consume: true)
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
    // Optional storage preserves decoding of existing preferences.
    var windowFocusShortcut: Shortcut? = nil
    var focusShortcut: Shortcut {
        get { windowFocusShortcut ?? .focus }
        set { windowFocusShortcut = newValue }
    }
    var dimOpacity = 0.62
    var windowFocusOpacity: Double? = nil
    var focusOpacity: Double {
        get { min(1, max(0, windowFocusOpacity ?? dimOpacity)) }
        set { windowFocusOpacity = min(1, max(0, newValue)) }
    }
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
            throw LumaError.message(L("请输入完整 HTTPS 语音接口地址；本机 localhost 可使用 HTTP。地址不能包含密码、查询参数或片段。"))
        }
        return url
    }
    static func make(text: String, preferences: Preferences, key: String) throws -> URLRequest {
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { throw LumaError.message(L("先选中一段文字，再开始朗读。")) }
        guard content.count <= maximumCharacters else { throw LumaError.message(L("这段文字超过 4,000 字，请分段选择后朗读。")) }
        guard !preferences.model.trimmingCharacters(in: .whitespaces).isEmpty,
              !preferences.voice.trimmingCharacters(in: .whitespaces).isEmpty else { throw LumaError.message(L("请填写模型和音色。")) }
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
        guard let response = try? JSONDecoder().decode(Payload.self, from: data) else { throw LumaError.message(L("MiniMax 返回了无法识别的响应。")) }
        guard response.base_resp.status_code == 0 else {
            let code = response.base_resp.status_code
            // Never echo provider messages: custom endpoints may reflect credentials or text.
            let hint: String
            switch code {
            case 1004, 2049: hint = L("请检查 API Key 及其所属地区的接口地址。")
            case 1008: hint = L("账户余额不足，请检查 MiniMax 账户。")
            case 1002: hint = L("请求过于频繁，请稍后重试。")
            default: hint = L("请检查模型、音色和账户权限。")
            }
            throw LumaError.message(L("MiniMax 错误 %@。%@", String(code), String(hint)))
        }
        guard let encoded = response.data?.audio, response.data?.status == 2,
              !encoded.isEmpty, encoded.utf8.count <= 48 * 1024 * 1024, encoded.utf8.count % 2 == 0 else {
            throw LumaError.message(L("MiniMax 没有返回完整的音频，请缩短文字后重试。"))
        }
        var audio = Data(capacity: encoded.utf8.count / 2)
        var high: UInt8?
        for c in encoded.utf8 {
            let value: UInt8
            switch c {
            case 48...57: value = c - 48
            case 65...70: value = c - 55
            case 97...102: value = c - 87
            default: throw LumaError.message(L("MiniMax 音频编码无效。"))
            }
            if let h = high { audio.append(h << 4 | value); high = nil } else { high = value }
        }
        return audio
    }
}
