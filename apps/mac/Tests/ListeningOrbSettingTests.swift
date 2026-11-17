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

    func testDefaultsAreComposingLargeWithoutBackground() {
        let settings = AppSettings(userDefaults: userDefaults)
        XCTAssertEqual(settings.listeningOrb, .composing)
        XCTAssertFalse(settings.orbBackground)
        XCTAssertEqual(settings.orbSize, .large)
    }

    func testSizeSurvivesReloadAndUnknownIsLarge() {
        let settings = AppSettings(userDefaults: userDefaults)
        settings.orbSize = .small
        XCTAssertEqual(AppSettings(userDefaults: userDefaults).orbSize, .small)
        userDefaults.set("huge", forKey: "AndrewDictate.orbSize")
        XCTAssertEqual(AppSettings(userDefaults: userDefaults).orbSize, .large)
    }

    func testChoiceSurvivesReload() {
        let settings = AppSettings(userDefaults: userDefaults)
        settings.listeningOrb = .searching
        settings.orbBackground = true

        let reloaded = AppSettings(userDefaults: userDefaults)
        XCTAssertEqual(reloaded.listeningOrb, .searching)
        XCTAssertTrue(reloaded.orbBackground)
    }

    func testUnknownStoredOrbFallsBackToComposing() {
        userDefaults.set("sparkle", forKey: "AndrewDictate.listeningOrb")
        XCTAssertEqual(AppSettings(userDefaults: userDefaults).listeningOrb, .composing)
    }
}
