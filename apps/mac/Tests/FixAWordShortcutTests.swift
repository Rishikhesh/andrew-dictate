import XCTest

/// fix a word's global shortcut: ⌃⌥F until somebody changes or clears it,
/// never on the dictation key or the meeting shortcut's keys.
@MainActor
final class FixAWordShortcutTests: XCTestCase {
    private let controlOptionF = MeetingShortcut(
        keyCode: 3, modifiers: [.control, .option], keyName: "F")
    private let controlCommandK = MeetingShortcut(
        keyCode: 40, modifiers: [.control, .command], keyName: "K")

    private func makeUserDefaults() -> (UserDefaults, String) {
        let suiteName = "FixAWordShortcutTests.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suiteName)!, suiteName)
    }

    func testAFreshInstallHasControlOptionF() {
        let (userDefaults, suiteName) = makeUserDefaults()
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(userDefaults: userDefaults)

        XCTAssertEqual(settings.fixAWordShortcut, controlOptionF)
        XCTAssertEqual(settings.fixAWordShortcut?.displayName, "⌃⌥F")
        XCTAssertTrue(settings.fixAWordShortcutIsDefault)
    }

    func testAChosenShortcutSurvivesARelaunch() {
        let (userDefaults, suiteName) = makeUserDefaults()
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        XCTAssertNil(AppSettings(userDefaults: userDefaults).setFixAWordShortcut(controlCommandK))

        let relaunched = AppSettings(userDefaults: userDefaults)
        XCTAssertEqual(relaunched.fixAWordShortcut, controlCommandK)
        XCTAssertFalse(relaunched.fixAWordShortcutIsDefault)
    }

    /// cleared means cleared: the default does not come back at launch.
    func testClearingItStaysClearedAcrossARelaunch() {
        let (userDefaults, suiteName) = makeUserDefaults()
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        AppSettings(userDefaults: userDefaults).setFixAWordShortcut(nil)

        let relaunched = AppSettings(userDefaults: userDefaults)
        XCTAssertNil(relaunched.fixAWordShortcut)
        XCTAssertFalse(relaunched.fixAWordShortcutIsDefault)
    }

    func testItCannotTakeTheMeetingShortcutsKeys() {
        let (userDefaults, suiteName) = makeUserDefaults()
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let settings = AppSettings(userDefaults: userDefaults)
        XCTAssertNil(settings.setMeetingShortcut(controlCommandK))

        // the same keys, whatever the layout called the letter.
        let refusal = settings.setFixAWordShortcut(
            MeetingShortcut(keyCode: 40, modifiers: [.control, .command], keyName: "k"))

        XCTAssertEqual(refusal, .isTheOtherShortcut("meeting"))
        XCTAssertEqual(refusal?.message, "that's already the meeting shortcut")
        XCTAssertEqual(settings.fixAWordShortcut, controlOptionF)
    }

    func testTheMeetingShortcutCannotTakeItsKeys() {
        let (userDefaults, suiteName) = makeUserDefaults()
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let settings = AppSettings(userDefaults: userDefaults)

        XCTAssertEqual(
            settings.setMeetingShortcut(controlOptionF),
            .isTheOtherShortcut("fix a word"))
        XCTAssertNil(settings.meetingShortcut)
    }

    func testItCannotHoldTheDictationKey() {
        let (userDefaults, suiteName) = makeUserDefaults()
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let settings = AppSettings(userDefaults: userDefaults)
        XCTAssertTrue(settings.setHotkeyBinding(.rightCommand))

        XCTAssertEqual(
            settings.setFixAWordShortcut(controlCommandK),
            .includesTheDictationKey(.rightCommand))
        XCTAssertEqual(settings.fixAWordShortcut, controlOptionF)
    }

    /// the default never blocks: the dictation key can move onto ⌥, and
    /// ⌃⌥F steps aside until it moves off again.
    func testTheDefaultStepsAsideForTheDictationKey() {
        let (userDefaults, suiteName) = makeUserDefaults()
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let settings = AppSettings(userDefaults: userDefaults)

        XCTAssertTrue(settings.setHotkeyBinding(.rightOption))
        XCTAssertNil(settings.fixAWordShortcut)
        XCTAssertNil(AppSettings(userDefaults: userDefaults).fixAWordShortcut)

        XCTAssertTrue(settings.setHotkeyBinding(.fn))
        XCTAssertEqual(settings.fixAWordShortcut, controlOptionF)
    }

    /// a chosen one holds its ground, as the meeting shortcut does.
    func testAChosenShortcutKeepsTheDictationKeyOffItsModifiers() {
        let (userDefaults, suiteName) = makeUserDefaults()
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let settings = AppSettings(userDefaults: userDefaults)
        XCTAssertNil(settings.setFixAWordShortcut(controlCommandK))

        XCTAssertFalse(settings.setHotkeyBinding(.leftControl))
        XCTAssertEqual(settings.dictationHotkey, .fn)
        XCTAssertTrue(settings.setHotkeyBinding(.rightOption))
    }
}
