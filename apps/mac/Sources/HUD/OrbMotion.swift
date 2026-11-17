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
    static func speed(_ phase: OrbPhase, loudness: Float, tone: Double = 0) -> Double {
        switch phase {
        case .waiting: 0.6
        case .hearing: (0.5 + 2.5 * clamped(loudness)) * (1 + 0.35 * clampedTone(tone))
        case .transcribing: 1.0
        }
    }

    /// how far the orb rises with a higher tone (falls with a lower), as a
    /// fraction of its size.
    static func lift(_ phase: OrbPhase, tone: Double, reduceMotion: Bool) -> Double {
        guard phase == .hearing, !reduceMotion else {
            return 0
        }
        return 0.08 * clampedTone(tone)
    }

    /// higher: taller and narrower. lower: wider and flatter.
    static func stretch(_ phase: OrbPhase, tone: Double, reduceMotion: Bool) -> (x: Double, y: Double) {
        guard phase == .hearing, !reduceMotion else {
            return (1, 1)
        }
        let t = clampedTone(tone)
        return (1 - 0.08 * t, 1 + 0.12 * t)
    }

    static func scale(_ phase: OrbPhase, loudness: Float, reduceMotion: Bool) -> Double {
        guard !reduceMotion else {
            return 1
        }
        switch phase {
        case .waiting: return 0.85
        case .hearing: return 0.85 + 0.45 * clamped(loudness)
        case .transcribing: return 1.0
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

    mutating func advance(by dt: Double, phase: OrbPhase, loudness: Float, tone: Double = 0) {
        let step = min(max(dt.isFinite ? dt : 0, 0), Self.maximumStep)
        time += step * Self.speed(phase, loudness: loudness, tone: tone)
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
