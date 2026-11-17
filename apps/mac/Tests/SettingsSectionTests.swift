import SwiftUI
import XCTest

/// The settings window's sidebar: eight sections, Home first.
final class SettingsSectionTests: XCTestCase {
    func testOrderIsHomeFirstGeneralLast() {
        XCTAssertEqual(
            SettingsSection.allCases,
            [.home, .dictation, .listening, .ai, .meetings, .dictionary, .history, .general]
        )
    }

    func testEveryRowHasATitleAndSymbol() {
        XCTAssertEqual(
            SettingsSection.allCases.map(\.title),
            ["Home", "Dictation", "Listening", "AI", "Meetings", "Dictionary", "History", "General"]
        )
        for section in SettingsSection.allCases {
            XCTAssertFalse(section.symbol.isEmpty, "\(section) has no symbol")
        }
    }
}

/// Settings follows the Mac's accent colour, blue when the Mac is on
/// Multicolor, whatever gold the rest of the app wears.
final class SystemAccentTests: XCTestCase {
    func testStoredAccentsMap() {
        XCTAssertEqual(SystemAccent.color(stored: -1), .gray)
        XCTAssertEqual(SystemAccent.color(stored: 0), .red)
        XCTAssertEqual(SystemAccent.color(stored: 1), .orange)
        XCTAssertEqual(SystemAccent.color(stored: 2), .yellow)
        XCTAssertEqual(SystemAccent.color(stored: 3), .green)
        XCTAssertEqual(SystemAccent.color(stored: 4), .blue)
        XCTAssertEqual(SystemAccent.color(stored: 5), .purple)
        XCTAssertEqual(SystemAccent.color(stored: 6), .pink)
    }

    func testUnknownAndMissingAreBlue() {
        XCTAssertEqual(SystemAccent.color(stored: nil), .blue)
        XCTAssertEqual(SystemAccent.color(stored: 7), .blue)
        XCTAssertEqual(SystemAccent.color(stored: -5), .blue)
    }
}

/// the app writes lowercase; settings shows it the way macOS writes.
final class SentenceCaseTests: XCTestCase {
    func testEverySentenceStartsWithACapital() {
        XCTAssertEqual(
            "hold it and talk. double-tap locks it on hands-free, tap once to end. esc cancels.".capitalizedFirst,
            "Hold it and talk. Double-tap locks it on hands-free, tap once to end. Esc cancels."
        )
    }

    func testAddressesAndKeyNamesAreLeftAlone() {
        XCTAssertEqual("send it to jass.gg".capitalizedFirst, "Send it to jass.gg")
        XCTAssertEqual("fn".capitalizedFirst, "fn")
        XCTAssertEqual("right ⌥".capitalizedFirst, "Right ⌥")
        XCTAssertEqual("".capitalizedFirst, "")
    }

    func testProperNamesKeepTheirCapitals() {
        XCTAssertEqual(
            "apple intelligence, on this mac. free and private.".capitalizedFirst,
            "Apple Intelligence, on this Mac. Free and private."
        )
        XCTAssertEqual("sign in and your chatgpt plan pays.".capitalizedFirst, "Sign in and your ChatGPT plan pays.")
        XCTAssertEqual("an ai rewrites it".capitalizedFirst, "An AI rewrites it")
        XCTAssertEqual("a key from platform.openai.com".capitalizedFirst, "A key from platform.openai.com")
        XCTAssertEqual("the machine said maybe".capitalizedFirst, "The machine said maybe")
        XCTAssertEqual("fast · english and european languages only".capitalizedFirst, "Fast · English and European languages only")
        XCTAssertEqual("~2.9 gb · 464.5 mb".capitalizedFirst, "~2.9 GB · 464.5 MB")
    }

    // final review: a symbol starts the sentence too, so "⌥ is…" stays.
    func testASymbolStartsTheSentence() {
        XCTAssertEqual("⌥ is your dictation key's own.".capitalizedFirst, "⌥ is your dictation key's own.")
        XCTAssertEqual("~2.9 gb".capitalizedFirst, "~2.9 GB")
    }
}

/// final review: the dictation key can never be set to one the meeting
/// shortcut already holds, whatever the menu lets through.
final class DictationKeyGuardTests: XCTestCase {
    func testAKeyTheMeetingShortcutHoldsIsRefused() {
        let shortcut = MeetingShortcut(keyCode: 46, modifiers: [.control, .command], keyName: "M")
        XCTAssertFalse(DictationKeyGuard.canBind(.leftControl, meetingShortcut: shortcut))
        XCTAssertTrue(DictationKeyGuard.canBind(.fn, meetingShortcut: shortcut))
        XCTAssertTrue(DictationKeyGuard.canBind(.leftControl, meetingShortcut: nil))
    }
}
