# Settings Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the six-tab, gold, dark-only settings window into a System Settings–style window: a sidebar, eight grouped-form sections, the system accent, and Liquid Glass.

**Architecture:** `SettingsView` becomes a `NavigationSplitView` driven by a `SettingsSection` enum. Each section is a `Form` with `.formStyle(.grouped)` in its own file under `Settings/Panes/`. Tested pure models (`SettingsSection`, `SystemAccent`, `DashboardStats`) carry the logic. Views stay thin and reuse the existing models (`ArchiveBrowserViewModel`, `MeetingsListModel`, `RewriteSettings`, `DictionaryStore`, `LoginItemController`, `ArchiveSettingsModel`, `ModelStore`).

**Tech Stack:** Swift 6 strict concurrency, SwiftUI on macOS 26 (`NavigationSplitView`, `Form`, `.searchable`, Swift Charts), XCTest, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-11-17-settings-redesign-design.md`

## Global Constraints

- Settings window only. Don't change `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME`, BrandUI, or any other window.
- Tint the settings window with `SystemAccent.color`; never use gold or `BrandUI` colours inside settings panes.
- No forced colour scheme and no `.controlSize(.small)`. Use the system font.
- Sentence case for labels, captions and alerts. Title Case for button titles ("Show in Finder", "Change…", "Delete All…").
- Every control in each task's checklist must exist when that task ends. Losing one fails the task.
- Run the test command from `apps/mac`, through `.superpowers/sdd/2026-11-17-listening-orb/runtests.sh [Class…]`. It runs XcodeGen and then `xcodebuild … test`, and prints `Passed passed N failed 0`.
- Commits are signed (the user's key is loaded) and end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Run a full suite at the end of every task.

## Review Focus

1. **Keeping dictations is off:** the archive is empty, so Home must say so and not show zeros as if they were real. Pinned by `DashboardStatsTests.testNothingKeptSaysSo`.
2. **No timings yet:** a fresh install shows "—" for the paste speeds, never "0 ms". Pinned by `DashboardStatsTests.testNoTimingsShowDash`.
3. **Midnight and time zones:** "today" and the 7 day buckets use the user's calendar day, not UTC. Pinned by `DashboardStatsTests.testDaysFollowTheLocalCalendar`.
4. **An unknown or missing `AppleAccentColor`** (a future value, or Multicolor): blue, never a crash. Pinned by `SystemAccentTests.testUnknownAndMissingAreBlue`.
5. **Deleting from history:** a single delete must confirm, and Cancel must leave the item untouched. This is a manual check in Task 8.

---

### Task 1: The shell (sidebar, sections, accent)

**Files:**
- Create: `Sources/Settings/SettingsSection.swift` (enum plus sidebar tile view)
- Create: `Sources/Settings/SystemAccent.swift`
- Modify: `Sources/Settings/SettingsView.swift` (body → `NavigationSplitView`; window modifiers; `selectedTab` → `selectedSection`; onChange hooks retargeted)
- Modify: `project.yml` (add `SettingsSection.swift` and `SystemAccent.swift` to the test target sources, next to `Sources/Settings/AppSettings.swift`)
- Test: `Tests/SettingsSectionTests.swift`, `Tests/SystemAccentTests.swift`

**Interfaces:**
- Produces:
  - `enum SettingsSection: String, CaseIterable, Identifiable { case home, dictation, listening, ai, meetings, dictionary, history, general }`, with `var title: String` (Home, Dictation, Listening, AI, Meetings, Dictionary, History, General), `var symbol: String` (`house`, `waveform`, `circle.dotted`, `sparkles`, `person.2.wave.2`, `character.book.closed`, `clock.arrow.circlepath`, `gearshape`) and `var tileColor: Color` (indigo, orange, purple, blue, green, pink, teal, gray).
  - `enum SystemAccent { static func color(stored: Int?) -> Color; static var color: Color }`. The stored values map as -1 → gray, 0 → red, 1 → orange, 2 → yellow, 3 → green, 4 → blue, 5 → purple, 6 → pink, and nil or anything else → blue. `color` reads `UserDefaults.standard.object(forKey: "AppleAccentColor") as? Int`.
  - `SettingsView` has `@State var selectedSection: SettingsSection = .home`.

- [ ] Write the failing tests:
  - `testOrderIsHomeFirstGeneralLast` (all 8 in order)
  - `testEveryRowHasATitleAndSymbol`
  - `testStoredAccentsMap` (each of -1…6)
  - `testUnknownAndMissingAreBlue` (nil, 7, -5 → `.blue`)

  Compare colours with `XCTAssertEqual(SystemAccent.color(stored: 4), .blue)`.
- [ ] Run them and confirm they fail (missing types).
- [ ] Implement the two files, then restructure `SettingsView.body`:
  - The sidebar is a `List(SettingsSection.allCases, selection: $selectedSection)`. Each row is a 20 pt rounded tile in `tileColor` with a white SF Symbol, then the title. Home gets `.badge(setupIssues.count)` when that's above 0.
  - The detail is a `switch selectedSection`, showing the existing tab bodies for now: Home shows a placeholder `Text("Home")` until Task 2; Dictation shows `dictationTab` minus `OrbPickerRow`; Listening shows `OrbPickerRow`; and so on.
  - Use `.navigationTitle(selectedSection.title)`.
  - Remove `.frame(width: 800)`, `.brandGlassWindow()`, `.foregroundStyle(BrandUI.textPrimary)`, `.font(BrandUI.bodyFont)`, `.brandTinted()`, `.controlSize(.small)` and `.preferredColorScheme(.dark)`. Add `.tint(SystemAccent.color)` and `.frame(minWidth: 760, idealWidth: 860, minHeight: 520, idealHeight: 620)`.
  - Retarget the `.onChange(of: selectedTab)` hooks to `.history` and `.general`.
- [ ] Run the full suite and confirm it passes. Run `./dev.sh`, open Settings, and click all 8 sections. Every old control should still be present, even if not yet restyled.
- [ ] Commit: "settings: a sidebar of eight sections, the system accent, no forced dark".

### Task 2: Home dashboard

**Files:** create `Sources/Settings/DashboardStats.swift` (add it to the test target in `project.yml`), `Sources/Settings/Panes/HomePane.swift`, and `Tests/DashboardStatsTests.swift`. In `SettingsView`, the Home case renders `HomePane`.

**Interfaces:**
- Produces: `struct DashboardStats: Equatable { static func make(dictations: [Dictation], totalWords: Int, timings: TimelineSummary?, keepsDictations: Bool, now: Date, calendar: Calendar) -> DashboardStats }`. Its fields:
  - `totalWords: Int`
  - `todayWords: Int?` (nil when nothing is kept)
  - `lastSevenDays: [DayWords]`: `struct DayWords: Equatable { let day: Date; let words: Int; let isToday: Bool }`, 7 entries, oldest first, with empty days at 0
  - `recent: [Dictation]` (at most 3, newest first)
  - `typicalPaste: String` and `slowestPaste: String` (formatted like "212 ms", or "—")
  - `pasteSample: Int`
  - `keptNothing: Bool`
- Words are counted as whitespace-separated words of `inserted`.

- [ ] Write the failing tests:
  - `testTodayAndWeekCountKeptWords` (dictations on 3 days, one 8 days ago that's excluded)
  - `testEmptyDaysAreZero`
  - `testRecentIsNewestThree`
  - `testNoTimingsShowDash`
  - `testTimingsFormatInMilliseconds`
  - `testNothingKeptSaysSo` (keep off, empty archive: `todayWords == nil`, `keptNothing == true`)
  - `testDaysFollowTheLocalCalendar` (a fixed `TimeZone(identifier: "Asia/Kolkata")` calendar; 23:50 local is today, not tomorrow UTC)
- [ ] Run them and confirm they fail.
- [ ] Implement `DashboardStats`.
- [ ] Implement `HomePane(stats:issues:onFinishSetup:onShowHistory:)`:
  - **Setup issues** as a `Section`: each issue row is a red title plus a detail; a "Finish Setup…" `.borderedProminent` button runs `coordinator.runOnboardingAgain()`.
  - **Stats:** a `Grid` of 4 tiles (rounded rects in `.background.secondary`, a caption, and the value in `.title2` monospaced digits).
  - **Last 7 days:** a `Chart` of `BarMark` per day, with today `.foregroundStyle(.tint)` and the rest `.secondary`; when `keptNothing`, the text "Turn on Keep new dictations in History to see your days."
  - **Recent:** 3 rows (text with lineLimit 1, plus the relative date) and "Show All in History", which sets `selectedSection = .history`.
  - **Footer:** "Dictation model: {name}, {state} · Meeting model: {name}".

  Build the stats in `SettingsView` from `browser.items`, `settings.totalWordsDictated`, `timings` and `settings.keepDictations`.
- [ ] Run the full suite and confirm it passes. Hands-on: Home shows real numbers.
- [ ] Commit: "settings: home, your numbers at a glance".

### Task 3: Dictation pane

**Files:** create `Sources/Settings/Panes/DictationPane.swift` and `Sources/Settings/ModelRadioList.swift` (shared with Task 6); modify `SettingsView.swift` (move `dictationTab`, `hotkeyRow` and `engineEditor` out); restyle `PipelineView.swift` with system colours (replace `BrandUI.gold` highlights with `.tint` at 0.25 opacity and attention red with `.red`).

**Checklist that must survive:**
- the hotkey choice (7 options; an option is disabled when it conflicts with the meeting shortcut) and the key-press light (use the label tint for 250 ms)
- pre-roll and sound feedback, with their explanations
- the cleanup toggle and the heard → cleanup → pasted preview, with its caption and marker line
- the speech model choice (5 models, traits, states, progress, the active tag, the experimental tag)
- retry when the chosen model failed
- "Show in Finder" for the model folder
- "Remove a Download…" (a menu of downloaded models) and the removal alert
- `modelStoreMessage` and `engineSwitchMessage`
- the setup banner (moves to Home)

**Interfaces:**
- Produces: `struct ModelRadioList: View { init(models: [SpeechModel], selection: Binding<SpeechModel>, trait: (SpeechModel) -> String, status: (SpeechModel) -> ModelRowStatus) }` with `enum ModelRowStatus: Equatable { case onThisMac(active: Bool), downloading(Double?), loading, failed, switching, downloadsWhenChosen, downloadsAtNextMeeting }`.
- Each row is a radio circle (`Image(systemName: selected ? "largecircle.fill.circle" : "circle")` in `.tint`), the name (plus a "Experimental" tag for whistle), the trait in `.secondary`, then status text, a `ProgressView(value:)` when downloading, or "Active" as a `.secondary` capsule tag.

- [ ] Build the pane as Form sections: Dictation key (`Picker` `.menu`), Behavior, Cleanup (`Toggle`, then `PipelineView` inside the section), Speech model (`ModelRadioList`, then a row with "Show in Finder" and the "Remove a Download…" `Menu`, then the messages).
- [ ] Map each card state to `ModelRowStatus` exactly as `ModelChooserView` does today, then delete `ModelChooserView`'s use from the Dictation pane.
- [ ] Run the full suite and confirm it passes. Hands-on: every checklist item works.
- [ ] Commit: "settings: dictation as a grouped form, models as a radio list".

### Task 4: Listening pane

**Files:** create `Sources/Settings/Panes/ListeningPane.swift`; modify `OrbPickerRow.swift` (split it into an `OrbGrid` view; the size and background controls move into the pane's "Look" section).

**Checklist:** the 9 live orbs with selection, Size (segmented), Background (toggle), and the explanation copy.

- [ ] Build the Form: an Orb section (`OrbGrid` with a footer of "One orb for the whole take. Your voice only changes its pace and size."), and a Look section (Size, Background).
- [ ] Run the full suite and confirm it passes, then commit: "settings: listening, the orb on its own page".

### Task 5: AI pane

**Files:** modify `Sources/Settings/RewriteSettingsView.swift`:
- Replace the ScrollView, the fixed 230 pt column, `BrandSectionHeader`, `textButton`, `divider` and `defaultBadge` with Form sections and native buttons.
- Keep `RewriteStyleEditor`, but drop its `.preferredColorScheme(.dark)` and gold, and give it a native sheet layout.
- Restyle `TonePadView.swift`'s colours to `.tint` and `.secondary`.

**Checklist:**
- provider picker (5 providers) with its explanation
- account states: ready (with sign out or remove key), working (with cancel), unavailable, and needs setup (sign in, paste a key + Save, get a key link)
- model field with the suggestions menu
- rewrite toggle with the dynamic explanation
- rewrite modifier choice (4, with the conflict-disabled state) shown with the dictation key
- styles list (number, name, summary, Default tag, Make Default, Edit…, Remove… with its alert, New Style… disabled at the limit, the "As said" row)
- style editor (name, tone pad with arrow keys, presets, reset, notes, the try-it sample and result, Cancel/Save)
- summaries toggle with the provider-dependent text, template picker (6 with symbols), privacy footer

- [ ] Rows that used hover now have a `Menu { … } label: { Image(systemName: "ellipsis.circle") }` with `.menuStyle(.borderlessButton)` and the same items in `.contextMenu`.
- [ ] Run the full suite and confirm it passes. Hands-on: sign-in flows unchanged, and editing and removing a style works.
- [ ] Commit: "settings: ai as a grouped form, styles with a visible menu".

### Task 6: Meetings pane

**Files:** create `Sources/Settings/Panes/MeetingsPane.swift` (move `meetingsTab` and its helpers out of `SettingsView`); restyle `MeetingShortcutRow.swift` to a native bordered button recorder (keep its NSEvent monitor logic unchanged); the meeting model uses `ModelRadioList`.

**Checklist:**
- meeting model (5, with meeting traits and states)
- shortcut recorder (press a shortcut…, Esc cancels, ⌘W/⌘Q pass through, Clear, refusal and failure messages)
- save folder (path middle-truncated, the iCloud warning, Show in Finder, Change… open panel)
- keep meeting audio (3, with the dynamic caption)
- after-saving script (path or "Nothing", Choose…, Clear, last run with relative time and label, red when not ok, Open Log, the $1 / JSON caption)

- [ ] Build the Form sections Meeting model, Recording and Saving, run the full suite and confirm it passes, then commit: "settings: meetings as a grouped form".

### Task 7: Dictionary pane

**Files:** create `Sources/Settings/Panes/DictionaryPane.swift` (move `dictionaryTab`, `DictionaryEditor` and `DictionaryCellEditor` out of `SettingsView.swift`).

**Checklist:**
- intro copy
- suggestions (heard word · count, "What you meant" field, Save, Not a Mistake)
- Table (Wrong / Right, multi-select, inline editing with revert on refusal, the Learned tag with tooltip, the × remove with tooltip, the empty state)
- + / −, Import… / Export… panels, the import alert (Add to Mine / Replace / Cancel), and the messages

- [ ] Replace gold with `.tint`, remove the `windowBg` table background (use `.scrollContentBackground(.visible)`), and put the suggestions in a Form section above the table. Run the full suite, confirm it passes, and commit: "settings: dictionary, native table, system colours".

### Task 8: History pane

**Files:** create `Sources/Settings/Panes/HistoryPane.swift`; modify `Archive/ArchiveBrowserView.swift` and `Settings/MeetingsBrowserView.swift` (hover actions → "⋯" `Menu` plus `.contextMenu`; single delete → `.confirmationDialog`; LazyVStack → `List`).

**Checklist:**
- segmented Dictations / Meetings, which goes in `.toolbar { ToolbarItem(placement: .principal) }`
- search via `.searchable(text:)` bound to `browser.query` or `meetings.query` depending on the segment; ⌘F is native, so remove the hidden button
- dictation rows (text with search highlight, date, heard-when-different; Copy, Fix a Word…, Delete… confirming "Delete this dictation? This can't be undone.")
- meeting rows (date · app · duration · completeness, audio kept until, transcribing again; Open (double-click too), Show in Finder, Transcribe Again With ▸ (or the reason it can't), Delete Audio Now, Delete… confirming)
- set-aside banner (Try Again, Show in Finder)
- empty and failure states
- footer: Keep new dictations, count, Delete All… (the existing alert), Show Folder in Finder

- [ ] Build it, run the full suite, and confirm it passes. Hands-on: Cancel on a delete leaves the row in place; Delete removes it.
- [ ] Commit: "settings: history with a toolbar search, visible menus, and deletes that ask".

### Task 9: General pane and clean-up

**Files:** create `Sources/Settings/Panes/GeneralPane.swift` (move `generalTab` out); the stats move to Home, so remove the "the numbers" block. Delete now-unused settings helpers (`rowDivider`, `statTile`, `BrandSectionHeader` uses in settings, `ModelChooserView`/`MeetingModelChooserView`/`ModelCardView` if unreferenced). Drop `RemovalView`'s forced dark scheme.

**Checklist:** open at login (with its message), check for updates (with its explanation), Copy Timing Report (when `canCopyTimings`), version line, Remove Andrew Dictate… (when `canUninstall`) with the existing sheet.

- [ ] Do a sentence-case copy pass over every settings string, and update any test asserting old copy (search `Tests/` for the changed strings).
- [ ] Run the full suite, confirm it passes, and commit: "settings: general, and the last of the brand styling out of settings".
