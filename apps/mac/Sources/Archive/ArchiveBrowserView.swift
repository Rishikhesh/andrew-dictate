import AppKit
import SwiftUI

/// history: what it kept, and the only place to delete one of them.
struct ArchiveBrowserView: View {
    @ObservedObject var viewModel: ArchiveBrowserViewModel
    let fixAWord: (String) -> Void

    /// one dictation at a time, and only after asking: a mis-click on a
    /// row should never cost something you said.
    @State private var pendingDelete: Dictation?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let failure = viewModel.failure {
                VStack(alignment: .leading, spacing: 3) {
                    Text(failure.capitalizedFirst)
                        .foregroundStyle(.red)
                    // somewhere to go: the file it could not read.
                    Text(viewModel.archivePath)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .font(.caption)
                .padding(.horizontal, 18)
                .padding(.top, 14)
            }

            if viewModel.filtered.isEmpty {
                // a failure already says why there is nothing to show; saying
                // "nothing kept yet." under it would be a second answer, and
                // the wrong one — an unreadable archive is not an empty one.
                if viewModel.failure == nil {
                    // and a search that found nothing is not an empty archive
                    // either.
                    Text(
                        viewModel.isSearching
                            ? "Nothing matches “\(viewModel.trimmedQuery)”."
                            : "Nothing kept yet."
                    )
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(viewModel.filtered) { item in
                            ArchiveRow(
                                dictation: item,
                                query: viewModel.trimmedQuery,
                                fixAWord: { fixAWord(item.heard) },
                                delete: { pendingDelete = item }
                            )
                            Divider()
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { viewModel.reload() }
        .confirmationDialog(
            "Delete this dictation?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { dictation in
            Button("Delete", role: .destructive) {
                viewModel.delete(dictation)
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: { _ in
            Text("This can’t be undone.")
        }
    }
}

private struct ArchiveRow: View {
    let dictation: Dictation
    /// what the search field holds, already trimmed. empty when no search is
    /// on, which is most of the time.
    let query: String
    let fixAWord: () -> Void
    let delete: () -> Void


    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(highlighted(dictation.inserted))
                    .lineLimit(3)
                    .textSelection(.enabled)

                HStack(spacing: 8) {
                    Text(
                        dictation.startedAt.formatted(
                            date: .abbreviated,
                            time: .shortened
                        )
                    )
                    // The raw text is only worth showing when the cleaner
                    // changed something; otherwise it is the same line twice.
                    // While a search is on it is always shown, and shown
                    // longer: the word being hunted for often lives only here.
                    if isSearching || dictation.heard != dictation.inserted {
                        Text(heardLine)
                            .lineLimit(isSearching ? 2 : 1)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
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
        .contextMenu { actions }
    }

    @ViewBuilder
    private var actions: some View {
        Button("Copy", action: copy)
        Button("Fix a Word…", action: fixAWord)
        Divider()
        Button("Delete…", role: .destructive, action: delete)
    }

    private var isSearching: Bool { !query.isEmpty }

    private var heardLine: AttributedString {
        var line = AttributedString("Heard “")
        line += highlighted(dictation.heard)
        line += AttributedString("”")
        return line
    }

    /// the matched run in gold: a hit you still have to hunt for on the line
    /// is not much of a hit. matched the way the filter matches — case- and
    /// diacritic-insensitive — or the highlight would miss what the list found.
    private func highlighted(_ text: String) -> AttributedString {
        var out = AttributedString(text)
        guard isSearching else { return out }

        var from = text.startIndex
        while let found = text.range(
            of: query,
            options: [.caseInsensitive, .diacriticInsensitive],
            range: from..<text.endIndex
        ) {
            if let lower = AttributedString.Index(found.lowerBound, within: out),
               let upper = AttributedString.Index(found.upperBound, within: out) {
                out[lower..<upper].mergeAttributes(Self.ink(SystemAccent.color))
            }
            from = found.upperBound
        }
        return out
    }

    // typed subscript rather than a key path: the key-path spelling trips a
    // non-Sendable warning under strict concurrency (as in PipelineView).
    private static func ink(_ color: Color) -> AttributeContainer {
        var container = AttributeContainer()
        container[
            AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self
        ] = color
        return container
    }

    /// the archive keeping ADR 0030's promise: "wanting it again is what the
    /// archive is for". the inserted text is the paragraph that went into the
    /// wrong window, so that is the one that comes back — the raw text is what
    /// `fix a word` already carries.
    private func copy() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(dictation.inserted, forType: .string)
    }
}

