import SwiftUI
import ThinkingOrbsKit

/// dictation's light: one libraries.dev thinking orb, on a small dark glass
/// chip or on its own. the orb keeps one shape for the whole take; the voice
/// only moves its speed and its size (`OrbMotion`), through its own clock
/// handed to the orb as `orbFrozenTime`, so a change of speed never jumps.
struct OrbChip: View {
    let orb: ListeningOrb
    let phase: OrbPhase
    let loudness: Float
    let background: Bool
    let glassID: String
    let glassNamespace: Namespace.ID

    static let chipSize: CGFloat = 44
    static let orbSize: CGFloat = 34

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var motion = OrbMotion()
    @State private var lastTick: Date?

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            orbView
                .onChange(of: timeline.date) { _, now in
                    let dt = lastTick.map { now.timeIntervalSince($0) } ?? 0
                    lastTick = now
                    motion.advance(by: dt, phase: phase, loudness: loudness)
                }
        }
        .frame(width: Self.chipSize, height: Self.chipSize)
        .modifier(ChipBackground(on: background, glassID: glassID, glassNamespace: glassNamespace))
    }

    private var orbView: some View {
        let scale = OrbMotion.scale(phase, loudness: loudness, reduceMotion: reduceMotion)
        let state = OrbState(rawValue: orb.rawValue) ?? .composing
        let presetSpeed = resolvePreset(state, .px64).speed
        return ThinkingOrb(
            state: state,
            theme: .dark,
            displaySize: Double(Self.orbSize) * scale
        )
        // reduce motion: the orb's own still frame, so no clock of ours.
        .orbFrozenTime(reduceMotion ? nil : motion.engineTime(presetSpeed: presetSpeed))
        .opacity(OrbMotion.opacity(phase))
        .shadow(color: .black.opacity(background ? 0 : 0.45), radius: 6)
    }
}

/// the chip: dark-tinted Liquid Glass so the light dots read over any
/// wallpaper, carrying the stage's glass ID so it morphs with the pills.
/// off, nothing behind the orb, and the same frame, so the orb never moves.
private struct ChipBackground: ViewModifier {
    let on: Bool
    let glassID: String
    let glassNamespace: Namespace.ID

    func body(content: Content) -> some View {
        if on {
            content
                .glassEffect(.regular.tint(.black.opacity(0.55)), in: Circle())
                .glassEffectID(glassID, in: glassNamespace)
        } else {
            content
        }
    }
}
