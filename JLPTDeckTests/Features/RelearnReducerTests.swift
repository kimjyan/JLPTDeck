import ComposableArchitecture
import XCTest
@testable import JLPTDeck

/// F3 reducer integration tests. Verifies the answerTapped → autoAdvanceFired
/// → retry path without `LockIsolated`-style call recording (which is what
/// the legacy `disabled_test_answerTapped_*` tests use and that pattern is
/// suspected of triggering the SwiftData host-app deinit crash documented in
/// `CLAUDE.md` and the `defer-jlptdeck-simulator-crash` memory).
///
/// Strategy:
/// - For the "should NOT call upsertSRS" assertion: configure the dependency
///   to `throw`. If it gets called, the reducer translates the throw into
///   `.internal(.upsertFailed(_))`, which sets `state.loadError`. Asserting
///   `loadError == nil` proves the dependency was never invoked.
/// - For the "first-attempt SM-2 ran" assertion: rely on the in-memory
///   `srsByCardID` mutation (the optimistic update path). No closure capture
///   needed.
@MainActor
final class RelearnReducerTests: XCTestCase {

    private struct UpsertCalledError: Error { let message: String }

    private func makeCard(
        id: UUID = UUID(),
        gloss_ko: String = "먹다"
    ) -> VocabCardDTO {
        VocabCardDTO(
            id: id,
            headword: "食べる",
            reading: "たべる",
            gloss: "to eat",
            gloss_ko: gloss_ko,
            jlptLevel: "n4"
        )
    }

    private func seedQuestion(for card: VocabCardDTO) -> QuizQuestion {
        var rng = SystemRandomNumberGenerator()
        return QuizGenerator.make(
            input: .init(
                cardID: card.id,
                headword: card.headword,
                reading: card.reading,
                glossKo: card.gloss_ko
            ),
            distractors: ["걷다", "자다", "보다"],
            rng: &rng
        )
    }

    /// First-attempt wrong answer must:
    /// - increment lapses + reset reps via SM-2
    /// - re-queue the card at the end
    /// - mark the card in `relearnedCardIDs`
    func test_firstAttemptWrong_marksCardAsRelearnedAndUpdatesSRS() async {
        let card = makeCard()
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        var state = ReviewSessionFeature.State()
        state.queue = [card]
        state.currentQuestion = seedQuestion(for: card)

        let store = TestStore(initialState: state) {
            ReviewSessionFeature()
        } withDependencies: {
            $0.localRepository.upsertSRS = { _, _, _ in /* no-op for first attempt */ }
            $0.localRepository.todayReviewCards = { _, _, _ in [] }
            $0.localRepository.distractorCards = { _, _, _ in [] }
            $0.continuousClock = ImmediateClock()
            $0.date.now = now
        }
        store.exhaustivity = .off

        let wrongIdx = (state.currentQuestion!.correctIndex + 1) % 4
        await store.send(.view(.answerTapped(wrongIdx)))
        await store.receive(\.internal.autoAdvanceFired)

        // SM-2 ran (optimistic in-memory update).
        let snap = store.state.srsByCardID[card.id]
        XCTAssertNotNil(snap, "SRS snapshot must exist after first attempt")
        XCTAssertEqual(snap?.lapses, 1, ".again must increment lapses")
        XCTAssertEqual(snap?.reps, 0, ".again must reset reps")

        // Card was re-queued and marked.
        XCTAssertEqual(store.state.queue.count, 2, "wrong card must be appended")
        XCTAssertEqual(store.state.queue.last?.id, card.id)
        XCTAssertTrue(
            store.state.relearnedCardIDs.contains(card.id),
            "Card must be marked in relearnedCardIDs after first wrong attempt"
        )
        XCTAssertEqual(store.state.relearnedCount, 0, "no recovery yet")
        XCTAssertNil(store.state.loadError, "no upsert error path")
    }

    /// Re-attempt of a relearned card MUST NOT touch SRS.
    /// We assert this two ways:
    ///   1. `srsByCardID[card.id]` is unchanged from its pre-seeded value.
    ///   2. `upsertSRS` throws if called → `.upsertFailed` increments
    ///      `failedUpsertCount`. Asserting `failedUpsertCount == 0` proves
    ///      no call happened. (F4 rev3 made `loadError` no longer set on
    ///      save failure, so the counter is now the canary.)
    func test_retryOfRelearnedCard_skipsSRSAndIncrementsRecoveryCount() async throws {
        let card = makeCard()
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        // Pre-seeded SRS state from the prior (first) attempt.
        let pinnedSnapshot = SRSSnapshot(
            cardID: card.id,
            ease: 2.30,
            intervalDays: 1,
            reps: 0,
            lapses: 1,
            lastReview: now.addingTimeInterval(-60),
            dueDate: now
        )

        var state = ReviewSessionFeature.State()
        state.queue = [card]
        state.currentQuestion = seedQuestion(for: card)
        state.srsByCardID[card.id] = pinnedSnapshot
        state.relearnedCardIDs = [card.id]   // simulate re-queue from prior turn

        let store = TestStore(initialState: state) {
            ReviewSessionFeature()
        } withDependencies: {
            // If the retry path mistakenly invokes upsertSRS, the throw will
            // be observed as `.internal(.upsertFailed(_))` which sets
            // `loadError`. We then assert `loadError == nil`.
            $0.localRepository.upsertSRS = { _, _, _ in
                throw UpsertCalledError(message: "upsertSRS must not run on retry")
            }
            $0.localRepository.todayReviewCards = { _, _, _ in [] }
            $0.localRepository.distractorCards = { _, _, _ in [] }
            $0.continuousClock = ImmediateClock()
            $0.date.now = now
        }
        store.exhaustivity = .off

        let correctIdx = state.currentQuestion!.correctIndex
        await store.send(.view(.answerTapped(correctIdx)))
        await store.receive(\.internal.autoAdvanceFired)

        // SRS snapshot pinned — no fields drifted.
        let after = try XCTUnwrap(store.state.srsByCardID[card.id])
        XCTAssertEqual(after.ease, pinnedSnapshot.ease, accuracy: 0.0001)
        XCTAssertEqual(after.intervalDays, pinnedSnapshot.intervalDays)
        XCTAssertEqual(after.reps, pinnedSnapshot.reps)
        XCTAssertEqual(after.lapses, pinnedSnapshot.lapses)
        XCTAssertEqual(after.dueDate, pinnedSnapshot.dueDate)

        // upsertSRS never ran → no propagated error → counter stays at 0.
        XCTAssertEqual(store.state.failedUpsertCount, 0,
                       "upsertSRS must not be invoked on retry path")
        XCTAssertNil(store.state.loadError,
                     "save failures must not pollute loadError (F4 rev3)")

        // Recovery counter incremented (for F10 SessionComplete display).
        XCTAssertEqual(store.state.relearnedCount, 1)

        // First-attempt counters untouched (no double-counting).
        XCTAssertEqual(store.state.correctCount, 0)
        XCTAssertEqual(store.state.wrongCount, 0)
    }

    /// Verify the cross-session leak fix: F3 state fields reset on both
    /// `.taskWithPreloaded` and `.loadResult(.success)` paths so a stale
    /// `relearnedCardIDs` from a prior session does not silently skip SRS
    /// for a brand-new session's first attempt.
    func test_taskWithPreloaded_resetsF3State() async {
        let card = makeCard()
        let staleID = UUID()

        var state = ReviewSessionFeature.State()
        state.relearnedCardIDs = [staleID]
        state.relearnedCount = 7

        let store = TestStore(initialState: state) {
            ReviewSessionFeature()
        } withDependencies: {
            $0.continuousClock = ImmediateClock()
            $0.date.now = Date(timeIntervalSince1970: 1_700_000_000)
        }
        store.exhaustivity = .off

        await store.send(.view(.taskWithPreloaded(
            queue: [card], srs: [:], distractors: []
        )))

        XCTAssertTrue(
            store.state.relearnedCardIDs.isEmpty,
            "relearnedCardIDs must reset on new session preload"
        )
        XCTAssertEqual(
            store.state.relearnedCount, 0,
            "relearnedCount must reset on new session preload"
        )
    }
}
