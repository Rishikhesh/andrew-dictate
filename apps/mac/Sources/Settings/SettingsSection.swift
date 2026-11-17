import SwiftUI

/// the settings window's sidebar, in the order it is read: home first,
/// general last, the way System Settings keeps its housekeeping at the end.
enum SettingsSection: String, CaseIterable, Identifiable, Hashable {
    case home
    case dictation
    case listening
    case ai
    case meetings
    case dictionary
    case history
    case general

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .dictation: "Dictation"
        case .listening: "Listening"
        case .ai: "AI"
        case .meetings: "Meetings"
        case .dictionary: "Dictionary"
        case .history: "History"
        case .general: "General"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house"
        case .dictation: "waveform"
        case .listening: "circle.dotted"
        case .ai: "sparkles"
        case .meetings: "person.2.wave.2"
        case .dictionary: "character.book.closed"
        case .history: "clock.arrow.circlepath"
        case .general: "gearshape"
        }
    }

    /// the tile behind the symbol, as System Settings colours its rows.
    var tileColor: Color {
        switch self {
        case .home: .indigo
        case .dictation: .orange
        case .listening: .purple
        case .ai: .blue
        case .meetings: .green
        case .dictionary: .pink
        case .history: .teal
        case .general: .gray
        }
    }
}

/// a sidebar row: the symbol on its coloured tile, then the title.
struct SettingsSectionLabel: View {
    let section: SettingsSection

    var body: some View {
        Label {
            Text(section.title)
        } icon: {
            Image(systemName: section.symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(section.tileColor.gradient, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
    }
}

/// the dictation key may never be one the meeting shortcut holds: every
/// press of the shortcut would start a take too. checked where the key is
/// set, so no menu can let it through.
enum DictationKeyGuard {
    static func canBind(_ key: HotkeyBinding, meetingShortcut: MeetingShortcut?) -> Bool {
        meetingShortcut?.refusal(againstDictationKey: key) == nil
    }
}
