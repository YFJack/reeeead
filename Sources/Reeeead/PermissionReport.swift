import AppKit
import ApplicationServices

enum PermissionReport {
    // Local support metadata only: no selected text, input history or credentials.
    static func write(mouseTapReady: Bool, keyboardTapReady: Bool) {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Reeeead", isDirectory: true)
        let report: [String: Any] = [
            "updatedAt": ISO8601DateFormatter().string(from: Date()),
            "pid": ProcessInfo.processInfo.processIdentifier,
            "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development",
            "appPath": Bundle.main.bundlePath,
            "accessibilityTrusted": AXIsProcessTrusted(),
            "eventPostingAllowed": CGPreflightPostEventAccess(),
            "mouseTapReady": mouseTapReady,
            "keyboardTapReady": keyboardTapReady
        ]
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appendingPathComponent("permissions.json")
            try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch { /* A diagnostic write must never prevent normal reading. */ }
    }
}
