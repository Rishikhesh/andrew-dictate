import Foundation

/// where a take is, as the orb sees it.
enum OrbPhase: Equatable, Sendable {
    /// pressed, the mic not heard yet: slow and dim.
    case waiting
    /// hearing you: the voice drives speed and size.
    case hearing
    /// you let go: a steady pace until the text lands.
    case transcribing
}

/// the orb's own clock. one orb state for the whole take: the voice only
/// changes how fast its time runs and how big it is drawn, never its shape.
/// time accumulates (`t += dt × speed`) so a change of speed never makes the
/// orb's phase jump, which `ThinkingOrb(speed:)` would.
struct OrbMotion: Equatable, Sendable {
    private(set) var time: Double = 0

    /// the longest step one frame may take: after a sleep or a hidden panel
    /// the orb picks up where it was instead of leaping ahead.
    static let maximumStep: Double = 0.1

    static func speed(_ phase: OrbPhase, loudness: Float) -> Double {
        switch phase {
        case .waiting: 0.6
        case .hearing: 0.7 + 1.8 * clamped(loudness)
        case .transcribing: 1.0
        }
    }

    static func scale(_ phase: OrbPhase, loudness: Float, reduceMotion: Bool) -> Double {
        guard phase == .hearing, !reduceMotion else {
            return 1
        }
        return 1 + 0.14 * clamped(loudness)
    }

    static func opacity(_ phase: OrbPhase) -> Double {
        phase == .waiting ? 0.6 : 1
    }

    mutating func advance(by dt: Double, phase: OrbPhase, loudness: Float) {
        let step = min(max(dt.isFinite ? dt : 0, 0), Self.maximumStep)
        time += step * Self.speed(phase, loudness: loudness)
    }

    /// bad mic data never reaches the orb: NaN is silence, and loudness
    /// stays within 0…1.
    private static func clamped(_ loudness: Float) -> Double {
        guard loudness.isFinite else {
            return 0
        }
        return Double(min(max(loudness, 0), 1))
    }
}
