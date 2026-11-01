import Foundation

enum VoiceConfiguration {
    static func status() -> Int32 {
        let preferences = Preferences.load()
        do {
            let present = !(try KeyStore.read(endpoint: preferences.endpoint)).isEmpty
            let value: [String: Any] = ["provider": preferences.provider, "endpoint": preferences.endpoint, "model": preferences.model, "voice": preferences.voice, "keyPresent": present]
            print(String(data: try JSONSerialization.data(withJSONObject: value, options: .sortedKeys), encoding: .utf8)!)
            return 0
        } catch { print("Keychain unavailable; no credential was printed."); return 1 }
    }
    // For explicit personal setup: secret arrives through stdin, never argv or stdout.
    static func importFromStandardInput() -> Int32 {
        struct Configuration: Decodable {
            let provider: String
            let endpoint: String
            let model: String
            let voice: String
            let key: String
        }
        do {
            let data = FileHandle.standardInput.readDataToEndOfFile()
            guard data.count <= 16_384 else { throw LumaError.message("配置过大。") }
            let input = try JSONDecoder().decode(Configuration.self, from: data)
            guard ["api", "minimax"].contains(input.provider), !input.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !input.model.isEmpty, !input.voice.isEmpty else { throw LumaError.message("语音配置不完整。") }
            _ = try SpeechRequest.validatedURL(input.endpoint)
            try KeyStore.save(input.key.trimmingCharacters(in: .whitespacesAndNewlines), endpoint: input.endpoint)
            var preferences = Preferences.load()
            preferences.selectProvider(input.provider)
            preferences.endpoint = input.endpoint; preferences.model = input.model; preferences.voice = input.voice
            preferences.save()
            UserDefaults.standard.synchronize()
            print("Voice configured; credential stored in Keychain. Reopen the app to reload settings.")
            return 0
        } catch {
            print((error as? LumaError)?.localizedDescription ?? "Invalid voice configuration; no credential was printed.")
            return 1
        }
    }
}
