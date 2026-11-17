import Foundation

/// what Home shows, worked out from what the app already keeps: the words
/// counter, the archive of kept dictations, and the paste timings. nothing
/// here is estimated; a number that is not known reads as such.
struct DashboardStats: Equatable {
    struct DayWords: Equatable {
        let day: Date
        let words: Int
        let isToday: Bool
    }

    let totalWords: Int
    /// nil when dictations are not kept: today cannot be counted then.
    let todayWords: Int?
    /// the last seven calendar days, oldest first, empty days at zero.
    let lastSevenDays: [DayWords]
    /// at most three, newest first.
    let recent: [Dictation]
    let typicalPaste: String
    let slowestPaste: String
    let pasteSample: Int
    /// no kept dictation to count from, whether keeping is off or new.
    let keptNothing: Bool

    static func make(
        dictations: [Dictation],
        totalWords: Int,
        typicalPaste: Duration?,
        slowestPaste: Duration?,
        pasteSample: Int,
        keepsDictations: Bool,
        now: Date,
        calendar: Calendar
    ) -> DashboardStats {
        let today = calendar.startOfDay(for: now)
        var byDay: [Date: Int] = [:]
        for dictation in dictations {
            byDay[calendar.startOfDay(for: dictation.startedAt), default: 0] += words(in: dictation.inserted)
        }
        let week = (0..<7).reversed().compactMap { back -> DayWords? in
            guard let day = calendar.date(byAdding: .day, value: -back, to: today) else {
                return nil
            }
            return DayWords(day: day, words: byDay[day] ?? 0, isToday: back == 0)
        }
        return DashboardStats(
            totalWords: totalWords,
            todayWords: keepsDictations ? (byDay[today] ?? 0) : nil,
            lastSevenDays: week,
            recent: Array(dictations.sorted { $0.startedAt > $1.startedAt }.prefix(3)),
            typicalPaste: milliseconds(typicalPaste),
            slowestPaste: milliseconds(slowestPaste),
            pasteSample: pasteSample,
            keptNothing: dictations.isEmpty
        )
    }

    static func words(in text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }

    static func milliseconds(_ duration: Duration?) -> String {
        guard let duration else {
            return "—"
        }
        let (seconds, attoseconds) = duration.components
        let ms = Double(seconds) * 1_000 + Double(attoseconds) / 1e15
        return "\(Int(ms.rounded())) ms"
    }
}
