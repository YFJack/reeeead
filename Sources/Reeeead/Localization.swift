import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system, english = "en", chinese = "zh-Hans"
    var id: String { rawValue }
    var title: String {
        switch self { case .system: return L("跟随系统"); case .english: return "English"; case .chinese: return "简体中文" }
    }
    func resolved(preferred: [String] = Locale.preferredLanguages) -> String {
        if self != .system { return rawValue }
        return preferred.first?.lowercased().hasPrefix("zh") == true ? "zh-Hans" : "en"
    }
}

enum Localization {
    static let preferenceKey = "interfaceLanguage.v1"
    static var language: AppLanguage {
        get { AppLanguage(rawValue: UserDefaults.standard.string(forKey: preferenceKey) ?? "system") ?? .system }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: preferenceKey) }
    }
    static func catalogue(_ language: String) -> [String: String] {
        guard let url = Brand.resources.url(forResource: "Localizable", withExtension: "strings", subdirectory: "Localization/\(language).lproj"),
              let data = try? Data(contentsOf: url),
              let values = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String] else { return [:] }
        return values
    }
    private static let english = catalogue("en")
    private static let chinese = catalogue("zh-Hans")
    // Translate stored status labels too when the user changes language mid-session.
    static func text(_ key: String, language: AppLanguage? = nil) -> String {
        let canonical = english[key] != nil ? key : (english.first { $0.value == key }?.key ?? key)
        return ((language ?? self.language).resolved() == "zh-Hans" ? chinese[canonical] : english[canonical]) ?? key
    }
    static func format(_ key: String, language: AppLanguage? = nil, arguments: [CVarArg]) -> String {
        String(format: text(key, language: language), locale: Locale(identifier: (language ?? self.language).resolved()), arguments: arguments)
    }
}

func L(_ key: String, _ arguments: CVarArg...) -> String {
    arguments.isEmpty ? Localization.text(key) : Localization.format(key, arguments: arguments)
}
