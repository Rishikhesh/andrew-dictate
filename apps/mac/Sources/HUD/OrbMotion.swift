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

extension OrbPhase {
    /// the take's phase from the panel's view of it; nil when there is no
    /// take. one rule, so the stage can keep one orb for the whole take
    /// instead of a new one per state.
    static func forLamp(_ lamp: HUDLampState, isHearing: Bool) -> OrbPhase? {
        switch lamp {
        case .idle: nil
        case .prewarming: .waiting
        case .recording: isHearing ? .hearing : .waiting
        case .transcribing: .transcribing
        }
    }
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

    // the voice has to be seen. ordinary speech sits mid-range (about 0.5
    // after `WaveLevelShaper`), so the ranges are wide: between words the
    // orb draws in, dims and slows; a loud syllable swells it, brightens it
    // and speeds it up, and the chip breathes with it.
    static func speed(_ phase: OrbPhase, loudness: Float) -> Double {
        switch phase {
        case .waiting: 0.6
        case .hearing: 0.5 + 2.5 * clamped(loudness)
        case .transcribing: 1.0
        }
    }

    /// the orb's size against its resting size. it only ever grows and
    /// shrinks, never changes shape: louder is bigger, and a voice higher
    /// than your usual is a little bigger again, lower a little smaller.
    static func scale(_ phase: OrbPhase, loudness: Float, tone: Double = 0, reduceMotion: Bool) -> Double {
        guard !reduceMotion else {
            return 1
        }
        switch phase {
        case .waiting:
            return 0.85
        case .hearing:
            let size = 0.85 + 0.45 * clamped(loudness) + 0.12 * clampedTone(tone)
            return min(max(size, 0.75), 1.4)
        case .transcribing:
            return 1.0
        }
    }

    static func opacity(_ phase: OrbPhase, loudness: Float) -> Double {
        switch phase {
        case .waiting: 0.6
        case .hearing: 0.7 + 0.3 * clamped(loudness)
        case .transcribing: 1.0
        }
    }

    /// the glass chip behind the orb, breathing with the voice.
    static func chipScale(_ phase: OrbPhase, loudness: Float, reduceMotion: Bool) -> Double {
        guard phase == .hearing, !reduceMotion else {
            return 1
        }
        return 1 + 0.18 * clamped(loudness)
    }

    /// the time to hand the orb: a frozen time is raw engine time, which
    /// skips the orb's own tuned pace, so it is applied here.
    func engineTime(presetSpeed: Double) -> Double {
        time * presetSpeed
    }

    mutating func advance(by dt: Double, phase: OrbPhase, loudness: Float) {
        let step = min(max(dt.isFinite ? dt : 0, 0), Self.maximumStep)
        time += step * Self.speed(phase, loudness: loudness)
    }

    private static func clampedTone(_ tone: Double) -> Double {
        guard tone.isFinite else {
            return 0
        }
        return min(max(tone, -1), 1)
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
