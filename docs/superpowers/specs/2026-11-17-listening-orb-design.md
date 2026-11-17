# Listening orb: design

Date: 2026-11-17 · Approved 2026-11-17 (no text, plus a no-background option) · Fork: Rishikhesh/andrew-dictate (on Suriya's main)

## Why

The gold lamp line that shows while you dictate felt dated. After eleven rounds of mockups, the one that landed is a libraries.dev "thinking orb" (a small sphere drawn in dots) on its own in a dark round chip, with no text beside it. It should be one orb for the whole take, and you should be able to pick which orb in settings.

## Goals

- Replace the dictation lamp with an orb chip at the same spot (bottom center, above the Dock).
- One orb state for the entire take. Your voice changes only its speed and size, never its shape.
- A settings picker with all nine libraries.dev orbs, each previewed live. Default: **Composing**.
- A settings switch for the dark round chip behind the orb: on by default, or off to show just the orb.

## Non-goals

- The meeting lamp. Meetings keep the gold line for now.
- The rewrite pill (fn+⌃) and the text pills. They stay as they are.
- The larger settings redesign (System Settings style with a Home dashboard). It was approved earlier but is a separate piece of work.
- Text beside the orb (words, "Thinking…"). We tried it, and the orb on its own was preferred.

## Anti-goals

- No switching between orb states mid-take.
- No jitter. The voice drives the orb through smoothing, so it swells and settles instead of twitching.
- Nothing appears before you press the key, which the app already guarantees.

## Approaches considered

1. **Use the ThinkingOrbsKit Swift package from libraries.dev (chosen).** It's MIT-licensed, supports macOS 12 and up, and draws with SwiftUI's Canvas inside a TimelineView, so there's no Metal and no extra resources. It's the same engine the mockup ran. Its public `orbFrozenTime(_:)` modifier lets us feed our own clock, which is how the voice can change speed without the orb's phase jumping.
2. **Copy the package's ten files into `Vendor/`, the way the app vendors Needle.** No network fetch at build time, but we'd have to hand-copy every upstream fix. Rejected: a pinned package gives the same stability with less upkeep.
3. **Write our own dotted orb.** Rejected: it would be a worse copy of something that already exists and that the user picked.

## Design

- **Dependency.** Add `https://github.com/Jakubantalik/Libraries.dev` to `apps/mac/project.yml`, pinned to commit `371b324a253b8ee71b9ce1bc8a1ecc5a59e1a16a` (`revision:`, not a branch), product `ThinkingOrbsKit`. This follows the file's rule of exact pins, so CI doesn't resolve something new each morning.
- **The chip.** A new `HUD/OrbChip.swift` view: a circle about 80 pt across, made of Liquid Glass tinted dark (so the light dots read over any wallpaper), with a `ThinkingOrb(state:, theme: .dark, displaySize:)` inside it about 70 pt across. It joins the existing `GlassEffectContainer`, so it morphs with the text pills the way the lamp does now.
- **Each state of the take**, mapped from the coordinator's existing states:
  - `prewarming`, and `recording` before the mic is heard: the orb at a slow speed (about 0.6×) and 60% opacity.
  - `recording`: speed `0.5 + 2.5 × loudness`, orb size `0.85 + 0.45 × loudness`, opacity `0.7 + 0.3 × loudness`, and the chip `1 + 0.18 × loudness`, all from the view model's existing smoothed `loudness`. (Revised after a hands-on run: the first numbers moved the orb only 6–10% at normal speech, which read as static.)
  - `transcribing`: a steady 1.0× speed at normal size.
  - `idle`: the chip leaves the way the panel already hides.
- **No background.** With the chip switched off, the orb draws on its own with no glass behind it. Its light dots get a faint dark shadow so they still read over a bright window. The chip keeps the same size either way, so turning the switch never moves the orb.
- **The voice clock.** The orb's time builds up as `t += dt × speed` inside our own `TimelineView`, and is passed down with `.orbFrozenTime(t)`. A pure `OrbMotion.step(...)` function does the speed and size math so tests can check it.
- **The setting.** `AppSettings.listeningOrb: OrbState`, stored under `AndrewDictate.listeningOrb` with default `.composing`, following the pattern of the existing `@Published` + `didSet` properties. An unknown stored value falls back to the default. `AppSettings.orbBackground: Bool`, stored under `AndrewDictate.orbBackground` with default `true`.
- **The settings row.** A new row in the Dictation tab, after "sound", labelled "orb": a 9-across (or 5 + 4) set of small live orbs, each one a button. The chosen one gets an accent ring, and VoiceOver reads each orb's name. Below it, a "background" toggle for the chip.
- **Reduced motion.** ThinkingOrb already draws a single still frame when Reduce Motion is on, and we keep that. The voice-driven size change is switched off too.

## Testing

- `AppSettingsTests`: the default is `.composing`, the choice survives a reload, and a garbage stored value falls back to the default. `orbBackground` defaults to on and survives a reload.
- `OrbMotionTests`: speed and size at loudness 0 and 1 for each state, and time only ever moves forward.
- Manual: `./dev.sh`, hold fn, talk, pause, let go, and check that the orb swells and settles and never changes shape. Then switch orbs in settings and check the next take uses the new one. Turn the background off and check the orb still reads over a white window.

## Left to the builder

The exact chip and orb sizes (80 and 70 pt after a hands-on run; the stage is about 114 pt tall, so the chip at its loudest, about 94 pt, still fits), the speed and size constants, and the settings row layout (9 across or 5 + 4).

## Revision 2 (after hands-on, 2026-11-17)

- **Size setting.** `AppSettings.orbSize: OrbSizeChoice` (`.small` 36 pt orb / 44 pt chip, `.medium` 54 / 64, `.large` 70 / 80), stored as `AndrewDictate.orbSize`, default `.large`. The picker row shows it as a segmented control.
- **No chip by default.** `orbBackground` now defaults to `false`.
- **Pitch, not only loudness.**
  - **Measuring.** The mic tap estimates the voice's fundamental pitch for each buffer: normalised autocorrelation over 70–450 Hz on a signal decimated to about 12 kHz, and only when the buffer is loud enough and the correlation peak is at least 0.6.
  - **Tone.** A `ToneTracker` keeps a slow running baseline of your own pitch in octaves, and turns each estimate into a tone from -1 (half an octave below your usual) to +1 (half an octave above). With no voiced pitch, the tone eases back to 0.
  - **What the orb does.** Tone only changes the orb's size, never its shape: the size becomes `0.85 + 0.45 × loudness + 0.12 × tone`, kept between 0.75 and 1.4. (Revision 3: lifting it and stretching it taller or wider was tried and dropped, because the shape change looked wrong.)
