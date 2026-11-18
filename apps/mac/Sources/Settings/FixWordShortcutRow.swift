import SwiftUI

/// fix a word's global shortcut in settings: ⌃⌥F until changed or cleared.
/// it opens fix a word on the last dictation from any app, and asks for no
/// permission (a registered hot key, as the meeting shortcut is).
struct FixWordShortcutRow: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var coordinator: DictationCoordinator

    var body: some View {
        ShortcutRecorderRow(
            title: "fix a word shortcut",
            explanation: explanation,
            shortcut: settings.fixAWordShortcut,
            slot: .fixAWord,
            set: { settings.setFixAWordShortcut($0) },
            hold: { coordinator.holdFixAWordShortcut($0) }
        )
    }

    /// the default steps aside for the dictation key or the meeting
    /// shortcut, so the row says why it is off rather than "not set".
    private var explanation: String {
        if settings.fixAWordShortcutIsDefault, settings.fixAWordShortcut == nil {
            return "opens fix a word on your last dictation, from any app. ⌃⌥F is off while your dictation key or meeting shortcut uses it."
        }
        return "opens fix a word on your last dictation, from any app. needs ⌃ or ⌘."
    }
}
