import XCTest
import SwiftData
@testable import JLPTDeck

final class SRSStateTests: XCTestCase {
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: SRSState.self, configurations: config)
    }

    @MainActor
    func testCreateApplyUpdateAndSnapshotRoundTrip() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let cardID = UUID()
        let state = SRSState(cardID: cardID)
        context.insert(state)

        // Defaults match spec.
        XCTAssertEqual(state.ease, 2.5)
        XCTAssertEqual(state.intervalDays, 0)
        XCTAssertEqual(state.reps, 0)
        XCTAssertEqual(state.lapses, 0)
        XCTAssertNil(state.lastReview)

        // Snapshot round-trip reflects current fields.
        let snap = state.snapshot()
        XCTAssertEqual(snap.cardID, cardID)
        XCTAssertEqual(snap.ease, 2.5)
        XCTAssertEqual(snap.intervalDays, 0)
        XCTAssertEqual(snap.reps, 0)
        XCTAssertEqual(snap.lapses, 0)
        XCTAssertNil(snap.lastReview)

        // Apply an SRSUpdate produced by the domain and verify mutation.
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let update = SM2.nextState(current: snap, quality: .good, now: now)
        state.apply(update, at: now)

        XCTAssertEqual(state.reps, 1)
        XCTAssertEqual(state.intervalDays, 1)
        XCTAssertEqual(state.ease, 2.5, accuracy: 1e-9)
        XCTAssertEqual(state.lapses, 0)
        XCTAssertEqual(state.lastReview, now)
        XCTAssertEqual(
            state.dueDate.timeIntervalSince1970,
            now.addingTimeInterval(86_400).timeIntervalSince1970,
            accuracy: 1.0
        )

        // Second snapshot reflects mutated state.
        let snap2 = state.snapshot()
        XCTAssertEqual(snap2.reps, 1)
        XCTAssertEqual(snap2.intervalDays, 1)
        XCTAssertEqual(snap2.lastReview, now)
    }
}
