import Foundation

/// An optional global shortcut: the one that starts a meeting, and stops it
/// while one records, and the one that opens fix a word. Not a dictation
/// key: that one is a lone modifier held and let go, and this is a chord
/// pressed once, so it is its own small thing with its own stored value.
struct MeetingShortcut: Codable, Hashable, Sendable {
    /// What is held with the key. Shift counts but never stands alone: a
    /// shortcut with only shift in it would fire on every capital letter.
    struct Modifiers: OptionSet, Codable, Hashable, Sendable {
        let rawValue: Int

        static let control = Modifiers(rawValue: 1 << 0)
        static let option = Modifiers(rawValue: 1 << 1)
        static let shift = Modifiers(rawValue: 1 << 2)
        static let command = Modifiers(rawValue: 1 << 3)
    }

    let keyCode: UInt16
    let modifiers: Modifiers
    /// what the key said when it was recorded, kept like the dictation key
    /// keeps its display name: the layout can change, the row should not.
    let keyName: String

    static let escapeKeyCode: UInt16 = 53

    /// What to call a key that was just pressed: its character, upper-cased,
    /// or its own word or glyph for the keys that have no character worth
    /// showing.
    static func keyName(forKeyCode keyCode: UInt16, characters: String) -> String {
        specialKeyNames[keyCode] ?? characters.uppercased()
    }

    /// virtual key codes, which do not change with the layout.
    private static let specialKeyNames: [UInt16: String] = [
        36: "↩", 48: "⇥", 49: "space", 51: "⌫", 53: "esc", 76: "⌤", 117: "⌦",
        115: "↖", 119: "↘", 116: "⇞", 121: "⇟",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7",
        100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
        105: "F13", 107: "F14", 113: "F15", 106: "F16", 64: "F17", 79: "F18",
        80: "F19", 90: "F20",
    ]

    /// the chip in settings: modifiers in the order the mac writes them,
    /// then the key.
    var displayName: String {
        keyCaps.joined()
    }

    /// the same, one key cap per key: what the menu bar panel shows.
    var keyCaps: [String] {
        let held = [
            (Modifiers.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘"),
        ]
        return held.filter { modifiers.contains($0.0) }.map(\.1) + [keyName]
    }

    /// Why settings will not take a shortcut, in the few words the row says.
    enum Refusal: Equatable, Sendable {
        case needsAModifier
        /// macOS 15 and later will not register a hot key held with option
        /// alone, or option and shift: it is how a mac types its other
        /// characters.
        case optionAlone
        case isEscape
        /// ⌘ or ⌘⇧ on a key every mac app answers.
        case everyAppUsesIt
        /// ⌘⇧3, 4 or 5.
        case takesAScreenshot
        case includesTheDictationKey(HotkeyBinding)
        /// the app's other shortcut already has these keys.
        case isTheOtherShortcut(String)

        var message: String {
            switch self {
            case .needsAModifier:
                "needs ⌃ or ⌘ held with it"
            case .optionAlone:
                "macos won't take ⌥ without ⌃ or ⌘"
            case .isEscape:
                "esc cancels a dictation"
            case .everyAppUsesIt:
                "every app already uses that one"
            case .takesAScreenshot:
                "that's the mac's screenshot key"
            case .includesTheDictationKey(let key):
                "includes your dictation key, \(key.displayName)"
            case .isTheOtherShortcut(let name):
                "that's already the \(name) shortcut"
            }
        }
    }

    func refusal(againstDictationKey key: HotkeyBinding) -> Refusal? {
        guard !modifiers.isDisjoint(with: [.control, .option, .command]) else {
            return .needsAModifier
        }
        guard !modifiers.isDisjoint(with: [.control, .command]) else {
            return .optionAlone
        }
        guard keyCode != Self.escapeKeyCode else {
            return .isEscape
        }
        if modifiers.subtracting(.shift) == .command {
            if modifiers.contains(.shift), Self.screenshotKeyCodes.contains(keyCode) {
                return .takesAScreenshot
            }
            if Self.everyAppsKeyCodes.contains(keyCode)
                || Self.everyAppsLetters.contains(keyName) {
                return .everyAppUsesIt
            }
        }
        if let held = Self.modifier(of: key), modifiers.contains(held) {
            return .includesTheDictationKey(key)
        }
        return nil
    }

    /// the same keys as `other`, whatever each was called when it was
    /// recorded: one press cannot be two shortcuts.
    func isSameKeys(as other: MeetingShortcut?) -> Bool {
        guard let other else { return false }
        return keyCode == other.keyCode && modifiers == other.modifiers
    }

    /// fix a word's shortcut cannot be this one: the dictation key would
    /// swallow it, or the meeting shortcut has its keys.
    func stepsAside(forDictationKey key: HotkeyBinding, meetingShortcut: MeetingShortcut?) -> Bool {
        refusal(againstDictationKey: key) != nil || isSameKeys(as: meetingShortcut)
    }

    /// fix a word's, until somebody changes or clears it: ⌃⌥F.
    static let fixAWordDefault = MeetingShortcut(
        keyCode: 3, modifiers: [.control, .option], keyName: "F")

    /// ⌘W or ⌘Q with nothing else held: a hand leaving settings, or the
    /// app. While the row listens these are not taken; listening stops and
    /// the key goes on to the window.
    var closesOrQuits: Bool {
        modifiers == .command
            && (keyCode == Self.wKeyCode || keyCode == Self.qKeyCode
                || keyName == "W" || keyName == "Q")
    }

    private static let wKeyCode: UInt16 = 13
    private static let qKeyCode: UInt16 = 12

    /// With ⌘, or ⌘⇧, what every mac app answers: select all, copy, find,
    /// hide, minimise, new, open, print, quit, save, a new tab, paste,
    /// close, cut, undo; and switching apps, spotlight, a default button,
    /// moving a file to the bin. ⌘V is also what the app presses itself
    /// for every paste. A menu matches the character the key typed, which
    /// is the key's name; the paste and the system match where the key
    /// sits, which is its code on a us keyboard. Either refuses it, so a
    /// layout that moves the letters is covered both ways.
    private static let everyAppsLetters: Set<String> = [
        "A", "C", "F", "H", "M", "N", "O", "P", "Q", "S", "T", "V", "W", "X", "Z",
    ]
    private static let everyAppsKeyCodes: Set<UInt16> = [
        0, 8, 3, 4, 46, 45, 31, 35, 12, 1, 17, 9, 13, 7, 6,
        48, 49, 36, 51,
    ]
    /// 3, 4 and 5, which ⌘⇧ makes the screenshot keys. By code, as the
    /// system matches them: with shift held they type no digit.
    private static let screenshotKeyCodes: Set<UInt16> = [20, 21, 23]

    /// The modifier a dictation key is, for a shortcut that holds it. Left
    /// and right are one modifier here. fn is none: a shortcut cannot hold
    /// it, so it never clashes.
    private static func modifier(of key: HotkeyBinding) -> Modifiers? {
        switch key.keyCode {
        case HotkeyBinding.leftOption.keyCode, HotkeyBinding.rightOption.keyCode:
            .option
        case HotkeyBinding.leftCommand.keyCode, HotkeyBinding.rightCommand.keyCode:
            .command
        case HotkeyBinding.leftControl.keyCode, HotkeyBinding.rightControl.keyCode:
            .control
        default:
            nil
        }
    }

    /// What a press of the shortcut does.
    enum Press: Equatable, Sendable {
        case start
        case stop
    }

    static func press(whileRecording isRecording: Bool) -> Press {
        isRecording ? .stop : .start
    }
}
