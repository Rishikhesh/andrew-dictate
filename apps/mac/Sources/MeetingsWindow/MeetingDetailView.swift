import SwiftUI

/// one meeting: its name across the top, what you can do with it in the
/// window's toolbar, then the notes on the left and what was said on the right. below 760pt of
/// width the two cannot both be read, so they become a pair of tabs.
struct MeetingDetailView: View {
    @ObservedObject var state: MeetingsWindowState
    @ObservedObject var library: MeetingsLibraryModel
    @ObservedObject var summaries: MeetingSummaries
    let entry: MeetingsLibraryModel.Entry
    let document: MeetingDocument

    var body: some View {
        VStack(spacing: 0) {
            MeetingDetailHeader(
                state: state, library: library, summaries: summaries,
                entry: entry, document: document)
            Divider()
            MeetingSplit {
                MeetingSummaryPane(
                    url: entry.id, document: document, summaries: summaries,
                    settings: state.coordinator.rewriteSettings,
                    accounts: state.coordinator.rewriteAccounts,
                    summarize: { state.summarize(entry.id, templateID: currentTemplate.id) })
            } transcript: {
                MeetingTranscriptPane(
                    document: document,
                    live: isRecordingIntoThis ? state.coordinator.liveTranscript : nil)
            }
        }
    }

    private var currentTemplate: MeetingTemplate {
        MeetingTemplate.resolving(
            document.header.template ?? state.coordinator.rewriteSettings.defaultTemplateID)
    }

    private var isRecordingIntoThis: Bool {
        state.recordingInto == entry.id && state.phase != .idle
    }
}

/// the meeting being recorded, which has no file yet: the same two panes,
/// with the notes waiting for the end and the transcript following the talk.
struct RecordingDetailView: View {
    @ObservedObject var state: MeetingsWindowState

    private var title: String {
        if let typed = state.recordingTitle { return typed }
        return MeetingDocument.untitled(app: state.coordinator.meetings.currentCall ?? "meeting")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: MW.s12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title2.weight(.bold))
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        PulsingRecordDot(size: 7)
                        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                            Text("Recording · \(state.coordinator.meetings.elapsed.runningClock)")
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, MW.s24)
            .padding(.top, MW.s12)
            .padding(.bottom, MW.s16)
            Divider()
            MeetingSplit {
                VStack(spacing: 0) {
                    MWPaneHeader(title: "summary") { EmptyView() }
                    VStack(spacing: MW.s12) {
                        IconTile(symbol: "sparkles", tint: .purple, size: 40)
                        Text("The notes are written when the meeting ends.")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(MW.s24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } transcript: {
                MeetingTranscriptPane(
                    document: nil, live: state.coordinator.liveTranscript)
            }
        }
    }
}

/// the two panes side by side, 55 and 45, or one at a time under a switch.
struct MeetingSplit<Summary: View, Transcript: View>: View {
    @ViewBuilder var summary: Summary
    @ViewBuilder var transcript: Transcript

    private enum Side: String, CaseIterable {
        case summary, transcript
    }

    @State private var side = Side.summary
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static var collapsesBelow: CGFloat { 760 }

    var body: some View {
        GeometryReader { proxy in
            if proxy.size.width >= Self.collapsesBelow {
                HStack(spacing: 0) {
                    summary
                        .frame(width: max(340, (proxy.size.width - 1) * 0.55))
                    Divider()
                    transcript
                        .frame(maxWidth: .infinity)
                }
            } else {
                VStack(spacing: 0) {
                    Picker("Show", selection: $side) {
                        ForEach(Side.allCases, id: \.self) { Text(MW.capitalized($0.rawValue)).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                    .padding(.top, MW.s12)
                    .padding(.bottom, MW.s8)
                    switch side {
                    case .summary: summary
                    case .transcript: transcript
                    }
                }
            }
        }
    }
}

// MARK: - header

/// the meeting's name, big, with when and how long under it; its actions
/// are the window's toolbar, in glass, where a Mac app keeps them.
private struct MeetingDetailHeader: View {
    @ObservedObject var state: MeetingsWindowState
    @ObservedObject var library: MeetingsLibraryModel
    @ObservedObject var summaries: MeetingSummaries
    let entry: MeetingsLibraryModel.Entry
    let document: MeetingDocument

    @State private var draft = ""
    @FocusState private var editing: Bool
    @State private var isHoveringTitle = false

    private var url: URL { entry.id }
    private var isSummarizing: Bool { summaries.state(for: url) == .summarizing }
    private var currentTemplate: MeetingTemplate {
        MeetingTemplate.resolving(
            document.header.template ?? state.coordinator.rewriteSettings.defaultTemplateID)
    }

    var body: some View {
        titleBlock
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, MW.s24)
            .padding(.top, MW.s12)
            .padding(.bottom, MW.s16)
            .toolbar {
                ToolbarItem(placement: .primaryAction) { templateMenu }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        state.summarize(url, templateID: currentTemplate.id)
                    } label: {
                        Label("Write the Notes Again", systemImage: "arrow.clockwise")
                    }
                    .disabled(isSummarizing || !document.hasWords)
                    .help("Write the notes again")
                    copyMenu
                    Button {
                        state.revealInFinder(url)
                    } label: {
                        Label("Show in Finder", systemImage: "folder")
                    }
                    .help("Show in Finder")
                }
                ToolbarItem(placement: .primaryAction) { moreMenu }
            }
            .onAppear {
                draft = entry.title
                takeRenameRequest()
            }
            .onChange(of: entry.title) { _, title in
                if !editing { draft = title }
            }
            .onChange(of: state.renameRequest) { _, _ in takeRenameRequest() }
            .onChange(of: editing) { _, isEditing in
                if !isEditing { commit() }
            }
    }

    private func takeRenameRequest() {
        guard state.renameRequest == url else { return }
        state.renameRequest = nil
        editing = true
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Name this meeting", text: $draft)
                .textFieldStyle(.plain)
                .font(.title2.weight(.bold))
                .focused($editing)
                .onSubmit { commit(); editing = false }
                .onExitCommand { draft = entry.title; editing = false }
                .padding(.horizontal, 6)
                .frame(height: 32)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.primary.opacity(editing ? 0.07 : (isHoveringTitle ? 0.04 : 0)))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(AppLook.accent.opacity(editing ? 0.6 : 0), lineWidth: 2)
                }
                .onHover { isHoveringTitle = $0 }
                .help("Click to rename")
                // the field sits 6pt in so its text lines up with the line below.
                .padding(.leading, -6)
            Text(meta)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .animation(.easeOut(duration: 0.12), value: isHoveringTitle)
        .animation(.easeOut(duration: 0.15), value: editing)
    }

    private func commit() {
        let name = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name != entry.title else { return }
        Task {
            await library.rename(url, to: name)
            draft = entry.title
        }
    }

    /// `Thu 16 Oct · 09:30 · 42m · 3 speakers · 2 sessions`
    private var meta: String {
        let started = document.header.started
        var parts = ["\(MW.date(started, "EEE d MMM")) · \(MW.date(started, "jmm"))"]
        parts.append(document.header.duration.spoken)
        let speakers = document.speakers.count
        if speakers > 0 { parts.append(speakers == 1 ? "1 speaker" : "\(speakers) speakers") }
        if document.sessions.count > 1 { parts.append("\(document.sessions.count) sessions") }
        return parts.joined(separator: " · ")
    }

    // MARK: menus

    private var templateMenu: some View {
        Menu {
            // a button, not a picker: choosing the shape the notes already
            // have writes them again in it.
            ForEach(MeetingTemplate.builtIn) { template in
                Button {
                    state.summarize(url, templateID: template.id)
                } label: {
                    if template.id == currentTemplate.id {
                        Label(MW.capitalized(template.name), systemImage: "checkmark")
                    } else {
                        Text(MW.capitalized(template.name))
                    }
                }
            }
        } label: {
            Label(MW.capitalized(currentTemplate.name), systemImage: currentTemplate.symbol)
                .labelStyle(.titleAndIcon)
        }
        .disabled(isSummarizing || !document.hasWords)
        .help("The shape of the notes")
    }

    private var copyMenu: some View {
        Menu {
            Button("Copy Summary") { MW.copy(MeetingsLibraryModel.text(.summary, of: document)) }
                .disabled(document.summary == nil)
            Button("Copy Transcript") { MW.copy(MeetingsLibraryModel.text(.transcript, of: document)) }
                .disabled(!document.hasWords)
            Button("Copy Both") { MW.copy(MeetingsLibraryModel.text(.both, of: document)) }
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }
        .help("Copy")
    }

    private var moreMenu: some View {
        Menu {
            Button("Rename") { editing = true }
            Button("Record into This Meeting") { state.record(into: url) }
                .disabled(state.isBusy)
            Divider()
            Button("Delete…", role: .destructive) { state.pendingDelete = url }
        } label: {
            Label("More", systemImage: "ellipsis")
        }
        .help("More")
    }
}
