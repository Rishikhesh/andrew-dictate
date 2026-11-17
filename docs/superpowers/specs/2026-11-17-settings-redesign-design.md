# Settings redesign: design

Date: 2026-11-17 · Branch `settings-redesign` (on top of `listening-orb`) · Approved from the mock `settings-b.html` (option B, system accent, Liquid Glass)

## Why

The settings window felt like a branded web page, not a Mac app:
- dark mode forced on and gold everywhere
- all-lowercase text
- hand-built rows with no grouped forms
- actions that only appear on hover
- no scrolling on long tabs

The aim is a clean, efficient window that looks and behaves like macOS 26's System Settings.

## Goals

- **Layout:** a System Settings–style window, with a sidebar and grouped forms (`Form` + `.formStyle(.grouped)`). Native controls everywhere a native control does the job.
- **Eight sections:** Home, Dictation, Listening, AI, Meetings, Dictionary, History, General. Every setting from today's six tabs survives (see the inventory below); none is lost.
- **Home**, a small dashboard:
  - words dictated (all time, today)
  - typical paste and slowest 1 in 20
  - a 7-day words chart
  - the 3 most recent dictations
  - setup problems shown at the top, with a badge on Home in the sidebar
- **Appearance:** follows the Mac's Light or Dark setting. The accent follows the Mac's accent colour (blue when the Mac is set to Multicolor), **in Settings only**. Liquid Glass comes from the native macOS 26 controls.
- **Text:** sentence case (Apple style) in place of all-lowercase.
- **Nothing hidden:** history rows and styles get a visible "⋯" menu, also on right-click. Deleting a single item asks first. History search is the toolbar's native search field, so ⌘F works.

## Non-goals

- Other windows (menu bar panel, onboarding, Meetings window, About) keep their gold look. They're a later redesign.
- No new settings or behaviour, apart from delete confirmations and the dashboard's read-only numbers.
- The orb overlay and the dictation pipeline don't change.

## Anti-goals

- Losing any setting, list, sheet or alert that exists today.
- Custom imitations of native controls where a native one works.
- A dashboard that invents numbers. Every figure comes from data the app already keeps.

## Approaches considered

- **A. Pure System Settings, all native.** Rejected: the cleanup preview, the live orb grid and the tone pad would be flattened into menus that can't show what they show.
- **B. System Settings layout, native wherever it fits, keeping custom pieces that earn their place.** Chosen.
- **C. Keep the toolbar tabs and only regroup inside them.** Rejected: Home and History would feel cramped.

## Design

### Shell
- `SettingsView` becomes a `NavigationSplitView`:
  - **Sidebar:** a `List(selection:)` of `SettingsSection` rows. Each row has an SF Symbol in a coloured rounded tile, like System Settings.
  - **Detail:** the selected pane, with the section title in the toolbar.
- The window is resizable: minimum 760 × 520, ideal 860 × 620.
- These come off the window: `.brandGlassWindow()`, `.preferredColorScheme(.dark)`, `.brandTinted()`, `.controlSize(.small)`, and the BrandUI font and colour overrides.
- The tint is `SystemAccent.color`: the user's chosen accent read from the global `AppleAccentColor` default (-1 graphite, 0 red, 1 orange, 2 yellow, 3 green, 4 blue, 5 purple, 6 pink), or blue when it isn't set (Multicolor).

### Sections
1. **Home** (new): setup issues section, then 4 stat tiles, then a 7-day chart (Swift Charts `BarMark`, today in the accent colour), then Recent (3 rows plus "Show All in History"), then a footer with the model status. The numbers come from a pure `DashboardStats` built from:
   - `[Dictation]` (the archive)
   - `totalWordsDictated`
   - `TimelineSummary`

   Today and the chart count only kept dictations. When keeping is off, the chart shows a note instead.
2. **Dictation:**
   - **Key:** a native `Picker` menu.
   - **Behavior:** keep the microphone ready, sound feedback.
   - **Cleanup:** a toggle plus the existing before/after preview, restyled with system colours.
   - **Speech model:** a radio list with status (On this Mac / Downloading + progress / Downloads when chosen / Failed + Retry), plus "Show in Finder" and "Remove a Download…".
3. **Listening:** the orb grid (kept), with Size (segmented) and Background (toggle) in a Look section.
4. **AI:**
   - **Provider:** provider picker, account row (status, Sign In / Paste Key / Sign Out), model field with its suggestions menu.
   - **Rewrite:** toggle, rewrite keys.
   - **Styles:** a list with a number, a Default tag and a "⋯" menu with Make Default / Edit… / Remove…, also on right-click. "New Style…" sits in the section header. As said is the last row.
   - **Summaries:** toggle, template.
   - A privacy footer.
   - The style editor sheet and tone pad stay, restyled.
5. **Meetings:**
   - **Meeting model:** a radio list.
   - **Recording:** shortcut recorder plus Clear, keep meeting audio.
   - **Saving:** folder (path, Show in Finder, Change…), after saving run (path, last run line, Open Log, Clear, Choose…).
6. **Dictionary:** intro, "Did it get these right?" suggestions, the existing native `Table`, + / −, Import… / Export…, and the import alert.
7. **History:**
   - **Toolbar:** a segmented Dictations / Meetings control, plus `.searchable`.
   - **Rows:** a `List` with a "⋯" menu and a context menu (dictations: Copy, Fix a Word…, Delete…; meetings: Open, Show in Finder, Transcribe Again With ▸, Delete Audio Now, Delete…). Each Delete… confirms.
   - **Footer group:** keep new dictations (with count), Delete All…, show folder; the set-aside banner for meetings.
8. **General:** open at login, check for updates, copy timing report, version, Remove Andrew Dictate… (existing sheet).

### Copy
Sentence case for labels, buttons and alerts, with Title Case for buttons that open panels ("Show in Finder", "Change…"), as macOS does. The meaning of every string stays the same; only the case and some tightening change. Tests that pin exact copy get updated alongside.

## Testing

- **Pure units with XCTest:**
  - `SettingsSection` (order, titles, symbols)
  - `SystemAccent` (each stored value, plus absent → blue)
  - `DashboardStats` (today's words, 7-day buckets including empty days, the 3 most recent, timing formatting, the keep-off case)
- The full suite stays green after every task.
- **Hands-on:** open Settings in `./dev.sh`, visit every section in Light and Dark, tick each control, and check Reduce Transparency.

## Inventory (must survive)

Each task in the plan (`docs/superpowers/plans/2026-11-17-settings-redesign.md`) carries the checklist of controls its section must keep.
