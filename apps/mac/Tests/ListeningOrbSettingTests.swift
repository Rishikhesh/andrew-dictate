import XCTest

/// Which orb listens while you talk, and whether it sits on its dark chip:
/// two settings beside sound, stored the way the others are.
@MainActor
final class ListeningOrbSettingTests: XCTestCase {
    private var suiteName: String!
    private var userDefaults: UserDefaults!

    override func setUp() {
        suiteName = "AndrewDictateTests.ListeningOrb.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    func testDefaultsAreComposingWithBackground() {
        let settings = AppSettings(userDefaults: userDefaults)
        XCTAssertEqual(settings.listeningOrb, .composing)
        XCTAssertTrue(settings.orbBackground)
    }

    func testChoiceSurvivesReload() {
        let settings = AppSettings(userDefaults: userDefaults)
        settings.listeningOrb = .searching
        settings.orbBackground = false

        let reloaded = AppSettings(userDefaults: userDefaults)
        XCTAssertEqual(reloaded.listeningOrb, .searching)
        XCTAssertFalse(reloaded.orbBackground)
    }

    func testUnknownStoredOrbFallsBackToComposing() {
        userDefaults.set("sparkle", forKey: "AndrewDictate.listeningOrb")
        XCTAssertEqual(AppSettings(userDefaults: userDefaults).listeningOrb, .composing)
    }
}
