import AppKit
import SwiftUI

/// the meetings half of history. the same row idiom as dictations: the facts
/// on the left, and on hover the three things you came for — open, show in
/// finder, delete. a double-click on the row opens it too, the way every other
/// mac list of documents behaves.
struct MeetingsBrowserView: View {
    @ObservedObject var viewModel: MeetingsListModel

    /// a meeting is other people's words too: deleting one asks first.
    @State private var pendingDelete: MeetingSummary?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let failure = viewModel.failure {
                Text(failure)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
            }

            // kept, not deleted, and not retried on its own — so this is the
            // only place it exists as far as anyone can tell, and the only
            // place to ask for another try.
            if viewModel.setAsideCount > 0, let folder = viewModel.setAsideFolder {
                HStack(spacing: 8) {
                    Text(setAsideSentence)
                                    .foregroundStyle(.red)

                    if viewModel.canTryAgain {
                        Button("Try Again") {
                            Task { await viewModel.tryAgain() }
                        }
                        .font(.caption)
                        .disabled(viewModel.tryingAgain)
                    }

                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([folder])
                    }
                    .font(.caption)
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
            }

            if viewModel.filtered.isEmpty {
                // a search that found nothing is not an empty folder, and
                // must not read like one.
                Text(
                    viewModel.isSearching
                        ? "nothing matches “\(viewModel.trimmedQuery)”."
                        : "no meetings yet."
                )
                    .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(viewModel.filtered) { meeting in
                            MeetingRow(
                                meeting: meeting,
                                audioNote: viewModel.audioNote(for: meeting),
                                again: viewModel.again(for: meeting),
                                transcribeAgain: { viewModel.transcribeAgain(meeting, with: $0) },
                                deleteAudio: { viewModel.deleteAudio(of: meeting) },
                                delete: { pendingDelete = meeting }
                            )
                            Divider()
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .confirmationDialog(
            "Delete this meeting?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { meeting in
            Button("Delete", role: .destructive) {
                viewModel.delete(meeting)
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: { _ in
            Text("The transcript moves to the Trash. Any kept audio is deleted.")
        }
    }

    /// what the line says: how many, or that they are being tried.
    private var setAsideSentence: String {
        if viewModel.tryingAgain {
            return "Trying again…"
        }
        return viewModel.setAsideCount == 1
            ? "1 recording couldn’t be transcribed"
            : "\(viewModel.setAsideCount) recordings couldn’t be transcribed"
    }
}

private struct MeetingRow: View {
    let meeting: MeetingSummary
    /// `audio until fri 14:02`, `audio kept`, or nil when there is none.
    let audioNote: String?
    /// `transcribe again with ▸`, or why it is off, or that it is running.
    let again: MeetingsListModel.Again
    let transcribeAgain: (SpeechModel) -> Void
    let deleteAudio: () -> Void
    let delete: () -> Void


    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            HStack(spacing: 8) {
                Text(
                    meeting.started.formatted(
                        date: .abbreviated,
                        time: .shortened
                    )
                )

                separator
                Text(meeting.app)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                separator
                Text(meeting.duration.spoken)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)

                separator
                Text(completeness.text)
                    .foregroundStyle(completeness.tint)

                // the audio is on this mac for a while yet: said on the
                // row, so nobody has to go looking to know it is there.
                if let audioNote {
                    separator
                    Text(audioNote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                // a rerun takes minutes, and nothing else on the row says
                // it is happening.
                if again == .running {
                    separator
                    Text("Transcribing again…")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            // every action in sight: the menu, and the same on right-click.
            Menu {
                actions
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("Actions")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: open)
        .contextMenu { actions }
    }

    @ViewBuilder
    private var actions: some View {
        Button("Open", action: open)
        Button("Show in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([meeting.fileURL])
        }
        againAction
        if audioNote != nil {
            Button("Delete Audio Now", action: deleteAudio)
        }
        Divider()
        Button("Delete…", role: .destructive, action: delete)
    }

    /// while the audio is kept, the models to read it again with. off, it
    /// says why beside itself, so the row never has a dead button.
    @ViewBuilder
    private var againAction: some View {
        switch again {
        case .none:
            EmptyView()
        case .offer(let models):
            Menu("Transcribe Again With") {
                ForEach(models, id: \.self) { model in
                    Button(model.shortName.capitalizedFirst) { transcribeAgain(model) }
                }
            }
        case .wait(let why):
            Button("Transcribe Again: \(why.capitalizedFirst)") {}
                .disabled(true)
        case .running:
            Button("Transcribing Again…") {}
                .disabled(true)
        }
    }

    /// the file *is* the artifact (ADR 0040), so this hands it to whatever
    /// markdown app the user already has — there is no reader of our own to
    /// keep. a file renamed since the folder was read reveals where it was,
    /// rather than being a click that does nothing.
    private func open() {
        guard !NSWorkspace.shared.open(meeting.fileURL) else { return }

        let stillThere = FileManager.default.fileExists(
            atPath: meeting.fileURL.path(percentEncoded: false)
        )
        NSWorkspace.shared.activateFileViewerSelecting([
            stillThere
                ? meeting.fileURL
                : meeting.fileURL.deletingLastPathComponent()
        ])
    }

    private var separator: some View {
        Text("·")
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
    }

    /// SPEC §4 for recordings: one with holes in it is never handed back
    /// looking whole, so anything short of complete is drawn in attention.
    private var completeness: (text: String, tint: Color) {
        if meeting.recovered {
            return ("Recovered", .red)
        }
        if meeting.gapCount > 0 {
            return (
                meeting.gapCount == 1 ? "1 gap" : "\(meeting.gapCount) gaps",
                .red
            )
        }
        if !meeting.complete {
            return ("Incomplete", .red)
        }
        return ("Complete", .secondary)
    }
}

#Preview("meetings") {
    MeetingsBrowserView(
        viewModel: MeetingsListModel {
            [
                MeetingSummary(
                    fileURL: URL(
                        fileURLWithPath:
                            "/tmp/2026-08-29-1402-zoom.md"
                    ),
                    app: "zoom",
                    started: .now,
                    duration: .seconds(6120),
                    complete: true,
                    gapCount: 0,
                    recovered: false
                ),
                MeetingSummary(
                    fileURL: URL(
                        fileURLWithPath:
                            "/tmp/2026-08-28-0930-chrome.md"
                    ),
                    app: "chrome",
                    started: .now.addingTimeInterval(-90000),
                    duration: .seconds(720),
                    complete: false,
                    gapCount: 2,
                    recovered: false
                ),
            ]
        }
    )
    .frame(width: 800, height: 330)
    .background(BrandUI.windowBg)
    .font(BrandUI.bodyFont)
    .brandTinted()
    .controlSize(.small)
    .preferredColorScheme(.dark)
}
