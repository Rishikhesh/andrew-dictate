import SwiftUI
import ThinkingOrbsKit

/// the window opens here: anything wrong with setup first, then today with
/// your orb and the week under it, the numbers at a glance, and what you
/// said last.
struct HomePane: View {
    let stats: DashboardStats
    let orb: ListeningOrb
    let issues: [SetupIssue]
    let modelLine: String
    let onFinishSetup: () -> Void
    let onShowHistory: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SectionHero(.home)
                    .padding(.bottom, 12)

                if !issues.isEmpty {
                    issueBanner
                        .padding(.bottom, 16)
                }

                todayCard

                HStack(spacing: 12) {
                    tile("All time", stats.totalWords.formatted(), "words dictated")
                    tile("Typical paste", stats.typicalPaste, "from key up to text")
                    tile("Slowest 1 in 20", stats.slowestPaste, sampleLine)
                }
                .padding(.top, 12)

                Text("Recent")
                    .font(.headline)
                    .padding(.horizontal, 4)
                    .padding(.top, 26)
                    .padding(.bottom, 8)
                recentGroup

                Text(modelLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.top, 8)
            }
            .frame(maxWidth: SettingsLayout.column)
            .padding(.horizontal, 28)
            .padding(.top, 6)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - setup

    private var issueBanner: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(issues) { issue in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(issue.title.capitalizedFirst)
                            .fontWeight(.semibold)
                            .foregroundStyle(.red)
                        Text(issue.detail.capitalizedFirst)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("Finish Setup…", action: onFinishSetup)
                .buttonStyle(.glassProminent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Needs attention")
    }

    // MARK: - today

    private var todayCard: some View {
        HStack(spacing: 22) {
            ThinkingOrb(
                state: OrbState(rawValue: orb.rawValue) ?? .composing,
                theme: .auto,
                displaySize: 96
            )
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                Text("Today")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                // with nothing to count from, say so: zeros here would be
                // a number pretending to be data.
                if let note = stats.chartNote {
                    Text(note)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)
                } else {
                    Text((stats.todayWords ?? 0).formatted())
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .tracking(-1.2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .contentTransition(.numericText())
                    Text(todayLine)
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                    SparkStrip(days: stats.lastSevenDays)
                        .padding(.top, 12)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 22)
        .padding(.horizontal, 24)
        .background {
            // the accent, lit softly from the top-left corner.
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    EllipticalGradient(
                        colors: [AppLook.accent.opacity(0.24), .clear],
                        center: .topLeading,
                        startRadiusFraction: 0,
                        endRadiusFraction: 0.75
                    )
                )
        }
        .glassModule(cornerRadius: 16)
        .accessibilityElement(children: .combine)
    }

    private var todayLine: String {
        let words = stats.todayWords == 1 ? "word" : "words"
        let count = stats.todayCount ?? 0
        return "\(words), across \(count.formatted()) \(count == 1 ? "dictation" : "dictations")"
    }

    // MARK: - numbers

    private var sampleLine: String {
        switch stats.pasteSample {
        case 0: "none measured yet"
        case 1: "over 1 paste"
        default: "over \(stats.pasteSample.formatted()) pastes"
        }
    }

    private func tile(_ label: String, _ value: String, _ caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(caption)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .glassModule(cornerRadius: 12)
        .accessibilityElement(children: .combine)
    }

    // MARK: - recent

    private var recentGroup: some View {
        VStack(spacing: 0) {
            if stats.recent.isEmpty {
                row {
                    Text("Nothing kept yet.")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                Divider().padding(.leading, 14)
            } else {
                ForEach(stats.recent) { dictation in
                    row {
                        Text(dictation.inserted.capitalizedFirst)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer(minLength: 12)
                        Text(when(dictation.startedAt))
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                    Divider().padding(.leading, 14)
                }
            }
            row {
                Spacer()
                Button("Show All in History", action: onShowHistory)
                    .buttonStyle(.glass)
            }
        }
        .glassModule(cornerRadius: 12)
    }

    private func row(@ViewBuilder _ content: () -> some View) -> some View {
        HStack(spacing: 14, content: content)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .frame(minHeight: 44)
    }

    /// today reads as a time, any other day as its date.
    private func when(_ date: Date) -> String {
        Calendar.current.isDateInToday(date)
            ? date.formatted(date: .omitted, time: .shortened)
            : date.formatted(.dateTime.month(.abbreviated).day())
    }
}

/// the week as seven small bars, today in the accent. they grow into place
/// one after another when the card appears, and simply stand there with
/// Reduce Motion.
private struct SparkStrip: View {
    let days: [DashboardStats.DayWords]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var grown = false

    private let height: CGFloat = 38

    var body: some View {
        let most = max(days.map(\.words).max() ?? 0, 1)
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(Array(days.enumerated()), id: \.element.day) { index, day in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(day.isToday ? AnyShapeStyle(AppLook.accent) : AnyShapeStyle(.quaternary))
                    .frame(maxWidth: 22)
                    // an empty day keeps a sliver, so the week still reads as seven.
                    .frame(height: max(3, height * CGFloat(day.words) / CGFloat(most)))
                    .scaleEffect(x: 1, y: grown ? 1 : 0.2, anchor: .bottom)
                    .opacity(grown ? 1 : 0)
                    .animation(
                        reduceMotion
                            ? nil
                            : .timingCurve(0.23, 1, 0.32, 1, duration: 0.3).delay(Double(index) * 0.04),
                        value: grown
                    )
                    .help("\(day.day.formatted(.dateTime.weekday(.wide))): \(day.words.formatted()) words")
            }
        }
        .frame(height: height, alignment: .bottom)
        .onAppear { grown = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Words each day, the last seven days")
        .accessibilityValue(
            days.map { "\($0.day.formatted(.dateTime.weekday(.wide))) \($0.words)" }
                .joined(separator: ", ")
        )
    }
}
