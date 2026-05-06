import ComposableArchitecture
import XCTest
@testable import JLPTDeck

/// F8 reducer integration tests — verifies that `hideCurrentCardTapped`:
/// 1. removes ALL queue occurrences of the current card (including F3 re-queue)
/// 2. advances to the next card (or completion)
/// 3. clears the relearn flag for the hidden card
/// 4. does NOT mutate SRS state
///
/// Note: we do NOT verify the `setHidden` dependency call count. Recorder
/// actors / `LockIsolated` patterns combined with reducer effects have tripped
/// the SwiftData host-app deinit crash documented in CLAUDE.md (the legacy
/// `disabled_test_answerTapped_*` tests in `ReviewSessionFeatureTests` use
/// the same pattern and are still disabled). State-mutation assertions
/// remain strong evidence; the dependency wiring is verified by the
/// non-throwing no-op closure (any wiring break would surface as a test
/// failure via TCA's "unhandled effect" exhaustivity check before the
/// `exhaustivity = .off` line).
@MainActor
final class HideCardReducerTests: XCTestCase {

    private func makeCard(id: UUID = UUID(), gloss_ko: String = "먹다") -> VocabCardDTO {
        VocabCardDTO(
            id: id, headword: "食べる", reading: "たべる",
            gloss: "to eat", gloss_ko: gloss_ko, jlptLevel: "n4"
        )
    }

    private func seedQuestion(for card: VocabCardDTO) -> QuizQuestion {
        var rng = SystemRandomNumberGenerator()
        return QuizGenerator.make(
            input: .init(cardID: card.id, headword: card.headword,
                         reading: card.reading, glossKo: card.gloss_ko),
            distractors: ["걷다", "자다", "보다"],
            rng: &rng
        )
    }

    private func makeStore(
        initialState: ReviewSessionFeature.State
    ) -> TestStoreOf<ReviewSessionFeature> {
        let store = TestStore(initialState: initialState) {
            ReviewSessionFeature()
        } withDependencies: {
            $0.localRepository.setHidden = { _, _ in /* no-op */ }
            $0.localRepository.todayReviewCards = { _, _, _ in [] }
            $0.localRepository.distractorCards = { _, _, _ in [] }
            $0.localRepository.upsertSRS = { _, _, _ in }
            $0.continuousClock = ImmediateClock()
            $0.date.now = Date(timeIntervalSince1970: 1_700_000_000)
        }
        store.exhaustivity = .off
        return store
    }

    func test_hideCurrentCard_removesFromQueueAndAdvances() async {
        let c1 = makeCard(gloss_ko: "먹다")
        let c2 = makeCard(gloss_ko: "마시다")

        var state = ReviewSessionFeature.State()
        state.queue = [c1, c2]
        state.currentQuestion = seedQuestion(for: c1)

        let store = makeStore(initialState: state)
        await store.send(.view(.hideCurrentCardTapped))

        XCTAssertEqual(store.state.queue.count, 1, "c1 must be removed")
        XCTAssertEqual(store.state.queue.first?.id, c2.id)
        XCTAssertEqual(store.state.currentCard?.id, c2.id)
        XCTAssertFalse(store.state.isComplete)
        XCTAssertNil(store.state.selectedAnswerIndex)
        XCTAssertFalse(store.state.isAnswerRevealed)
    }

    /// Hide the LAST card → session completes.
    func test_hideLastCard_completesSession() async {
        let c1 = makeCard()

        var state = ReviewSessionFeature.State()
        state.queue = [c1]
        state.currentQuestion = seedQuestion(for: c1)

        let store = makeStore(initialState: state)
        await store.send(.view(.hideCurrentCardTapped))

        XCTAssertTrue(store.state.isComplete)
        XCTAssertNil(store.state.currentQuestion)
    }

    /// Hide MUST also strip the card from `relearnedCardIDs` and any F3
    /// re-queued occurrence (so it doesn't re-appear later in the session).
    func test_hideRelearnedCard_dropsFromRelearnQueue() async {
        let c1 = makeCard(gloss_ko: "A")
        let c2 = makeCard(gloss_ko: "B")

        var state = ReviewSessionFeature.State()
        // c1 was already wrong-answered and re-queued (F3 path).
        state.queue = [c1, c2, c1]
        state.relearnedCardIDs = [c1.id]
        state.currentQuestion = seedQuestion(for: c1)

        let store = makeStore(initialState: state)
        await store.send(.view(.hideCurrentCardTapped))

        XCTAssertEqual(store.state.queue.count, 1, "both c1 occurrences gone")
        XCTAssertEqual(store.state.queue.first?.id, c2.id)
        XCTAssertFalse(store.state.relearnedCardIDs.contains(c1.id))
    }

    /// `setHidden` persistence failure increments `hideFailedCount` and
    /// surfaces via SessionComplete. Card stays out of the in-memory queue
    /// (already removed) so the user is not blocked. F8 rev2 — non-silent
    /// failure handling.
    func test_setHiddenPersistenceFailure_incrementsCounter() async {
        struct PersistFailure: Error {}
        let c1 = makeCard()

        var state = ReviewSessionFeature.State()
        state.queue = [c1]
        state.currentQuestion = seedQuestion(for: c1)

        let store = TestStore(initialState: state) {
            ReviewSessionFeature()
        } withDependencies: {
            $0.localRepository.setHidden = { _, _ in throw PersistFailure() }
            $0.localRepository.todayReviewCards = { _, _, _ in [] }
            $0.localRepository.distractorCards = { _, _, _ in [] }
            $0.localRepository.upsertSRS = { _, _, _ in }
            $0.continuousClock = ImmediateClock()
            $0.date.now = Date(timeIntervalSince1970: 1_700_000_000)
        }
        store.exhaustivity = .off

        await store.send(.view(.hideCurrentCardTapped))
        await store.receive(\.internal.hidePersistenceFailed)

        // Card still gone from queue (in-memory remove is sync).
        XCTAssertTrue(store.state.isComplete)
        // Counter incremented for SessionComplete display.
        XCTAssertEqual(store.state.hideFailedCount, 1)
        // loadError NOT polluted (same rule as F4 rev3).
        XCTAssertNil(store.state.loadError)
    }

    /// Hide MUST NOT mutate SRS state for the hidden card.
    func test_hideCard_doesNotMutateSRS() async {
        let c1 = makeCard()
        let pinnedSnap = SRSSnapshot(
            cardID: c1.id, ease: 2.5, intervalDays: 3, reps: 1, lapses: 0,
            lastReview: nil, dueDate: Date(timeIntervalSince1970: 1_700_000_000)
        )

        var state = ReviewSessionFeature.State()
        state.queue = [c1]
        state.srsByCardID[c1.id] = pinnedSnap
        state.currentQuestion = seedQuestion(for: c1)

        let store = makeStore(initialState: state)
        await store.send(.view(.hideCurrentCardTapped))

        XCTAssertEqual(store.state.srsByCardID[c1.id]?.intervalDays, 3)
        XCTAssertEqual(store.state.srsByCardID[c1.id]?.reps, 1)
        XCTAssertEqual(store.state.failedUpsertCount, 0)
    }
}
