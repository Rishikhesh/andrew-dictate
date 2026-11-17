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

/// how big the orb is drawn: the three sizes approved from real renders.
enum OrbSizeChoice: String, CaseIterable, Sendable, Identifiable {
    case small
    case medium
    case large

    static let defaultSize: OrbSizeChoice = .large

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        }
    }

    /// the orb's resting size, in points.
    var orb: Double {
        switch self {
        case .small: 36
        case .medium: 54
        case .large: 70
        }
    }

    /// the chip around it, in points.
    var chip: Double {
        switch self {
        case .small: 44
        case .medium: 64
        case .large: 80
        }
    }
}
