import Carbon
import Foundation
import os

/// A shortcut registered with the system as a global hot key: the meeting
/// shortcut, and fix a word's.
///
/// Not the dictation key's mechanism on purpose. That one listens to every
/// key through an event monitor, which is the accessibility permission, and
/// someone who only records meetings has not been asked for it. A registered
/// hot key asks for nothing: the system says when this one combination is
/// pressed, hears no other key, and takes the press, so the dictation key's
/// monitor is not shown it.
@MainActor
final class GlobalHotkey {
    /// which shortcut this is: its id among this process's hot keys, and
    /// what the log calls it.
    enum Slot: UInt32, Sendable {
        case meeting = 1
        case fixAWord = 2

        var name: String {
            switch self {
            case .meeting: "meeting"
            case .fixAWord: "fix a word"
            }
        }
    }

    let slot: Slot

    init(_ slot: Slot) {
        self.slot = slot
        slotID = slot.rawValue
    }

    /// the shortcut was pressed.
    var onPress: (() -> Void)?

    /// What is registered, or nil. Setting it replaces the old one.
    var shortcut: MeetingShortcut? {
        didSet { apply() }
    }

    /// While the settings row listens for a new combination, the old one
    /// must not fire: pressing it again to keep it would do what it does.
    var isHeld = false {
        didSet { apply() }
    }

    /// Why the system would not register a shortcut, in the row's words.
    enum Failure: Equatable, Sendable {
        /// Another app holds the combination.
        case alreadyRegistered
        /// Anything else the system says no with.
        case refused

        init(status: OSStatus) {
            self = status == OSStatus(eventHotKeyExistsErr) ? .alreadyRegistered : .refused
        }

        var message: String {
            switch self {
            case .alreadyRegistered: "another app already uses that."
            case .refused: "can't use that one."
            }
        }
    }

    /// The system would not give the combination. The setting stays; the
    /// row says so.
    var isTaken: Bool { failure != nil }

    /// Why, from the last registration.
    private(set) var failure: Failure? {
        didSet { Self.lastFailures[slot] = failure }
    }

    /// The same answer, where the settings row reads it. The coordinator
    /// owns the hot keys and passes on only whether one failed, and only
    /// when the setting changes; this is current after every registration,
    /// including the one when the row stops listening. There is one hot key
    /// per slot in the app, so its last answer is the answer.
    static func lastFailure(_ slot: Slot) -> Failure? {
        lastFailures[slot]
    }

    private static var lastFailures: [Slot: Failure] = [:]

    /// the slot's id, readable from the event handler, which runs on the
    /// main thread but outside the actor's view.
    private nonisolated let slotID: UInt32

    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?

    private static let logger = Logger(
        subsystem: AppIdentity.loggingSubsystem, category: "global-hotkey")
    /// 'ADMH': ours among the hot keys of this process.
    private static let signature: OSType = 0x41_44_4D_48

    private func apply() {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
            self.hotKey = nil
        }
        failure = nil
        guard let shortcut, !isHeld else { return }

        installHandlerOnce()
        var registered: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            shortcut.modifiers.carbonFlags,
            EventHotKeyID(signature: Self.signature, id: slot.rawValue),
            GetApplicationEventTarget(),
            0,
            &registered)
        guard status == noErr, let registered else {
            failure = Failure(status: status)
            Self.logger.error(
                "the \(self.slot.name, privacy: .public) shortcut \(shortcut.displayName, privacy: .public) could not be registered: \(status)")
            return
        }
        hotKey = registered
        Self.logger.info("the \(self.slot.name, privacy: .public) shortcut \(shortcut.displayName, privacy: .public) is registered")
    }

    /// one handler per hot key, each on the application target: a press
    /// that is not this one's goes on to the next handler.
    private func installHandlerOnce() {
        guard handler == nil else { return }
        var pressed = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, context in
                guard let event, let context else {
                    return OSStatus(eventNotHandledErr)
                }
                var id = EventHotKeyID()
                let read = GetEventParameter(
                    event, EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID), nil,
                    MemoryLayout<EventHotKeyID>.size, nil, &id)
                let hotkey = Unmanaged<GlobalHotkey>.fromOpaque(context).takeUnretainedValue()
                guard read == noErr, id.signature == GlobalHotkey.signature,
                      id.id == hotkey.slotID else {
                    return OSStatus(eventNotHandledErr)
                }
                Task { @MainActor in hotkey.onPress?() }
                return noErr
            },
            1, &pressed,
            Unmanaged.passUnretained(self).toOpaque(),
            &handler)
        if status != noErr {
            Self.logger.error("the hot key handler could not be installed: \(status)")
        }
    }
}

extension MeetingShortcut.Modifiers {
    /// the flags `RegisterEventHotKey` wants.
    var carbonFlags: UInt32 {
        var flags = 0
        if contains(.control) { flags |= controlKey }
        if contains(.option) { flags |= optionKey }
        if contains(.shift) { flags |= shiftKey }
        if contains(.command) { flags |= cmdKey }
        return UInt32(flags)
    }
}
