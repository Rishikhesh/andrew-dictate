import Foundation

/// which libraries.dev thinking orb listens while you talk. our own enum, so
/// settings and tests do not need the package; the raw values are
/// ThinkingOrbsKit's `OrbState` raw values, which is how the chip maps one
/// onto the other.
enum ListeningOrb: String, CaseIterable, Sendable, Identifiable {
    case breathing
    case searching
    case listening
    case composing
    case working
    case weaving
    case solving
    case connecting
    case shaping

    static let defaultOrb: ListeningOrb = .composing

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .breathing: "Breathing"
        case .searching: "Globe"
        case .listening: "Rings"
        case .composing: "Composing"
        case .working: "Working"
        case .weaving: "Weaving"
        case .solving: "Solving"
        case .connecting: "Connecting"
        case .shaping: "Shaping"
        }
    }
}
