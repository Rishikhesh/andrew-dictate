# Listening Orb Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the dictation gold lamp with a single libraries.dev thinking orb in an optional dark glass chip, choosable in settings (default Composing).

**Architecture:** A pure `OrbMotion` model turns the take's phase and the view model's existing smoothed `loudness` into orb time, speed, scale and opacity. A new `OrbChip` SwiftUI view feeds that time into `ThinkingOrb` through its public `.orbFrozenTime(_:)` modifier. Our own `ListeningOrb` enum keeps settings and tests free of the package. `HUDView` swaps `lampLine(...)` for `OrbChip` in the three dictation states. A new `OrbPickerRow` in the Dictation tab writes `AppSettings.listeningOrb` and `AppSettings.orbBackground`.

**Tech Stack:** Swift 6 (strict concurrency complete), SwiftUI on macOS 26, XcodeGen, XCTest, ThinkingOrbsKit from github.com/Jakubantalik/Libraries.dev (MIT).

**Spec:** `docs/superpowers/specs/2026-11-17-listening-orb-design.md`

## Global Constraints

- Package pin: `https://github.com/Jakubantalik/Libraries.dev`, `revision: 371b324a253b8ee71b9ce1bc8a1ecc5a59e1a16a`, product `ThinkingOrbsKit`. Never a branch.
- Default orb `.composing`. Default background `true`.
- UserDefaults keys: `AndrewDictate.listeningOrb` (raw string) and `AndrewDictate.orbBackground` (bool).
- One orb state for a whole take. The voice changes only speed and scale.
- Hearing: speed `0.7 + 1.8 × loudness`, scale `1 + 0.14 × loudness`. Waiting: speed `0.6`, opacity `0.6`. Transcribing: speed `1.0`.
- Chip about 44 pt, orb about 34 pt. The chip keeps the same frame with the background off.
- The meeting lamp, the rewrite pill and the text pills don't change.
- All work happens on branch `listening-orb` off `main`, in `~/personal/andrew-dictate`.
- Test command (from `apps/mac`): `xcodegen generate && xcodebuild -project AndrewDictate.xcodeproj -scheme AndrewDictate -configuration Debug test -destination 'platform=macOS' -derivedDataPath .build -quiet`. Add `-only-testing:AndrewDictateTests/<Class>` to run one class.

## Review Focus

1. **Loudness that's NaN, negative or above 1** (bad mic data): the orb must stay finite, never vanish, and never grow past `1.14`. Pinned in Task 1 by `testLoudnessIsClampedAndNaNIsSilence`.
2. **A long gap between frames** (laptop asleep, panel hidden): orb time must not leap ahead, so cap `dt` at `0.1` s. Pinned in Task 1 by `testLargeFrameGapIsCapped`.
3. **A stored orb name that no longer exists** (a renamed state, a hand-edited plist): fall back to `.composing` without crashing. Pinned in Task 2 by `testUnknownStoredOrbFallsBackToComposing`.
4. **Reduce Motion on:** the orb is a still frame and doesn't swell with the voice. Pinned in Task 1 by `testReduceMotionNeverScales`.
5. **Background off over a white window:** the light dots must still be readable. This is the manual check in Task 3, step 6.

---

### Task 1: The orb's motion model

**Files:**
- Create: `apps/mac/Sources/HUD/ListeningOrb.swift`
- Create: `apps/mac/Sources/HUD/OrbMotion.swift`
- Modify: `apps/mac/project.yml` (add both files to the `AndrewDictateTests` sources list, next to `Sources/Settings/AppSettings.swift`)
- Test: `apps/mac/Tests/OrbMotionTests.swift`

**Interfaces:**
- Produces:
  - `enum ListeningOrb: String, CaseIterable, Sendable, Identifiable { case breathing, searching, listening, composing, working, weaving, solving, connecting, shaping }`, with `static let defaultOrb: ListeningOrb = .composing` and `var displayName: String`. Display names: Breathing, Globe, Rings, Composing, Working, Weaving, Solving, Connecting, Shaping. Raw values must equal ThinkingOrbsKit's `OrbState` raw values.
  - `enum OrbPhase: Equatable, Sendable { case waiting, hearing, transcribing }`
  - `struct OrbMotion: Equatable, Sendable { private(set) var time: Double; static func speed(_ phase: OrbPhase, loudness: Float) -> Double; static func scale(_ phase: OrbPhase, loudness: Float, reduceMotion: Bool) -> Double; static func opacity(_ phase: OrbPhase) -> Double; mutating func advance(by dt: Double, phase: OrbPhase, loudness: Float) }`

- [ ] **Step 1: Write the failing tests** in `OrbMotionTests.swift`:
  - `testHearingSpeedAndScaleFollowLoudness`: `speed(.hearing, 0) == 0.7`, `speed(.hearing, 1) == 2.5`, `scale(.hearing, 0, false) == 1`, `scale(.hearing, 1, false) == 1.14` (accuracy 1e-9).
  - `testWaitingIsSlowAndDim`: `speed(.waiting, 1) == 0.6`, `opacity(.waiting) == 0.6`, `scale(.waiting, 1, false) == 1`.
  - `testTranscribingIsSteady`: `speed(.transcribing, 1) == 1.0`, `opacity(.transcribing) == 1`.
  - `testLoudnessIsClampedAndNaNIsSilence`: `speed(.hearing, .nan) == 0.7`, `scale(.hearing, 5, false) == 1.14`, `scale(.hearing, -3, false) == 1`.
  - `testReduceMotionNeverScales`: `scale(.hearing, 1, reduceMotion: true) == 1`.
  - `testTimeOnlyMovesForward`: advancing `0.016` s 100 times at varying loudness gives a strictly increasing `time`.
  - `testLargeFrameGapIsCapped`: `advance(by: 30, .transcribing, 0)` from 0 gives `time == 0.1`; `advance(by: -1, ...)` leaves `time` unchanged.
  - `testDefaultOrbIsComposingAndNamesExist`: `ListeningOrb.defaultOrb == .composing`, there are 9 cases, and every `displayName` is non-empty.

- [ ] **Step 2: Run the tests and confirm they fail** (`-only-testing:AndrewDictateTests/OrbMotionTests`). Expected: build error, `cannot find 'OrbMotion' in scope`.

- [ ] **Step 3: Implement `ListeningOrb` and `OrbMotion`.** Clamp loudness to 0...1 and treat NaN as 0. Clamp `dt` to 0...0.1. `advance` adds `dt × speed`.

- [ ] **Step 4: Run the tests and confirm they pass.** Expected: `OrbMotionTests` 8 tests, 0 failures.

- [ ] **Step 5: Commit**: `git add` the 4 files, then `git commit -m "hud: the orb's motion, one state per take, voice drives speed and size"`.

### Task 2: The two settings

**Files:**
- Modify: `apps/mac/Sources/Settings/AppSettings.swift` (two new `@Published` properties in the `soundFeedbackEnabled` style, two keys next to `soundFeedbackKey`, initialised in `init(userDefaults:)` with the others)
- Test: `apps/mac/Tests/ListeningOrbSettingTests.swift` (use a fresh `UserDefaults(suiteName:)` per test, as `KeepMeetingAudioSettingTests` does)

**Interfaces:**
- Consumes: `ListeningOrb` from Task 1.
- Produces: `AppSettings.listeningOrb: ListeningOrb` (`@Published`, read and write) and `AppSettings.orbBackground: Bool` (`@Published`, read and write).

- [ ] **Step 1: Write the failing tests:**
  - `testDefaultsAreComposingWithBackground`: a new `AppSettings` has `listeningOrb == .composing` and `orbBackground == true`.
  - `testChoiceSurvivesReload`: set `.searching` and `false`, then a new `AppSettings` on the same defaults reads `.searching` and `false`.
  - `testUnknownStoredOrbFallsBackToComposing`: `userDefaults.set("sparkle", forKey: "AndrewDictate.listeningOrb")` gives `.composing`.

- [ ] **Step 2: Run the tests and confirm they fail.** Expected: `value of type 'AppSettings' has no member 'listeningOrb'`.
- [ ] **Step 3: Add the two properties, their keys and their initialisation.**
- [ ] **Step 4: Run `ListeningOrbSettingTests` and `AppSettingsTests` and confirm both pass.**
- [ ] **Step 5: Commit:** `git commit -m "settings: which orb listens, and whether it sits on a chip"`.

### Task 3: The orb on the stage

**Files:**
- Modify: `apps/mac/project.yml` (add the package under `packages:` using the Global Constraints pin, with a comment in the file's style explaining the pin; add `- package: LibrariesDev, product: ThinkingOrbsKit` to the `AndrewDictate` target only, not the tests)
- Create: `apps/mac/Sources/HUD/OrbChip.swift`
- Modify: `apps/mac/Sources/HUD/HUDView.swift` (`HUDViewModel` gains `var orbStyle: () -> (orb: ListeningOrb, background: Bool) = { (.defaultOrb, true) }`; in `HUDView.body`, the `.prewarming`, `.recording` and `.transcribing` cases render `OrbChip` instead of `lampLine(...)`, keeping their accessibility labels)
- Modify: `apps/mac/Sources/App/DictationCoordinator.swift:421` (after creating the view model: `viewModel.orbStyle = { [settings] in (settings.listeningOrb, settings.orbBackground) }`)

**Interfaces:**
- Consumes: `ListeningOrb`, `OrbPhase` and `OrbMotion` (Task 1); `AppSettings.listeningOrb` and `.orbBackground` (Task 2); `HUDViewModel.loudness: Float` (existing).
- Produces: `struct OrbChip: View { init(orb: ListeningOrb, phase: OrbPhase, loudness: Float, background: Bool, glassID: String, glassNamespace: Namespace.ID) }`

- [ ] **Step 1: Add the package to `project.yml`, run `xcodegen generate`, and run a Debug build.** Expected: `** BUILD SUCCEEDED **`, with ThinkingOrbsKit resolved at `371b324`.
- [ ] **Step 2: Implement `OrbChip`.**
  - It owns `@State var motion = OrbMotion()` and runs `TimelineView(.animation)`. It advances `motion` by each frame's date delta (stored in `@State var lastTick: Date?`).
  - It renders `ThinkingOrb(state: OrbState(rawValue: orb.rawValue) ?? .composing, theme: .dark, displaySize: 34 * OrbMotion.scale(...))`, applies `.orbFrozenTime(motion.time)` and `.opacity(OrbMotion.opacity(phase))`, and sits in a 44×44 frame.
  - With `background`, the chip is `.glassEffect(.regular.tint(.black.opacity(0.55)), in: Circle())` with `.glassEffectID(glassID, in: glassNamespace)`. Without it, there's no glass and the orb gets `.shadow(color: .black.opacity(0.45), radius: 6)`.
  - Read `@Environment(\.accessibilityReduceMotion)` and pass it to `scale`.
- [ ] **Step 3: Wire the phases in `HUDView`:** `.prewarming` and `.recording where !isHearing` map to `.waiting`, `.recording` to `.hearing`, and `.transcribing` to `.transcribing`. Then wire `orbStyle` in `DictationCoordinator`.
- [ ] **Step 4: Run the full test command.** Expected: all tests pass, including Tasks 1 and 2.
- [ ] **Step 5: Run `./dev.sh`, hold fn, talk, pause, then let go.** Expected: a dark chip with the Composing orb. It's dim and slow before the mic is heard, swells and speeds up while you talk, settles when you pause, holds steady while transcribing, then leaves. It never changes shape.
- [ ] **Step 6: Set `orbBackground` to false** (`defaults write gg.jass.dictate.dev AndrewDictate.orbBackground -bool NO`) **and dictate over a white window.** Expected: the orb floats with no chip and is still readable. Turn on Reduce Motion: the orb is still and doesn't swell.
- [ ] **Step 7: Commit:** `git commit -m "hud: a libraries.dev orb where the lamp was, for dictation"`.

### Task 4: Choosing the orb in settings

**Files:**
- Create: `apps/mac/Sources/Settings/OrbPickerRow.swift`
- Modify: `apps/mac/Sources/Settings/SettingsView.swift:301` (in `dictationTab`, after the `.soundFeedback` row: `rowDivider` then `OrbPickerRow(settings: settings)`)

**Interfaces:**
- Consumes: `AppSettings.listeningOrb` and `.orbBackground`; `ListeningOrb.allCases` and `.displayName`; `ThinkingOrb` and `OrbState`.
- Produces: `struct OrbPickerRow: View { @ObservedObject var settings: AppSettings }`

- [ ] **Step 1: Implement `OrbPickerRow`.**
  - It uses `SettingsRowLabel("orb", explanation: "what listens while you talk")`, the label the other rows use.
  - Below that is a `LazyVGrid` of 5 flexible columns with one button per `ListeningOrb`: a 40 pt `ThinkingOrb(state:, theme: .auto, displaySize: 40)` above its `displayName` in caption type.
  - The selected button gets a 2 pt accent ring (`Circle().strokeBorder(.tint, lineWidth: 2)`) and the `.isSelected` trait, with `.accessibilityLabel(displayName)`.
  - Under the grid is a `Toggle("background", isOn: $settings.orbBackground)` in the tab's existing toggle style.
- [ ] **Step 2: Build and run `./dev.sh`, open Settings › Dictation.** Expected: nine live orbs with Composing ringed. Click Globe and the ring moves. The next take shows the Globe orb, and turning off background takes the chip away on the next take.
- [ ] **Step 3: Run the full test command.** Expected: all tests pass.
- [ ] **Step 4: Commit:** `git commit -m "settings: pick the orb, with or without its chip"`.
