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
}
