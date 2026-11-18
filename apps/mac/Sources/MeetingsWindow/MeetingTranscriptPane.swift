import SwiftUI

/// what was said, on the right: a paragraph to a row, who said it, when,
/// with a find field over it. while the meeting is being recorded it
/// follows the talk and stays at the bottom, unless you have scrolled up to
/// read, in which case a pill offers the way back.
struct MeetingTranscriptPane: View {
    /// the file, or nil for a meeting that has none yet.
    let document: MeetingDocument?
    /// the streaming pass, while the meeting is being recorded.
    let live: LiveTranscriptModel?

    /// the rows of the file, laid out once per file: the window draws this
    /// pane again whenever anything it watches moves — a search, a reload,
    /// a summary — and a long meeting is thousands of rows.
    @State private var rows = Rows()

    var body: some View {
        if let live {
            LiveBody(document: document, live: live, rows: rows)
        } else if let document {
            PaneBody(items: rows.items(for: document), document: document, isLive: false)
        } else {
            EmptyView()
        }
    }

    /// the live model is watched here and only here: the lines change as
    /// often as people talk.
    private struct LiveBody: View {
        let document: MeetingDocument?
        @ObservedObject var live: LiveTranscriptModel
        let rows: Rows

        var body: some View {
            let known = document?.speakers ?? []
            let before = document.map(rows.items(for:)) ?? []
            // a meeting recorded into again gets its new session announced.
            let marker: [MeetingTranscriptBlocks.Item] = document == nil || live.lines.isEmpty
                ? [] : [.init(id: "session-live", kind: .session("now"))]
            PaneBody(
                items: before + marker
                    + MeetingTranscriptBlocks.items(live: live.lines, knownSpeakers: known),
                document: document, isLive: true)
        }
    }

    /// the last file's rows, kept until the file is another. not watched:
    /// it only saves the work, and what is drawn comes from `document`.
    /// an unchanged file is the same arrays, which compare at once.
    final class Rows {
        private var document: MeetingDocument?
        private var items: [MeetingTranscriptBlocks.Item] = []

        func items(for document: MeetingDocument) -> [MeetingTranscriptBlocks.Item] {
            if document != self.document {
                self.document = document
                items = MeetingTranscriptBlocks.items(for: document)
            }
            return items
        }
    }

    private struct PaneBody: View {
        let items: [MeetingTranscriptBlocks.Item]
        let document: MeetingDocument?
        let isLive: Bool

        @State private var query = ""
        @State private var current = 0
        @State private var followsLive = true
        @FocusState private var findFocused: Bool
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        private var matches: [MeetingTranscriptFind.Match] {
            MeetingTranscriptFind.matches(in: items, for: query)
        }

        var body: some View {
            let found = matches
            VStack(spacing: 0) {
                MWPaneHeader(title: "transcript") {
                    findField(count: found.count)
                    MWCopyButton(
                        help: "Copy the transcript", isDisabled: document?.hasWords != true
                    ) {
                        document?.transcriptText ?? ""
                    }
                }
                transcript(found)
            }
            .background {
                // ⌘F: the find field.
                Button("") { findFocused = true }
                    .keyboardShortcut("f", modifiers: .command)
                    .opacity(0)
                    .accessibilityHidden(true)
            }
        }

        // MARK: find

        private func findField(count: Int) -> some View {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                TextField("Find", text: $query)
                    .textFieldStyle(.plain)
                    .focused($findFocused)
                    .onSubmit { step(1, of: count) }
                    .onKeyPress(.return, phases: .down) { press in
                        guard press.modifiers.contains(.shift) else { return .ignored }
                        step(-1, of: count)
                        return .handled
                    }
                    .onExitCommand {
                        query = ""
                        findFocused = false
                    }
                if !query.isEmpty {
                    Text(count == 0 ? "None" : "\(min(current, count - 1) + 1) of \(count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .fixedSize()
                    Button {
                        step(-1, of: count)
                    } label: {
                        Image(systemName: "chevron.up").font(.system(size: 9, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .disabled(count == 0)
                    .accessibilityLabel("Previous match")
                    Button {
                        step(1, of: count)
                    } label: {
                        Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .disabled(count == 0)
                    .accessibilityLabel("Next match")
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 26)
            .frame(minWidth: 96, maxWidth: 240)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(.primary.opacity(0.07))
            }
            .overlay {
                // the field has the keyboard: a ring in the Mac's accent.
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(AppLook.accent.opacity(findFocused ? 0.6 : 0), lineWidth: 2)
            }
            .animation(.easeOut(duration: 0.15), value: findFocused)
        }

        private func step(_ delta: Int, of count: Int) {
            guard count > 0 else { return }
            current = MeetingTranscriptFind.step(min(current, count - 1), by: delta, of: count)
        }

        // MARK: rows

        @ViewBuilder
        private func transcript(_ found: [MeetingTranscriptFind.Match]) -> some View {
            if items.isEmpty {
                Text(isLive ? "Listening…" : "Nobody said anything.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                scroller(found)
            }
        }

        private func scroller(_ found: [MeetingTranscriptFind.Match]) -> some View {
            let active = found.isEmpty ? nil : found[min(current, found.count - 1)]
            return ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            TranscriptRow(
                                item: item, isFirst: index == 0, query: query,
                                activeOccurrence: active?.itemID == item.id ? active?.occurrence : nil)
                        }
                        Color.clear.frame(height: 1).id(Self.bottom)
                    }
                    .padding(.horizontal, MW.s24)
                    .padding(.top, MW.s8)
                    .padding(.bottom, MW.s24)
                    .textSelection(.enabled)
                    .animation(
                        MW.animation(.easeOut(duration: 0.25), reduceMotion: reduceMotion),
                        value: items.count)
                }
                .scrollIndicators(.automatic)
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    geometry.contentOffset.y + geometry.containerSize.height
                        >= geometry.contentSize.height - 32
                } action: { _, atBottom in
                    followsLive = atBottom
                }
                .onChange(of: items.last?.id) { _, _ in
                    guard isLive, followsLive else { return }
                    scrollToEnd(proxy)
                }
                .onChange(of: current) { _, _ in scrollToActive(active: active, proxy: proxy) }
                .onChange(of: query) { _, _ in
                    current = 0
                    let first = MeetingTranscriptFind.matches(in: items, for: query).first
                    if let first {
                        withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(first.itemID, anchor: .center) }
                    }
                }
                .onAppear {
                    if isLive { proxy.scrollTo(Self.bottom, anchor: .bottom) }
                }
                .overlay(alignment: .bottomTrailing) {
                    if isLive, !followsLive {
                        jumpToLive { scrollToEnd(proxy) }
                            .padding(MW.s16)
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }
                }
                .animation(
                    MW.animation(.easeOut(duration: 0.2), reduceMotion: reduceMotion),
                    value: followsLive)
            }
        }

        private static let bottom = "transcript-bottom"

        private func scrollToEnd(_ proxy: ScrollViewProxy) {
            withAnimation(.easeOut(duration: 0.16)) { proxy.scrollTo(Self.bottom, anchor: .bottom) }
        }

        private func scrollToActive(active: MeetingTranscriptFind.Match?, proxy: ScrollViewProxy) {
            guard let active else { return }
            withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(active.itemID, anchor: .center) }
        }

        private func jumpToLive(_ action: @escaping () -> Void) -> some View {
            Button(action: action) {
                Label("Jump to Live", systemImage: "arrow.down")
            }
            .buttonStyle(.glass)
        }
    }
}

// MARK: - one row

private struct TranscriptRow: View {
    let item: MeetingTranscriptBlocks.Item
    let isFirst: Bool
    let query: String
    let activeOccurrence: Int?

    var body: some View {
        switch item.kind {
        case let .session(heading):
            sessionHeading(heading)
        case let .turn(turn):
            paragraph(turn)
                .padding(.top, isFirst ? 0 : (turn.beginsRun ? MW.s16 : MW.s8))
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func sessionHeading(_ heading: String) -> some View {
        HStack(spacing: MW.s12) {
            VStack { Divider() }
            Text(MW.capitalized(heading))
                .font(.caption.weight(.medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .fixedSize()
            VStack { Divider() }
        }
        .padding(.top, isFirst ? 0 : MW.s24)
        .padding(.bottom, MW.s8)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func paragraph(_ turn: MeetingTranscriptBlocks.Turn) -> some View {
        let ink = SpeakerInk.color(turn.colour)
        return HStack(alignment: .top, spacing: MW.s12) {
            // a timestamp is data: monospaced, so the column holds still.
            Text(turn.at.runningClock)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 54, alignment: .leading)
                .padding(.top, turn.beginsRun ? 3 : 2)
            VStack(alignment: .leading, spacing: 4) {
                if turn.beginsRun {
                    Text(MW.capitalized(turn.speaker))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ink)
                        .padding(.horizontal, 8)
                        .frame(height: 18)
                        .background(Capsule().fill(ink.opacity(0.14)))
                }
                Text(highlighted(turn.text))
                    .lineSpacing(4)
                    .foregroundStyle(turn.isConfirmed ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .overlay(alignment: .leading) {
                // a run carries on: the speaker's colour, in the gutter.
                if !turn.beginsRun {
                    Capsule().fill(ink.opacity(0.6)).frame(width: 2)
                        .offset(x: -7)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(turn.speaker), \(turn.at.runningClock): \(turn.text)")
    }

    /// the find field's matches lit a pale yellow, as the Mac's find does, the
    /// one you are on a deeper yellow with a line under it.
    private func highlighted(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return attributed }
        for (index, range) in MeetingTranscriptFind.ranges(of: needle, in: text).enumerated() {
            guard let found = Range(range, in: attributed) else { continue }
            if index == activeOccurrence {
                attributed.paint(found, background: Color.yellow.opacity(0.6))
                attributed.underline(found)
            } else {
                attributed.paint(found, background: Color.yellow.opacity(0.25))
            }
        }
        return attributed
    }
}
