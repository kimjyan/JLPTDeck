import ComposableArchitecture
import XCTest
@testable import JLPTDeck

/// F9 reducer integration — verifies that response-latency tracking marks
/// SLOW first-attempt CORRECT answers and never affects SM-2 input.
@MainActor
final class LatencyReducerTests: XCTestCase {

    private let base = Date(timeIntervalSince1970: 1_700_000_000)

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

    /// Mutable date used to simulate the user taking N seconds to answer.
    private final class MockClock: @unchecked Sendable {
        private let lock = NSLock()
        private var current: Date
        init(_ start: Date) { self.current = start }
        func advance(by seconds: TimeInterval) {
            lock.lock(); defer { lock.unlock() }
            current = current.addingTimeInterval(seconds)
        }
        func now() -> Date {
            lock.lock(); defer { lock.unlock() }
            return current
        }
    }

    private func makeStore(card: VocabCardDTO, clock: MockClock) -> TestStoreOf<ReviewSessionFeature> {
        var state = ReviewSessionFeature.State()
        state.queue = [card]
        state.currentQuestion = seedQuestion(for: card)
        state.currentQuestionPresentedAt = clock.now()
        let store = TestStore(initialState: state) {
            ReviewSessionFeature()
        } withDependencies: {
            $0.localRepository.upsertSRS = { _, _, _ in }
            $0.localRepository.todayReviewCards = { _, _, _ in [] }
            $0.localRepository.distractorCards = { _, _, _ in [] }
            $0.continuousClock = ImmediateClock()
            $0.date.now = clock.now()   // snapshotted; per-action read uses snapshot
        }
        store.exhaustivity = .off
        return store
    }

    /// FAST correct → NOT marked slow. (latency well under threshold)
    func test_fastCorrectAnswer_notMarkedSlow() async {
        let c1 = makeCard()
        let clock = MockClock(base)
        var state = ReviewSessionFeature.State()
        state.queue = [c1]
        state.currentQuestion = seedQuestion(for: c1)
        state.currentQuestionPresentedAt = base

        // 500ms after presentation.
        let storeNow = base.addingTimeInterval(0.5)
        let store = TestStore(initialState: state) {
            ReviewSessionFeature()
        } withDependencies: {
            $0.localRepository.upsertSRS = { _, _, _ in }
            $0.localRepository.todayReviewCards = { _, _, _ in [] }
            $0.localRepository.distractorCards = { _, _, _ in [] }
            $0.continuousClock = ImmediateClock()
            $0.date.now = storeNow
        }
        store.exhaustivity = .off
        _ = clock

        let correctIdx = state.currentQuestion!.correctIndex
        await store.send(.view(.answerTapped(correctIdx)))

        XCTAssertTrue(store.state.slowFirstAttemptIDs.isEmpty)
        XCTAssertEqual(store.state.correctCount, 1)
    }

    /// SLOW correct → marked. Threshold = 5000ms; we wait 6000ms.
    func test_slowCorrectAnswer_isMarked() async {
        let c1 = makeCard()
        var state = ReviewSessionFeature.State()
        state.queue = [c1]
        state.currentQuestion = seedQuestion(for: c1)
        state.currentQuestionPresentedAt = base

        let storeNow = base.addingTimeInterval(6)
        let store = TestStore(initialState: state) {
            ReviewSessionFeature()
        } withDependencies: {
            $0.localRepository.upsertSRS = { _, _, _ in }
            $0.localRepository.todayReviewCards = { _, _, _ in [] }
            $0.localRepository.distractorCards = { _, _, _ in [] }
            $0.continuousClock = ImmediateClock()
            $0.date.now = storeNow
        }
        store.exhaustivity = .off

        let correctIdx = state.currentQuestion!.correctIndex
        await store.send(.view(.answerTapped(correctIdx)))

        XCTAssertEqual(store.state.slowFirstAttemptIDs, [c1.id])
        XCTAssertEqual(store.state.correctCount, 1)
    }

    /// SLOW WRONG → not marked (mark is for correct only — guess heuristic).
    func test_slowWrongAnswer_notMarkedSlow() async {
        let c1 = makeCard()
        var state = ReviewSessionFeature.State()
        state.queue = [c1]
        state.currentQuestion = seedQuestion(for: c1)
        state.currentQuestionPresentedAt = base

        let storeNow = base.addingTimeInterval(10)
        let store = TestStore(initialState: state) {
            ReviewSessionFeature()
        } withDependencies: {
            $0.localRepository.upsertSRS = { _, _, _ in }
            $0.localRepository.todayReviewCards = { _, _, _ in [] }
            $0.localRepository.distractorCards = { _, _, _ in [] }
            $0.continuousClock = ImmediateClock()
            $0.date.now = storeNow
        }
        store.exhaustivity = .off

        let wrongIdx = (state.currentQuestion!.correctIndex + 1) % 4
        await store.send(.view(.answerTapped(wrongIdx)))

        XCTAssertTrue(store.state.slowFirstAttemptIDs.isEmpty)
        XCTAssertEqual(store.state.wrongCount, 1)
    }

    /// SM-2 input is unaffected — slow correct still produces .good (reps=1, lapses=0).
    /// Indirect: srsByCardID after answer should have reps=1 lapses=0 just like a fast correct.
    func test_slowCorrectAnswer_doesNotChangeSM2Input() async {
        let c1 = makeCard()
        var state = ReviewSessionFeature.State()
        state.queue = [c1]
        state.currentQuestion = seedQuestion(for: c1)
        state.currentQuestionPresentedAt = base

        let storeNow = base.addingTimeInterval(10)
        let store = TestStore(initialState: state) {
            ReviewSessionFeature()
        } withDependencies: {
            $0.localRepository.upsertSRS = { _, _, _ in }
            $0.localRepository.todayReviewCards = { _, _, _ in [] }
            $0.localRepository.distractorCards = { _, _, _ in [] }
            $0.continuousClock = ImmediateClock()
            $0.date.now = storeNow
        }
        store.exhaustivity = .off

        let correctIdx = state.currentQuestion!.correctIndex
        await store.send(.view(.answerTapped(correctIdx)))

        let snap = store.state.srsByCardID[c1.id]
        XCTAssertEqual(snap?.reps, 1, "slow correct must still produce .good (reps=1)")
        XCTAssertEqual(snap?.lapses, 0)
    }

    /// F9 rev2: every answerTapped emits a `ResponseLatencyRecord`,
    /// regardless of correctness or first/retry status. SM-2 path is the
    /// SAME (.good for correct, .again for wrong) — measurement is parallel.
    func test_everyAnswerTapped_appendsLatencyRecord() async {
        let c1 = makeCard()
        var state = ReviewSessionFeature.State()
        state.queue = [c1]
        state.currentQuestion = seedQuestion(for: c1)
        state.currentQuestionPresentedAt = base

        // Wrong answer 3 seconds in (fast wrong).
        let storeNow = base.addingTimeInterval(3)
        let store = TestStore(initialState: state) {
            ReviewSessionFeature()
        } withDependencies: {
            $0.localRepository.upsertSRS = { _, _, _ in }
            $0.localRepository.todayReviewCards = { _, _, _ in [] }
            $0.localRepository.distractorCards = { _, _, _ in [] }
            $0.continuousClock = ImmediateClock()
            $0.date.now = storeNow
        }
        store.exhaustivity = .off

        let wrongIdx = (state.currentQuestion!.correctIndex + 1) % 4
        await store.send(.view(.answerTapped(wrongIdx)))

        XCTAssertEqual(store.state.responseLatencies.count, 1)
        let r = store.state.responseLatencies.first!
        XCTAssertEqual(r.cardID, c1.id)
        XCTAssertEqual(r.latencyMs, 3000)
        XCTAssertFalse(r.isCorrect)
        XCTAssertTrue(r.isFirstAttempt)
        XCTAssertFalse(r.isSlow)   // 3000 < 5000
        // Slow set is for first-attempt-correct only — empty here.
        XCTAssertTrue(store.state.slowFirstAttemptIDs.isEmpty)
    }

    /// Retry attempt: still recorded, with `isFirstAttempt = false`.
    func test_retryAttempt_recordsLatencyWithIsFirstAttemptFalse() async throws {
        let c1 = makeCard()
        var state = ReviewSessionFeature.State()
        state.queue = [c1]
        state.currentQuestion = seedQuestion(for: c1)
        state.currentQuestionPresentedAt = base
        // Pre-marked as relearned (F3 path).
        state.relearnedCardIDs = [c1.id]
        state.srsByCardID[c1.id] = SRSSnapshot(
            cardID: c1.id, ease: 2.5, intervalDays: 1, reps: 0, lapses: 1,
            lastReview: nil, dueDate: base
        )

        let storeNow = base.addingTimeInterval(2)
        let store = TestStore(initialState: state) {
            ReviewSessionFeature()
        } withDependencies: {
            $0.localRepository.upsertSRS = { _, _, _ in
                XCTFail("upsertSRS must NOT be called on retry path")
            }
            $0.localRepository.todayReviewCards = { _, _, _ in [] }
            $0.localRepository.distractorCards = { _, _, _ in [] }
            $0.continuousClock = ImmediateClock()
            $0.date.now = storeNow
        }
        store.exhaustivity = .off

        let correctIdx = state.currentQuestion!.correctIndex
        await store.send(.view(.answerTapped(correctIdx)))

        XCTAssertEqual(store.state.responseLatencies.count, 1)
        let r = try XCTUnwrap(store.state.responseLatencies.first)
        XCTAssertFalse(r.isFirstAttempt, "retry must be flagged isFirstAttempt = false")
        XCTAssertTrue(r.isCorrect)
        XCTAssertEqual(r.latencyMs, 2000)
        // Retry doesn't add to slowFirstAttemptIDs even if slow.
        XCTAssertTrue(store.state.slowFirstAttemptIDs.isEmpty)
    }

    /// F9 rev2: scenePhaseBackgrounded clears the timestamp so the next
    /// answer's latencyMs is nil (not the background-suspended duration).
    func test_scenePhaseBackgrounded_dropsTimestamp() async {
        let c1 = makeCard()
        var state = ReviewSessionFeature.State()
        state.queue = [c1]
        state.currentQuestion = seedQuestion(for: c1)
        state.currentQuestionPresentedAt = base

        let store = TestStore(initialState: state) {
            ReviewSessionFeature()
        } withDependencies: {
            $0.localRepository.upsertSRS = { _, _, _ in }
            $0.localRepository.todayReviewCards = { _, _, _ in [] }
            $0.localRepository.distractorCards = { _, _, _ in [] }
            $0.continuousClock = ImmediateClock()
            // 10 minutes "passed" while backgrounded.
            $0.date.now = base.addingTimeInterval(600)
        }
        store.exhaustivity = .off

        await store.send(.view(.scenePhaseBackgrounded))
        XCTAssertNil(store.state.currentQuestionPresentedAt)

        // Now the user returns and answers — latencyMs must be nil, not 600000.
        let correctIdx = state.currentQuestion!.correctIndex
        await store.send(.view(.answerTapped(correctIdx)))
        XCTAssertEqual(store.state.responseLatencies.count, 1)
        XCTAssertNil(store.state.responseLatencies.first?.latencyMs)
        XCTAssertFalse(store.state.responseLatencies.first?.isSlow ?? true)
    }

    /// nil presentedAt (e.g. session resumed mid-question) → no marking.
    func test_nilPresentedAt_neverMarksSlow() async {
        let c1 = makeCard()
        var state = ReviewSessionFeature.State()
        state.queue = [c1]
        state.currentQuestion = seedQuestion(for: c1)
        state.currentQuestionPresentedAt = nil

        let store = TestStore(initialState: state) {
            ReviewSessionFeature()
        } withDependencies: {
            $0.localRepository.upsertSRS = { _, _, _ in }
            $0.localRepository.todayReviewCards = { _, _, _ in [] }
            $0.localRepository.distractorCards = { _, _, _ in [] }
            $0.continuousClock = ImmediateClock()
            $0.date.now = base.addingTimeInterval(60)
        }
        store.exhaustivity = .off

        let correctIdx = state.currentQuestion!.correctIndex
        await store.send(.view(.answerTapped(correctIdx)))

        XCTAssertTrue(store.state.slowFirstAttemptIDs.isEmpty)
    }
}
