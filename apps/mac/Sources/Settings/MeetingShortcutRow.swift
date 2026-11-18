import AppKit
import SwiftUI

/// the meeting shortcut in settings.
struct MeetingShortcutRow: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var coordinator: DictationCoordinator

    var body: some View {
        ShortcutRecorderRow(
            title: "meeting shortcut",
            explanation: "starts a meeting, and stops the one that records. needs ⌃ or ⌘.",
            shortcut: settings.meetingShortcut,
            slot: .meeting,
            set: { settings.setMeetingShortcut($0) },
            hold: { coordinator.holdMeetingShortcut($0) }
        )
    }
}

/// a global shortcut in settings: click the chip, press a combination,
/// done. the dictation key is a pick from a short list of lone modifiers, so
/// there was nothing here to reuse that records a chord. the meeting
/// shortcut and fix a word's both use it.
struct ShortcutRecorderRow: View {
    let title: String
    let explanation: String
    let shortcut: MeetingShortcut?
    let slot: GlobalHotkey.Slot
    /// what the chip says with no shortcut set.
    var unsetText = "not set"
    /// stores it, or says why not.
    let set: (MeetingShortcut?) -> MeetingShortcut.Refusal?
    /// lets the registered one go while the row listens, and back after.
    let hold: (Bool) -> Void

    @State private var isListening = false
    @State private var monitor: Any?
    /// why the last combination was not taken, until the next try.
    @State private var refusal: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                SettingsRowLabel(title, explanation: explanation)

                Spacer(minLength: 8)

                // a recorder: click, then press the keys. it reads as a
                // field while it listens, so the next key press has a home.
                Button(action: toggleListening) {
                    Text(chipText.capitalizedFirst)
                        .monospacedDigit()
                        .frame(minWidth: 110)
                }
                .buttonStyle(.bordered)
                .overlay {
                    if isListening {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(.tint, lineWidth: 2)
                    }
                }
                .accessibilityLabel(title.capitalizedFirst)
                .accessibilityValue(chipText)
                .accessibilityHint("Press to choose a new one")

                if shortcut != nil {
                    Button("Clear", action: clear)
                }
            }

            if let note {
                Text(note.capitalizedFirst)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        // the app going to the background ends it: no key would reach the
        // monitor, and the old shortcut should not stay let go.
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.didResignActiveNotification)
        ) { _ in
            stopListening()
        }
        .onDisappear(perform: stopListening)
    }

    private var chipText: String {
        if isListening {
            return "press a shortcut…"
        }
        return shortcut?.displayName ?? unsetText
    }

    /// a refusal, or the system not giving what was chosen: the row says it
    /// in a few words and the shortcut stays what it was. read when the row
    /// draws, which it does when the setting changes or listening stops —
    /// the two moments the hot key is registered again.
    private var note: String? {
        if let refusal {
            return refusal
        }
        if shortcut != nil, !isListening,
           let failure = GlobalHotkey.lastFailure(slot) {
            return failure.message
        }
        return nil
    }

    private func toggleListening() {
        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }

    private func startListening() {
        refusal = nil
        isListening = true
        hold(true)
        // every key goes to this row until one is taken, so nothing typed
        // meanwhile reaches the pane behind it — except ⌘W and ⌘Q, which
        // end listening and go on to the window.
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            heard(event)
        }
    }

    private func stopListening() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        guard isListening else {
            return
        }
        isListening = false
        hold(false)
    }

    /// the event, to pass it on, or nil to keep it from the window.
    private func heard(_ event: NSEvent) -> NSEvent? {
        guard !event.isARepeat else {
            return nil
        }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        // esc on its own is how you leave without choosing.
        if event.keyCode == MeetingShortcut.escapeKeyCode,
           flags.isDisjoint(with: [.control, .option, .command, .shift]) {
            stopListening()
            return nil
        }

        var modifiers: MeetingShortcut.Modifiers = []
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.command) { modifiers.insert(.command) }
        let shortcut = MeetingShortcut(
            keyCode: event.keyCode,
            modifiers: modifiers,
            keyName: MeetingShortcut.keyName(
                forKeyCode: event.keyCode,
                characters: event.charactersIgnoringModifiers ?? ""))

        // ⌘W and ⌘Q are a hand leaving, not a choice: the window closes, or
        // the app quits, as it would anywhere else.
        if shortcut.closesOrQuits {
            refusal = nil
            stopListening()
            return event
        }
        if let reason = set(shortcut) {
            // still listening: the next combination may be fine.
            refusal = reason.message
            return nil
        }
        refusal = nil
        stopListening()
        return nil
    }

    private func clear() {
        stopListening()
        refusal = nil
        _ = set(nil)
    }
}
