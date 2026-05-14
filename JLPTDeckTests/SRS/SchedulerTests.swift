import XCTest
@testable import JLPTDeck

final class SchedulerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func dueSnapshot(id: UUID = UUID(), offset: TimeInterval) -> SRSSnapshot {
        SRSSnapshot(
            cardID: id,
            ease: 2.5,
            intervalDays: 1,
            reps: 1,
            lapses: 0,
            lastReview: now,
            dueDate: now.addingTimeInterval(offset)
        )
    }

    // 1. limit=10, 15 due -> returns 10 in dueDate-ascending order.
    func testReturnsUpToLimitFromDueSorted() {
        // Create 15 due cards with increasing staleness (most overdue first).
        let snaps: [SRSSnapshot] = (0..<15).map { i in
            dueSnapshot(offset: -TimeInterval(i * 60))
        }
        // Shuffle input to ensure the scheduler sorts.
        let shuffled = snaps.shuffled()
        let picked = CardScheduler.pickToday(
            due: shuffled, newCardIDs: [], limit: 10, now: now
        )
        XCTAssertEqual(picked.count, 10)

        // Expected order: most negative offset first (i=14 down to i=5).
        let expected = snaps.sorted { $0.dueDate < $1.dueDate }
            .prefix(10)
            .map { $0.cardID }
        XCTAssertEqual(picked, Array(expected))
    }

    // 2. limit=10, 3 due + 20 new -> 3 due then 7 new (order preserved).
    func testFillsWithNewCardsWhenDueIsShort() {
        let due: [SRSSnapshot] = (0..<3).map { i in
            dueSnapshot(offset: -TimeInterval((i + 1) * 60))
        }
        let newIDs: [UUID] = (0..<20).map { _ in UUID() }
        let picked = CardScheduler.pickToday(
            due: due, newCardIDs: newIDs, limit: 10, now: now
        )
        XCTAssertEqual(picked.count, 10)

        let expectedDuePrefix = due.sorted { $0.dueDate < $1.dueDate }.map { $0.cardID }
        XCTAssertEqual(Array(picked.prefix(3)), expectedDuePrefix)
        XCTAssertEqual(Array(picked.suffix(7)), Array(newIDs.prefix(7)))
    }

    // 3. 0 due + 5 new -> 5 new, no padding.
    func testZeroDueReturnsNewWithoutPadding() {
        let newIDs: [UUID] = (0..<5).map { _ in UUID() }
        let picked = CardScheduler.pickToday(
            due: [], newCardIDs: newIDs, limit: 10, now: now
        )
        XCTAssertEqual(picked, newIDs)
    }

    // 4. limit=0 -> empty.
    func testZeroLimitReturnsEmpty() {
        let due = [dueSnapshot(offset: -60)]
        let newIDs = [UUID()]
        let picked = CardScheduler.pickToday(
            due: due, newCardIDs: newIDs, limit: 0, now: now
        )
        XCTAssertTrue(picked.isEmpty)
    }

    // 5. Future-dated cards are excluded.
    func testFutureCardsAreExcluded() {
        let pastID = UUID()
        let futureID = UUID()
        let due = [
            dueSnapshot(id: pastID, offset: -120),   // eligible
            dueSnapshot(id: futureID, offset: +3600) // not yet due
        ]
        let newID = UUID()
        let picked = CardScheduler.pickToday(
            due: due, newCardIDs: [newID], limit: 10, now: now
        )
        XCTAssertEqual(picked, [pastID, newID])
        XCTAssertFalse(picked.contains(futureID))
    }

    // MARK: - Daily-limit cap (bug fix)

    // The daily limit MUST be a calendar-day cap. If the user already
    // reviewed N cards today, a second session on the same day must
    // pick at most (limit - N) new cards — not another full batch of
    // `limit`.
    func testAlreadyReviewedTodaySubtractsFromQuota() {
        // 20 new cards available, limit=20, already-reviewed=20 → 0 picks.
        let newIDs = (0..<20).map { _ in UUID() }
        let picked = CardScheduler.pickToday(
            due: [], newCardIDs: newIDs, limit: 20, now: now,
            alreadyReviewedToday: 20
        )
        XCTAssertEqual(picked.count, 0,
                       "Daily quota already hit → no new picks even if pool is non-empty")
    }

    func testPartialQuotaUsedSoFar() {
        // 12 already done, limit=20 → 8 remaining.
        let newIDs = (0..<50).map { _ in UUID() }
        let picked = CardScheduler.pickToday(
            due: [], newCardIDs: newIDs, limit: 20, now: now,
            alreadyReviewedToday: 12
        )
        XCTAssertEqual(picked.count, 8)
    }

    func testAlreadyReviewedExceedsLimitClampsAtZero() {
        // Defensive: if for some reason `alreadyReviewedToday` > limit
        // (e.g., user lowered dailyLimit mid-day), we clamp to 0, not
        // a negative slice.
        let newIDs = (0..<5).map { _ in UUID() }
        let picked = CardScheduler.pickToday(
            due: [], newCardIDs: newIDs, limit: 10, now: now,
            alreadyReviewedToday: 99
        )
        XCTAssertEqual(picked.count, 0)
    }

    func testReviewedTodayCount_sameCalendarDay_isCounted() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let states = [
            dueSnapshot(offset: 86_400),             // lastReview = `now` (today)
            dueSnapshot(offset: 86_400),             // same
        ]
        let count = CardScheduler.reviewedTodayCount(
            states: states, now: today.addingTimeInterval(3600), calendar: cal
        )
        XCTAssertEqual(count, 2)
    }

    func testReviewedTodayCount_yesterday_isNotCounted() {
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: now)!
        let snap = SRSSnapshot(
            cardID: UUID(), ease: 2.5, intervalDays: 1, reps: 1, lapses: 0,
            lastReview: yesterday,
            dueDate: now.addingTimeInterval(86_400)
        )
        let count = CardScheduler.reviewedTodayCount(
            states: [snap], now: now, calendar: cal
        )
        XCTAssertEqual(count, 0)
    }

    func testReviewedTodayCount_nilLastReview_isNotCounted() {
        let snap = SRSSnapshot(
            cardID: UUID(), ease: 2.5, intervalDays: 0, reps: 0, lapses: 0,
            lastReview: nil,
            dueDate: now
        )
        let count = CardScheduler.reviewedTodayCount(
            states: [snap], now: now
        )
        XCTAssertEqual(count, 0)
    }

    // Default arg backward-compat: existing call sites without
    // `alreadyReviewedToday:` continue to behave as before (no cap).
    func testDefaultArgBackwardCompat() {
        let newIDs = (0..<5).map { _ in UUID() }
        let pickedNoArg = CardScheduler.pickToday(
            due: [], newCardIDs: newIDs, limit: 5, now: now
        )
        let pickedExplicit = CardScheduler.pickToday(
            due: [], newCardIDs: newIDs, limit: 5, now: now,
            alreadyReviewedToday: 0
        )
        XCTAssertEqual(pickedNoArg, pickedExplicit)
        XCTAssertEqual(pickedNoArg.count, 5)
    }
}
