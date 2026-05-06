import XCTest
@testable import JLPTDeck

final class RetentionStatsTests: XCTestCase {
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func date(_ s: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: s) ?? f.date(from: s + ".000Z")!
    }

    private func day(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = hour
        return calendar.date(from: comps)!
    }

    func test_emptyEvents_returnsAllNil() {
        let snap = RetentionStats.snapshot(
            eventDates: [], now: day(2026, 5, 6), calendar: calendar
        )
        XCTAssertNil(snap.installDate)
        XCTAssertEqual(snap.totalOpenDays, 0)
        XCTAssertNil(snap.d1Retained)
        XCTAssertNil(snap.d7Retained)
        XCTAssertNil(snap.lastOpenDate)
    }

    func test_singleEventToday_d1d7AreNil() {
        let today = day(2026, 5, 6)
        let snap = RetentionStats.snapshot(
            eventDates: [today], now: today, calendar: calendar
        )
        XCTAssertNotNil(snap.installDate)
        XCTAssertEqual(snap.totalOpenDays, 1)
        XCTAssertNil(snap.d1Retained, "D1 unknown until tomorrow")
        XCTAssertNil(snap.d7Retained, "D7 unknown until day 7")
    }

    func test_d1Retained_true_whenOpenedNextDay() {
        let install = day(2026, 5, 1)
        let nextDay = day(2026, 5, 2)
        let snap = RetentionStats.snapshot(
            eventDates: [install, nextDay],
            now: day(2026, 5, 3), calendar: calendar
        )
        XCTAssertEqual(snap.d1Retained, true)
        XCTAssertNil(snap.d7Retained)
    }

    func test_d1Retained_false_whenNotOpenedNextDay() {
        let install = day(2026, 5, 1)
        let snap = RetentionStats.snapshot(
            eventDates: [install],
            now: day(2026, 5, 3), calendar: calendar
        )
        XCTAssertEqual(snap.d1Retained, false)
    }

    func test_d7Retained_true_whenOpenedAnytimeInWindow() {
        let install = day(2026, 5, 1)
        let day5 = day(2026, 5, 5)
        let snap = RetentionStats.snapshot(
            eventDates: [install, day5],
            now: day(2026, 5, 9), calendar: calendar
        )
        XCTAssertEqual(snap.d7Retained, true)
    }

    func test_d7Retained_false_whenNoEventsInWindow() {
        let install = day(2026, 5, 1)
        // Skip days 2..7 entirely; next event is day 9 (after window).
        let snap = RetentionStats.snapshot(
            eventDates: [install, day(2026, 5, 9)],
            now: day(2026, 5, 10), calendar: calendar
        )
        XCTAssertEqual(snap.d7Retained, false)
    }

    func test_totalOpenDays_dedupsSameDay() {
        let install = day(2026, 5, 1, hour: 9)
        let install2 = day(2026, 5, 1, hour: 21)   // same calendar day
        let day2 = day(2026, 5, 2, hour: 9)
        let snap = RetentionStats.snapshot(
            eventDates: [install, install2, day2],
            now: day(2026, 5, 3), calendar: calendar
        )
        XCTAssertEqual(snap.totalOpenDays, 2, "same-day events count once")
    }

    func test_lastOpenDate_isMaximum() {
        let dates = [day(2026, 5, 1), day(2026, 5, 5), day(2026, 5, 3)]
        let snap = RetentionStats.snapshot(
            eventDates: dates, now: day(2026, 5, 10), calendar: calendar
        )
        XCTAssertEqual(snap.lastOpenDate, day(2026, 5, 5))
    }

    func test_featureFlagDefaultOn() {
        XCTAssertTrue(FeatureFlags.eventCounter)
    }
}
