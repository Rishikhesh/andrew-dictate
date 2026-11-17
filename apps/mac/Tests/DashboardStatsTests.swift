import XCTest

/// Home's numbers: only what the app already keeps, never invented.
final class DashboardStatsTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        return c
    }()

    /// 2026-11-17 15:00 in Kolkata.
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 17, hour: 15))! }

    private func dictation(_ text: String, daysAgo: Int, hour: Int = 10, minute: Int = 0) -> Dictation {
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now))!
        let at = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
        return Dictation(startedAt: at, heard: text, inserted: text, engine: "test")
    }

    private func make(_ dictations: [Dictation], keeps: Bool = true, typical: Duration? = nil, slowest: Duration? = nil, sample: Int = 0) -> DashboardStats {
        DashboardStats.make(
            dictations: dictations, totalWords: 48_210,
            typicalPaste: typical, slowestPaste: slowest, pasteSample: sample,
            keepsDictations: keeps, now: now, calendar: calendar
        )
    }

    func testTodayAndWeekCountKeptWords() {
        let stats = make([
            dictation("one two three", daysAgo: 0),
            dictation("four five", daysAgo: 0, hour: 9),
            dictation("six", daysAgo: 2),
            dictation("seven eight nine ten", daysAgo: 8),
        ])
        XCTAssertEqual(stats.totalWords, 48_210)
        XCTAssertEqual(stats.todayWords, 5)
        XCTAssertEqual(stats.lastSevenDays.count, 7)
        XCTAssertEqual(stats.lastSevenDays.last?.words, 5)
        XCTAssertEqual(stats.lastSevenDays.last?.isToday, true)
        XCTAssertEqual(stats.lastSevenDays[4].words, 1, "two days ago")
        XCTAssertEqual(stats.lastSevenDays.map(\.words).reduce(0, +), 6, "eight days ago is outside the week")
    }

    func testEmptyDaysAreZero() {
        let stats = make([dictation("hello there", daysAgo: 0)])
        XCTAssertEqual(stats.lastSevenDays.map(\.words), [0, 0, 0, 0, 0, 0, 2])
        XCTAssertEqual(stats.lastSevenDays.filter(\.isToday).count, 1)
    }

    func testRecentIsNewestThree() {
        let a = dictation("a", daysAgo: 3), b = dictation("b", daysAgo: 0, hour: 8)
        let c = dictation("c", daysAgo: 0, hour: 12), d = dictation("d", daysAgo: 1)
        XCTAssertEqual(make([a, b, c, d]).recent.map(\.inserted), ["c", "b", "d"])
    }

    func testNoTimingsShowDash() {
        let stats = make([])
        XCTAssertEqual(stats.typicalPaste, "—")
        XCTAssertEqual(stats.slowestPaste, "—")
        XCTAssertEqual(stats.pasteSample, 0)
    }

    func testTimingsFormatInMilliseconds() {
        let stats = make([], typical: .milliseconds(211.6), slowest: .seconds(0.54), sample: 312)
        XCTAssertEqual(stats.typicalPaste, "212 ms")
        XCTAssertEqual(stats.slowestPaste, "540 ms")
        XCTAssertEqual(stats.pasteSample, 312)
    }

    func testNothingKeptSaysSo() {
        let stats = make([], keeps: false)
        XCTAssertNil(stats.todayWords)
        XCTAssertTrue(stats.keptNothing)
        XCTAssertTrue(make([], keeps: true).keptNothing, "keeping on but nothing yet is still nothing kept")
        XCTAssertFalse(make([dictation("x", daysAgo: 0)]).keptNothing)
    }

    func testDaysFollowTheLocalCalendar() {
        // 23:50 local yesterday is yesterday here, though in UTC it is the
        // same day as this afternoon.
        let stats = make([dictation("late night", daysAgo: 1, hour: 23, minute: 50), dictation("now", daysAgo: 0)])
        XCTAssertEqual(stats.todayWords, 1)
        XCTAssertEqual(stats.lastSevenDays[5].words, 2)
    }
}
