import AppKit
import AVFoundation
import Security

enum KeyStore {
    private static func query(_ endpoint: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "app.luma.reader.speech", kSecAttrAccount as String: endpoint.trimmingCharacters(in: .whitespacesAndNewlines)]
    }
    static func read(endpoint: String) throws -> String {
        var q = query(endpoint)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var value: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &value)
        if status == errSecItemNotFound { return "" }
        guard status == errSecSuccess, let data = value as? Data, let key = String(data: data, encoding: .utf8) else {
            throw LumaError.message(L("无法读取钥匙串（%@）。请解锁系统钥匙串后重试。", String(status)))
        }
        return key
    }
    static func save(_ key: String, endpoint: String) throws {
        _ = try SpeechRequest.validatedURL(endpoint)
        let q = query(endpoint)
        let fields = [kSecValueData as String: Data(key.utf8)]
        var status = SecItemUpdate(q as CFDictionary, fields as CFDictionary)
        if status == errSecItemNotFound {
            var item = q
            item[kSecValueData as String] = Data(key.utf8)
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
            status = SecItemAdd(item as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw LumaError.message(L("密钥保存失败（%@），尚未写入钥匙串。", String(status))) }
    }
    static func delete(endpoint: String) throws {
        let status = SecItemDelete(query(endpoint) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw LumaError.message(L("密钥删除失败（%@）。", String(status))) }
    }
}

// Do not forward bearer credentials through redirects. Bound downloads even for custom providers.
final class AudioDownloadPolicy: NSObject, URLSessionDownloadDelegate {
    static let maximumBytes: Int64 = 24 * 1024 * 1024
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesWritten > Self.maximumBytes || totalBytesExpectedToWrite > Self.maximumBytes { downloadTask.cancel() }
    }
}

@MainActor final class SpeechEngine: NSObject, ObservableObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    enum State { case idle, loading, speaking, paused }
    @Published private(set) var state: State = .idle
    @Published private(set) var message = L("就绪")
    private let synth = AVSpeechSynthesizer()
    private var player: AVAudioPlayer?
    private var task: Task<Void, Never>?
    private var generation = UUID()
    private var activeUtterance: AVSpeechUtterance?
    var busy: Bool { state != .idle }
    override init() { super.init(); synth.delegate = self }
    func show(_ text: String) { message = text }
    func stop() {
        generation = UUID()
        task?.cancel(); task = nil
        activeUtterance = nil
        synth.stopSpeaking(at: .immediate)
        player?.stop(); player = nil
        state = .idle
        message = L("已停止")
    }
    func togglePause() {
        if state == .speaking {
            if player != nil { player?.pause() } else { synth.pauseSpeaking(at: .immediate) }
            state = .paused; message = L("已暂停")
        } else if state == .paused {
            if player != nil { player?.play() } else { synth.continueSpeaking() }
            state = .speaking; message = L("正在朗读…")
        }
    }
    func selection(preferences: Preferences) {
        if busy { stop(); return }
        begin(preferences: preferences) { try await SelectionReader.read(useCopyFallback: preferences.copyFallback) }
    }
    func speak(_ text: String, preferences: Preferences) {
        begin(preferences: preferences) { text }
    }
    private func begin(preferences: Preferences, text: @escaping () async throws -> String) {
        stop()
        let token = UUID(); generation = token
        state = .loading
        message = preferences.provider == "system" ? L("正在准备朗读…") : L("正在请求语音服务…")
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let content = try await text().trimmingCharacters(in: .whitespacesAndNewlines)
                try Task.checkCancellation()
                guard self.generation == token else { return }
                guard !content.isEmpty else { throw LumaError.message(L("先选中或输入一段文字。")) }
                guard content.count <= SpeechRequest.maximumCharacters else { throw LumaError.message(L("文字超过 4,000 字，请分段朗读。")) }
                if preferences.provider == "system" {
                    let utterance = AVSpeechUtterance(string: content)
                    if !preferences.systemVoice.isEmpty { utterance.voice = AVSpeechSynthesisVoice(identifier: preferences.systemVoice) }
                    if utterance.voice == nil {
                        let chinese = content.unicodeScalars.contains { (0x3400...0x9FFF).contains(Int($0.value)) }
                        utterance.voice = AVSpeechSynthesisVoice(language: chinese ? "zh-CN" : "en-US")
                    }
                    utterance.rate = min(AVSpeechUtteranceMaximumSpeechRate, max(AVSpeechUtteranceMinimumSpeechRate, AVSpeechUtteranceDefaultSpeechRate * Float(preferences.speed)))
                    self.activeUtterance = utterance
                    self.state = .speaking; self.message = L("正在朗读 · 系统语音")
                    self.synth.speak(utterance)
                } else {
                    let key = try KeyStore.read(endpoint: preferences.endpoint)
                    let request = try SpeechRequest.make(text: content, preferences: preferences, key: key)
                    let config = URLSessionConfiguration.ephemeral
                    config.timeoutIntervalForRequest = 45
                    config.timeoutIntervalForResource = 90
                    config.httpMaximumConnectionsPerHost = 1
                    config.urlCache = nil
                    let policy = AudioDownloadPolicy()
                    let session = URLSession(configuration: config, delegate: policy, delegateQueue: nil)
                    defer { session.invalidateAndCancel() }
                    let (file, response) = try await session.download(for: request)
                    defer { try? FileManager.default.removeItem(at: file) }
                    try Task.checkCancellation()
                    guard self.generation == token else { return }
                    guard let http = response as? HTTPURLResponse else { throw LumaError.message(L("语音服务没有返回有效响应。")) }
                    switch http.statusCode {
                    case 200..<300: break
                    case 401, 403: throw LumaError.message(L("语音服务拒绝访问（%@）。请检查该地址对应的 API Key 和账户权限。", String(http.statusCode)))
                    case 429: throw LumaError.message(L("语音服务额度不足或请求过于频繁（429），请稍后重试。"))
                    case 300..<400: throw LumaError.message(L("接口发生重定向，已停止以保护密钥。请填写最终语音接口地址。"))
                    default: throw LumaError.message(L("语音服务返回 HTTP %@。请检查地址、模型和音色是否兼容。", String(http.statusCode)))
                    }
                    let size = (try FileManager.default.attributesOfItem(atPath: file.path)[.size] as? NSNumber)?.int64Value ?? 0
                    guard size > 0, size <= AudioDownloadPolicy.maximumBytes else { throw LumaError.message(L("返回的音频为空或超过 24 MB，请缩短文字后重试。")) }
                    let bytes = try SpeechResponse.audio(Data(contentsOf: file, options: .mappedIfSafe), provider: preferences.provider)
                    let audio = try AVAudioPlayer(data: bytes)
                    audio.delegate = self
                    audio.prepareToPlay()
                    self.player = audio
                    guard audio.play() else { throw LumaError.message(L("音频无法播放，请检查服务是否返回 MP3 音频。")) }
                    self.state = .speaking; self.message = L("正在朗读 · 外部语音")
                }
            } catch {
                guard self.generation == token else { return }
                self.state = .idle
                self.player = nil
                if error is CancellationError { self.message = L("已取消。") }
                else if let e = error as? URLError, e.code == .timedOut { self.message = L("语音请求超时，请检查网络后重试。") }
                else if let e = error as? URLError, e.code == .cancelled { self.message = L("请求已取消，或音频超过大小限制。") }
                else { self.message = (error as? LumaError)?.localizedDescription ?? L("语音服务暂时不可用，请检查网络、接口设置和音频格式。") }
            }
        }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self, self.activeUtterance === utterance else { return }
            self.activeUtterance = nil; self.state = .idle; self.message = L("朗读完成")
        }
    }
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self, self.player === player else { return }
            self.player = nil; self.state = .idle; self.message = flag ? L("朗读完成") : L("音频播放中断，请重试。")
        }
    }
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor [weak self] in
            guard let self, self.player === player else { return }
            self.player = nil; self.state = .idle; self.message = L("音频格式无法解码，请检查接口。")
        }
    }
}
