import Charts
import SwiftUI

/// the window opens here: anything wrong with setup first, then your
/// numbers at a glance, the week, and what you said last.
struct HomePane: View {
    let stats: DashboardStats
    let issues: [SetupIssue]
    let modelLine: String
    let onFinishSetup: () -> Void
    let onShowHistory: () -> Void

    var body: some View {
        Form {
            if !issues.isEmpty {
                Section {
                    ForEach(issues) { issue in
                        LabeledContent {
                            EmptyView()
                        } label: {
                            Text(issue.title.capitalizedFirst)
                                .foregroundStyle(.red)
                            Text(issue.detail.capitalizedFirst)
                        }
                    }
                    HStack {
                        Spacer()
                        Button("Finish Setup…", action: onFinishSetup)
                            .buttonStyle(.borderedProminent)
                    }
                } header: {
                    Text("Needs attention")
                }
            }

            Section {
                Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                    GridRow {
                        tile("Words dictated", stats.totalWords.formatted(), "all time")
                        tile(
                            "Today",
                            stats.todayWords.map { $0.formatted() } ?? "—",
                            stats.todayWords == nil ? "keeping is off" : "words"
                        )
                        tile("Typical paste", stats.typicalPaste, "from key up to text")
                        tile("Slowest 1 in 20", stats.slowestPaste, sampleLine)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Last 7 days") {
                if let note = stats.chartNote {
                    Text(note)
                        .foregroundStyle(.secondary)
                } else {
                    Chart(stats.lastSevenDays, id: \.day) { day in
                        BarMark(
                            x: .value("Day", day.day, unit: .day),
                            y: .value("Words", day.words)
                        )
                        .foregroundStyle(day.isToday ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
                        .cornerRadius(4)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { _ in
                            AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                        }
                    }
                    .chartYAxis(.hidden)
                    .frame(height: 110)
                    .accessibilityLabel("Words dictated each day for the last seven days")
                }
            }

            Section {
                if stats.recent.isEmpty {
                    Text("Nothing kept yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(stats.recent) { dictation in
                        LabeledContent {
                            Text(dictation.startedAt, format: .relative(presentation: .named))
                                .foregroundStyle(.secondary)
                        } label: {
                            Text(dictation.inserted)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                }
            } header: {
                Text("Recent")
            } footer: {
                HStack {
                    Text(modelLine)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Show All in History", action: onShowHistory)
                }
            }
        }
        .formStyle(.grouped)
    }

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
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
