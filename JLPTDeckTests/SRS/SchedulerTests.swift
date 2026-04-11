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
}
