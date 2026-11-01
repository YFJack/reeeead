import XCTest
@testable import Reeeead

final class LocalizationTests: XCTestCase {
    func testSystemLanguageAndExplicitOverrides() {
        XCTAssertEqual(AppLanguage.system.resolved(preferred: ["zh-Hant-HK", "en"]), "zh-Hans")
        XCTAssertEqual(AppLanguage.system.resolved(preferred: ["en-GB", "zh-Hans"]), "en")
        XCTAssertEqual(AppLanguage.system.resolved(preferred: ["fr-FR"]), "en")
        XCTAssertEqual(AppLanguage.system.resolved(preferred: []), "en")
        XCTAssertEqual(AppLanguage.english.resolved(preferred: ["zh-Hans"]), "en")
        XCTAssertEqual(AppLanguage.chinese.resolved(preferred: ["en"]), "zh-Hans")
    }

    func testBundledCataloguesAreCompleteAndKeepFormatArguments() {
        let english = Localization.catalogue("en")
        let chinese = Localization.catalogue("zh-Hans")
        XCTAssertGreaterThan(english.count, 150, "Resources must load in both SwiftPM and the packaged app")
        XCTAssertEqual(Set(english.keys), Set(chinese.keys))
        for (key, value) in english {
            XCTAssertFalse(value.isEmpty, key)
            XCTAssertEqual(key.components(separatedBy: "%@").count, value.components(separatedBy: "%@").count, key)
        }
        XCTAssertEqual(Localization.text("阅读", language: .english), "Read")
        XCTAssertEqual(Localization.text("Ready", language: .chinese), "就绪")
        XCTAssertEqual(Localization.format("鼠标 %@", language: .english, arguments: ["4"]), "Mouse 4")
        XCTAssertEqual(Localization.text("Unknown provider error", language: .english), "Unknown provider error")
    }
}
