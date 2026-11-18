import SwiftUI

/// the list of meetings: the sidebar's own search field, then what is being
/// recorded, then today, yesterday, this week and earlier. rows are drawn by
/// hand rather than by a List so the selection is the Mac's accent pill (as
/// in settings) whatever the app's own accent, and so the arrow keys and the
/// scroll are ours to keep honest.
struct MeetingsSidebar: View {
    @ObservedObject var state: MeetingsWindowState
    @ObservedObject var library: MeetingsLibraryModel
    @ObservedObject var summaries: MeetingSummaries

    @State private var searchText = ""
    @FocusState private var searchFocused: Bool
    @FocusState private var listFocused: Bool

    private var showsRecordingRow: Bool {
        state.phase != .idle && state.recordingInto == nil
    }

    var body: some View {
        content
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search")
        .searchFocused($searchFocused)
        .onSubmit(of: .search) { listFocused = true }
        .background {
            // ⌘⇧F: the search field. plain ⌘F is the transcript's.
            Button("") { searchFocused = true }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                .opacity(0)
                .accessibilityHidden(true)
        }
        .task(id: searchText) {
            // typing is not a search on every key.
            if searchText.isEmpty {
                library.query = ""
                return
            }
            try? await Task.sleep(for: .milliseconds(150))
            if !Task.isCancelled { library.query = searchText }
        }
    }

    // MARK: - the list

    @ViewBuilder
    private var content: some View {
        if library.isSearching, library.sections.isEmpty {
            noResults
        } else if library.sections.isEmpty, !showsRecordingRow {
            Text(library.hasLoaded ? "No meetings yet" : "")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            list
        }
    }

    private var noResults: some View {
        ContentUnavailableView {
            Label("No meetings match “\(library.trimmedQuery)”", systemImage: "magnifyingglass")
        } actions: {
            Button("Clear Search") { searchText = "" }
                .buttonStyle(.glass)
        }
    }

    private var order: [MeetingsLibraryModel.Selection] {
        (showsRecordingRow ? [.recording] : []) + library.visible.map { .meeting($0.id) }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    if showsRecordingRow {
                        header("Recording", first: true)
                        RecordingRow(
                            state: state,
                            isSelected: library.selection == .recording
                        )
                        .id(MeetingsLibraryModel.Selection.recording)
                        .onTapGesture { choose(.recording) }
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(library.selection == .recording ? [.isButton, .isSelected] : .isButton)
                        .accessibilityAction { choose(.recording) }
                    }
                    ForEach(Array(library.sections.enumerated()), id: \.element.id) { index, section in
                        header(MW.capitalized(section.group.title), first: index == 0 && !showsRecordingRow)
                        ForEach(section.items) { item in
                            row(item, group: section.group)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, MW.s16)
            }
            .scrollIndicators(.never)
            .focusable()
            .focused($listFocused)
            .focusEffectDisabled()
            .onKeyPress(.downArrow) { step(1) }
            .onKeyPress(.upArrow) { step(-1) }
            .onKeyPress(.delete) {
                guard case let .meeting(url)? = library.selection else { return .ignored }
                state.pendingDelete = url
                return .handled
            }
            .onChange(of: library.selection) { _, selection in
                guard let selection else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(selection)
                }
            }
        }
    }

    private func header(_ title: String, first: Bool) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.leading, 10)
            .padding(.top, first ? 4 : MW.s16)
            .padding(.bottom, 2)
            .accessibilityAddTraits(.isHeader)
    }

    private func row(_ item: MeetingsLibraryModel.Item, group: MeetingsLibraryModel.Group) -> some View {
        let url = item.entry.id
        return SidebarRow(
            item: item,
            group: group,
            isSelected: library.selection == .meeting(url),
            isRecording: state.recordingInto == url && state.phase != .idle,
            isSummarizing: summaries.state(for: url) == .summarizing,
            flashes: state.flash == url
        )
        .id(MeetingsLibraryModel.Selection.meeting(url))
        .onTapGesture { choose(.meeting(url)) }
        .contextMenu { MeetingMenuItems(state: state, library: library, summaries: summaries, entry: item.entry) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(library.selection == .meeting(url) ? [.isButton, .isSelected] : .isButton)
        // a click is a tap; voiceover's press, and the context menu's lines,
        // are these.
        .accessibilityAction { choose(.meeting(url)) }
        .accessibilityAction(named: "Record into this meeting") {
            if !state.isBusy { state.record(into: url) }
        }
        .accessibilityAction(named: "Rename") {
            library.selection = .meeting(url)
            state.renameRequest = url
        }
        .accessibilityAction(named: "Show in Finder") { state.revealInFinder(url) }
        .accessibilityAction(named: "Delete") { state.pendingDelete = url }
    }

    private func choose(_ selection: MeetingsLibraryModel.Selection) {
        library.selection = selection
        listFocused = true
    }

    private func step(_ delta: Int) -> KeyPress.Result {
        guard let next = MeetingsLibraryModel.stepped(library.selection, by: delta, in: order) else {
            return .ignored
        }
        library.selection = next
        return .handled
    }
}

// MARK: - rows

/// how a row says when: `Today · 9:30`, `Thu · 14:02`, `16 Oct · 09:30`.
@MainActor
enum SidebarWhen {
    static func label(
        _ date: Date, group: MeetingsLibraryModel.Group, now: Date = Date(),
        calendar: Calendar = .current, locale: Locale = .current
    ) -> String {
        let day: String
        switch group {
        case .today: day = "Today"
        case .yesterday: day = "Yesterday"
        case .thisWeek: day = format(date, "EEE", calendar, locale)
        case .earlier:
            let sameYear = calendar.isDate(date, equalTo: now, toGranularity: .year)
            day = format(date, sameYear ? "d MMM" : "d MMM yyyy", calendar, locale)
        }
        return "\(day) · \(format(date, "jmm", calendar, locale))"
    }

    private static func format(
        _ date: Date, _ template: String, _ calendar: Calendar, _ locale: Locale
    ) -> String {
        MW.date(date, template, calendar: calendar, locale: locale)
    }
}

/// a row's surface: the Mac's accent pill when chosen (white words on it,
/// as in settings and Finder), a faint wash under the pointer, nothing at
/// rest. in a window that is not in front the pill goes grey, as a
/// sidebar's does.
private struct RowSurface: ViewModifier {
    let isSelected: Bool
    var flashes = false

    @Environment(\.appearsActive) private var appearsActive
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false
    @State private var glow = 0.0

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
    }

    private var isLit: Bool { isSelected && appearsActive }

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 10)
            .frame(height: 62)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(isLit ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .environment(\.rowIsLit, isLit)
            .background {
                if isSelected {
                    shape.fill(appearsActive ? AnyShapeStyle(AppLook.accent) : AnyShapeStyle(.primary.opacity(0.1)))
                } else {
                    shape.fill(.primary.opacity(isHovering ? 0.05 : 0))
                }
            }
            .overlay {
                // the meeting just saved says so once, in the accent.
                shape.fill(AppLook.accent.opacity(glow)).allowsHitTesting(false)
            }
            .contentShape(shape)
            .onHover { isHovering = $0 }
            .onChange(of: flashes, initial: true) { _, now in
                guard now, !reduceMotion else { return }
                glow = 0.3
                withAnimation(.easeOut(duration: 1.1)) { glow = 0 }
            }
            .animation(.easeOut(duration: 0.12), value: isHovering)
            .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}

private extension EnvironmentValues {
    /// the row sits on the accent pill: its quieter words go white too.
    @Entry var rowIsLit = false
}

/// a row's second and third lines: secondary on the sidebar, a softer white
/// on the accent pill.
private struct RowQuiet: ViewModifier {
    var level = 1
    @Environment(\.rowIsLit) private var isLit

    func body(content: Content) -> some View {
        if isLit {
            content.foregroundStyle(.white.opacity(level == 1 ? 0.85 : 0.7))
        } else {
            content.foregroundStyle(level == 1 ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tertiary))
        }
    }
}

private extension View {
    func rowQuiet(_ level: Int = 1) -> some View { modifier(RowQuiet(level: level)) }
}

private struct SidebarRow: View {
    let item: MeetingsLibraryModel.Item
    let group: MeetingsLibraryModel.Group
    let isSelected: Bool
    let isRecording: Bool
    let isSummarizing: Bool
    let flashes: Bool
    @Environment(\.appearsActive) private var appearsActive
    /// on the accent pill (`RowSurface`), where its marks go white.
    private var isLit: Bool { isSelected && appearsActive }

    private var entry: MeetingsLibraryModel.Entry { item.entry }

    var body: some View {
        HStack(alignment: .top, spacing: MW.s8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    status
                    Text(entry.title)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(entry.summary.duration.runningClock)
                        .font(.caption.monospacedDigit())
                        .rowQuiet()
                        .lineLimit(1)
                        .fixedSize()
                }
                .frame(height: 18)
                meta
                    .frame(height: 16)
                lastLine
                    .frame(height: 14)
            }
        }
        .modifier(RowSurface(isSelected: isSelected, flashes: flashes))
    }

    @ViewBuilder
    private var status: some View {
        if isRecording {
            PulsingRecordDot(size: 7)
        } else if isSummarizing {
            MWSpinner(size: 10, lineWidth: 1.5, color: isLit ? .white : nil)
        }
    }

    private var meta: some View {
        HStack(spacing: MW.s8) {
            Text(SidebarWhen.label(entry.summary.started, group: group))
                .font(.caption)
                .rowQuiet()
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            SpeakerDots(speakers: entry.speakers)
            if entry.summary.sessions > 1 {
                Text("\(entry.summary.sessions) sessions")
                    .font(.caption2.weight(.medium))
                    .rowQuiet()
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 6)
                    .frame(height: 16)
                    .background(Capsule().fill(.primary.opacity(0.08)))
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var lastLine: some View {
        if isSummarizing {
            GeometryReader { proxy in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(.primary.opacity(0.1))
                    .frame(width: proxy.size.width * 0.6, height: 6)
                    .mwShimmer()
                    .frame(maxHeight: .infinity)
            }
        } else {
            Text(line)
                .font(.caption)
                .rowQuiet(2)
                .lineLimit(1)
        }
    }

    private var line: String {
        if let hit = item.hit { return hit }
        if !entry.hasWords { return "Nobody spoke" }
        return entry.snippet
    }
}

/// up to three dots in the speakers' colours, then how many more.
private struct SpeakerDots: View {
    let speakers: [String]

    var body: some View {
        if !speakers.isEmpty {
            HStack(spacing: 4) {
                HStack(spacing: 3) {
                    ForEach(Array(speakers.prefix(3).enumerated()), id: \.offset) { _, speaker in
                        Circle()
                            .fill(SpeakerInk.color(
                                MeetingTranscriptBlocks.colour(of: speaker, in: speakers)))
                            .frame(width: 7, height: 7)
                    }
                }
                if speakers.count > 3 {
                    Text("+\(speakers.count - 3)")
                        .font(.caption2.weight(.medium))
                        .rowQuiet()
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(speakers.count == 1
                ? "1 speaker: \(speakers[0])"
                : "\(speakers.count) speakers: \(speakers.joined(separator: ", "))")
        }
    }
}

/// a red dot that breathes, slowly: something is being heard. still, and
/// fully lit, when the Mac is asked for less motion.
struct PulsingRecordDot: View {
    var size: CGFloat = 10

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false

    var body: some View {
        Circle()
            .fill(MW.recordingRed)
            .frame(width: size, height: size)
            .shadow(color: MW.recordingRed.opacity(breathing ? 0.15 : 0.5), radius: size * 0.4)
            .opacity(breathing ? 0.45 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    breathing = true
                }
            }
            .accessibilityLabel("Recording")
    }
}

/// the pinned row for a meeting that has no file yet.
private struct RecordingRow: View {
    @ObservedObject var state: MeetingsWindowState
    let isSelected: Bool
    @Environment(\.appearsActive) private var appearsActive
    /// on the accent pill (`RowSurface`), where its marks go white.
    private var isLit: Bool { isSelected && appearsActive }

    private var title: String {
        if let typed = state.recordingTitle { return typed }
        return MeetingDocument.untitled(app: state.coordinator.meetings.currentCall ?? "meeting")
    }

    private var phaseLine: String {
        switch state.phase {
        case .idle: ""
        case .gettingReady: "Getting ready…"
        case .recording: "Recording"
        case .problem: (state.phase.menuLine(elapsed: .zero) ?? "recording").capitalizedFirst
        case .writingOut: "Writing it out…"
        }
    }

    private var isProblem: Bool {
        if case .problem = state.phase { return true }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                PulsingRecordDot(size: 7)
                Text(title)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
                TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                    Text(state.coordinator.meetings.elapsed.runningClock)
                        .font(.caption.monospacedDigit())
                        .rowQuiet()
                        .fixedSize()
                }
            }
            .frame(height: 18)
            Group {
                if isProblem {
                    Text(phaseLine).foregroundStyle(isLit ? .white : .orange)
                } else {
                    Text(phaseLine).rowQuiet()
                }
            }
            .font(.caption)
            .lineLimit(1)
            .frame(height: 16)
            Color.clear.frame(height: 14)
        }
        .modifier(RowSurface(isSelected: isSelected))
    }
}

// MARK: - the menu a meeting has

/// the same lines in the row's context menu and the detail's `…` menu.
struct MeetingMenuItems: View {
    @ObservedObject var state: MeetingsWindowState
    @ObservedObject var library: MeetingsLibraryModel
    @ObservedObject var summaries: MeetingSummaries
    let entry: MeetingsLibraryModel.Entry

    private var document: MeetingDocument? { library.document(for: entry.id) }
    private var busy: Bool { summaries.state(for: entry.id) == .summarizing }

    var body: some View {
        Button("Record into This Meeting") { state.record(into: entry.id) }
            .disabled(state.isBusy)
        Button("Rename") {
            library.selection = .meeting(entry.id)
            state.renameRequest = entry.id
        }
        Menu("Summarize Again") {
            ForEach(MeetingTemplate.builtIn) { template in
                Button {
                    state.summarize(entry.id, templateID: template.id)
                } label: {
                    Label(MW.capitalized(template.name), systemImage: template.symbol)
                }
            }
        }
        .disabled(busy || !entry.hasWords)
        Divider()
        Button("Copy Summary") {
            if let notes = document?.summary { MW.copy(notes) }
        }
        .disabled(document?.summary == nil)
        Button("Copy Transcript") {
            if let document { MW.copy(document.transcriptText) }
        }
        .disabled(document == nil || !entry.hasWords)
        Divider()
        Button("Show in Finder") { state.revealInFinder(entry.id) }
        Button("Delete…", role: .destructive) { state.pendingDelete = entry.id }
    }
}
