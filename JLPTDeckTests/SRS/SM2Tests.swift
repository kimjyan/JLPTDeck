import XCTest
@testable import JLPTDeck

final class SM2Tests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func freshSnapshot() -> SRSSnapshot {
        SRSSnapshot(
            cardID: UUID(),
            ease: 2.5,
            intervalDays: 0,
            reps: 0,
            lapses: 0,
            lastReview: nil,
            dueDate: now
        )
    }

    // 1. First review with .good -> reps=1, interval=1, ease unchanged for q=4.
    func testFirstGoodReview() {
        let result = SM2.nextState(current: freshSnapshot(), quality: .good, now: now)
        XCTAssertEqual(result.reps, 1)
        XCTAssertEqual(result.intervalDays, 1)
        XCTAssertEqual(result.ease, 2.5, accuracy: 1e-9)
        XCTAssertEqual(result.lapses, 0)
    }

    // 2. Second review with .good -> reps=2, interval=6.
    func testSecondGoodReview() {
        let snap = SRSSnapshot(
            cardID: UUID(), ease: 2.5, intervalDays: 1, reps: 1,
            lapses: 0, lastReview: now, dueDate: now
        )
        let result = SM2.nextState(current: snap, quality: .good, now: now)
        XCTAssertEqual(result.reps, 2)
        XCTAssertEqual(result.intervalDays, 6)
        XCTAssertEqual(result.ease, 2.5, accuracy: 1e-9)
    }

    // 3. Third review from reps=2, interval=6, ef=2.5 -> reps=3, interval=15.
    func testThirdGoodReviewUsesEaseMultiplier() {
        let snap = SRSSnapshot(
            cardID: UUID(), ease: 2.5, intervalDays: 6, reps: 2,
            lapses: 0, lastReview: now, dueDate: now
        )
        let result = SM2.nextState(current: snap, quality: .good, now: now)
        XCTAssertEqual(result.reps, 3)
        XCTAssertEqual(result.intervalDays, 15) // round(6 * 2.5)
    }

    // 4. .again resets reps to 0, interval to 1, increments lapses.
    func testAgainResetsRepsAndIncrementsLapses() {
        let snap = SRSSnapshot(
            cardID: UUID(), ease: 2.5, intervalDays: 15, reps: 3,
            lapses: 1, lastReview: now, dueDate: now
        )
        let result = SM2.nextState(current: snap, quality: .again, now: now)
        XCTAssertEqual(result.reps, 0)
        XCTAssertEqual(result.intervalDays, 1)
        XCTAssertEqual(result.lapses, 2)
    }

    // 5. Ease never drops below 1.3 even under repeated .again.
    func testEaseFloorAt1_3() {
        var snap = freshSnapshot()
        for _ in 0..<50 {
            let update = SM2.nextState(current: snap, quality: .again, now: now)
            XCTAssertGreaterThanOrEqual(update.ease, 1.3)
            snap = SRSSnapshot(
                cardID: snap.cardID,
                ease: update.ease,
                intervalDays: update.intervalDays,
                reps: update.reps,
                lapses: update.lapses,
                lastReview: now,
                dueDate: update.dueDate
            )
        }
        XCTAssertEqual(snap.ease, 1.3, accuracy: 1e-9)
    }

    // 6. .easy (q=5) increases ease.
    func testEasyIncreasesEase() {
        let result = SM2.nextState(current: freshSnapshot(), quality: .easy, now: now)
        XCTAssertGreaterThan(result.ease, 2.5)
        // delta for q=5: 0.1 - 0 = 0.1
        XCTAssertEqual(result.ease, 2.6, accuracy: 1e-9)
    }

    // 7. .hard (q=3) decreases ease by ~0.14.
    func testHardDecreasesEase() {
        let result = SM2.nextState(current: freshSnapshot(), quality: .hard, now: now)
        // delta for q=3: 0.1 - 2*(0.08 + 2*0.02) = 0.1 - 2*0.12 = -0.14
        XCTAssertEqual(result.ease, 2.5 - 0.14, accuracy: 1e-9)
    }

    // 8. dueDate == now + intervalDays * 86400 (second-level tolerance).
    func testDueDateMatchesIntervalDays() {
        let snap = SRSSnapshot(
            cardID: UUID(), ease: 2.5, intervalDays: 6, reps: 2,
            lapses: 0, lastReview: now, dueDate: now
        )
        let result = SM2.nextState(current: snap, quality: .good, now: now)
        let expected = now.addingTimeInterval(TimeInterval(result.intervalDays) * 86_400)
        XCTAssertEqual(result.dueDate.timeIntervalSince1970,
                       expected.timeIntervalSince1970,
                       accuracy: 1.0)
    }
}
