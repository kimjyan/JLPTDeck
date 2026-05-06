import ComposableArchitecture
import XCTest
@testable import JLPTDeck

/// F4 reducer integration tests — verifies that failed upserts enqueue to the
/// retry client and that the next session boundary drains the queue. Uses a
/// thread-safe in-memory mock for `upsertRetry` (NSLock-guarded array, no
/// `LockIsolated` to avoid the SwiftData host-app deinit crash pattern).
@MainActor
final class UpsertRetryReducerTests: XCTestCase {

    /// Sendable in-memory mock backing the `UpsertRetryClient` injection.
    /// Mirrors the `liveValue` semantics (replace-by-cardID, append) and
    /// exposes `waitForFirstRemove()` so tests can synchronize on the
    /// fire-and-forget drain effect deterministically (no `Task.yield()`
    /// polling loops).
    private final class MockRetryStore: @unchecked Sendable {
        private let lock = NSLock()
        private var items: [UpsertRetryItem] = []
        private var pendingRemoveSignal: CheckedContinuation<UUID, Never>?

        var snapshot: [UpsertRetryItem] {
            lock.lock(); defer { lock.unlock() }
            return items
        }

        func client() -> UpsertRetryClient {
            UpsertRetryClient(
                list: { [weak self] in self?.snapshot ?? [] },
                enqueue: { [weak self] item in
                    guard let self else { return }
                    self.lock.lock(); defer { self.lock.unlock() }
                    self.items.removeAll { $0.cardID == item.cardID }
                    self.items.append(item)
                },
                remove: { [weak self] cardID in
                    guard let self else { return }
                    self.lock.lock()
                    self.items.removeAll { $0.cardID == cardID }
                    let cont = self.pendingRemoveSignal
                    self.pendingRemoveSignal = nil
                    self.lock.unlock()
                    cont?.resume(returning: cardID)
                },
                clear: { [weak self] in
                    guard let self else { return }
                    self.lock.lock(); defer { self.lock.unlock() }
                    self.items.removeAll()
                }
            )
        }

        func seed(_ items: [UpsertRetryItem]) {
            lock.lock(); defer { lock.unlock() }
            self.items = items
        }

        /// Awaits the next `remove(_:)` call. Returns the removed card ID.
        /// Use to synchronize on the fire-and-forget drain effect.
        func waitForFirstRemove() async -> UUID {
            await withCheckedContinuation { cont in
                lock.lock(); defer { lock.unlock() }
                pendingRemoveSignal = cont
            }
        }
    }

    private struct UpsertFailure: Error {}

    private func makeCard(
        id: UUID = UUID(),
        gloss_ko: String = "먹다"
    ) -> VocabCardDTO {
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

    /// First-attempt failed upsert must:
    /// 1. enqueue an `UpsertRetryItem` carrying the SM-2 result
    /// 2. increment `state.failedUpsertCount`
    /// 3. NOT set `state.loadError` — F4 rev3 made save failures non-blocking
    ///    so a per-card SRS write failure never collapses the quiz UI into
    ///    `errorState`.
    func test_upsertFailure_enqueuesAndIncrementsCounter() async throws {
        let card = makeCard()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let mock = MockRetryStore()

        var state = ReviewSessionFeature.State()
        state.queue = [card]
        state.currentQuestion = seedQuestion(for: card)

        let store = TestStore(initialState: state) {
            ReviewSessionFeature()
        } withDependencies: {
            $0.localRepository.upsertSRS = { _, _, _ in throw UpsertFailure() }
            $0.localRepository.todayReviewCards = { _, _, _ in [] }
            $0.localRepository.distractorCards = { _, _, _ in [] }
            $0.upsertRetry = mock.client()
            $0.continuousClock = ImmediateClock()
            $0.date.now = now
        }
        store.exhaustivity = .off

        let wrongIdx = (state.currentQuestion!.correctIndex + 1) % 4
        await store.send(.view(.answerTapped(wrongIdx)))
        await store.receive(\.internal.upsertFailed)
        await store.receive(\.internal.autoAdvanceFired)

        // Counter incremented; loadError NOT touched (rev3 — quiz flow
        // must not collapse into errorState on a per-card save failure).
        XCTAssertEqual(store.state.failedUpsertCount, 1)
        XCTAssertNil(store.state.loadError,
                     "save failures must not pollute loadError")

        // Queued for retry with the correct SM-2 result (.again → lapses=1, reps=0).
        let queued = mock.snapshot
        XCTAssertEqual(queued.count, 1)
        let item = try XCTUnwrap(queued.first)
        XCTAssertEqual(item.cardID, card.id)
        XCTAssertEqual(item.lapses, 1)
        XCTAssertEqual(item.reps, 0)
    }

    /// Drain on `.taskWithPreloaded` must call `upsertSRS` for each pending
    /// item and `remove` it on success.
    ///
    /// Synchronization: the mock exposes `waitForFirstRemove()` that resolves
    /// the moment `remove(_:)` is invoked by the drain effect. No
    /// `Task.yield()` polling — the test fails fast if drain never fires.
    ///
    /// (Failure-branch coverage lives in `UpsertRetryDrainTests` against the
    /// pure `UpsertRetryDrain.drain` function, which avoids the throwing
    /// dependency + TestStore combination that has tripped the simulator
    /// deinit crash documented in CLAUDE.md.)
    func test_drainOnNewSession_removesSucceededItems() async {
        let cardID = UUID()
        let mock = MockRetryStore()
        mock.seed([
            UpsertRetryItem(
                cardID: cardID, ease: 2.5, intervalDays: 1, reps: 0, lapses: 1,
                dueDate: Date(timeIntervalSince1970: 1_700_086_400),
                now: Date(timeIntervalSince1970: 1_700_000_000)
            )
        ])

        let store = TestStore(initialState: ReviewSessionFeature.State()) {
            ReviewSessionFeature()
        } withDependencies: {
            // All retries succeed → all items must be removed from the queue.
            $0.localRepository.upsertSRS = { _, _, _ in /* succeed */ }
            $0.localRepository.todayReviewCards = { _, _, _ in [] }
            $0.localRepository.distractorCards = { _, _, _ in [] }
            $0.upsertRetry = mock.client()
            $0.continuousClock = ImmediateClock()
            $0.date.now = Date(timeIntervalSince1970: 1_700_100_000)
        }
        store.exhaustivity = .off

        // Arm the synchronization continuation BEFORE triggering the effect.
        async let removed = mock.waitForFirstRemove()
        await store.send(.view(.taskWithPreloaded(queue: [], srs: [:], distractors: [])))
        let removedID = await removed

        XCTAssertEqual(removedID, cardID, "drain must remove the queued cardID")
        XCTAssertTrue(mock.snapshot.isEmpty)
        XCTAssertEqual(store.state.failedUpsertCount, 0,
                       "Drain must not pollute session counters")
        XCTAssertNil(store.state.loadError)
    }

    /// Quiz flow MUST NOT collapse into `errorState` after a save failure.
    /// View-side check (`ReviewSessionView`) gates the SessionComplete branch
    /// behind `loadError == nil`. Reducer-level proof: after a forced save
    /// failure on the only card, the session completes (`isComplete == true`)
    /// with `loadError == nil`. The view is then free to render
    /// `SessionCompleteView`, which surfaces `failedUpsertCount` to the user.
    func test_upsertFailure_doesNotBlockSessionCompletion() async {
        let card = makeCard()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let mock = MockRetryStore()

        var state = ReviewSessionFeature.State()
        state.queue = [card]
        state.currentQuestion = seedQuestion(for: card)

        let store = TestStore(initialState: state) {
            ReviewSessionFeature()
        } withDependencies: {
            $0.localRepository.upsertSRS = { _, _, _ in throw UpsertFailure() }
            $0.localRepository.todayReviewCards = { _, _, _ in [] }
            $0.localRepository.distractorCards = { _, _, _ in [] }
            $0.upsertRetry = mock.client()
            $0.continuousClock = ImmediateClock()
            $0.date.now = now
        }
        store.exhaustivity = .off

        // Wrong answer on the only card → after autoAdvance the card is
        // re-queued (F3 relearn path). Answer correct on retry → relearn
        // branch skips upsert entirely → autoAdvance → isComplete.
        let wrongIdx = (state.currentQuestion!.correctIndex + 1) % 4
        await store.send(.view(.answerTapped(wrongIdx)))
        await store.receive(\.internal.upsertFailed)
        await store.receive(\.internal.autoAdvanceFired)

        // Now answer the re-queued card correctly.
        let q2 = store.state.currentQuestion!
        await store.send(.view(.answerTapped(q2.correctIndex)))
        await store.receive(\.internal.autoAdvanceFired)

        // The session must reach completion — never errorState.
        XCTAssertTrue(store.state.isComplete, "session must complete despite save failure")
        XCTAssertNil(store.state.loadError,
                     "save failure must NOT pollute loadError → ReviewSessionView errorState branch must NOT fire")
        XCTAssertEqual(store.state.failedUpsertCount, 1)
        XCTAssertEqual(mock.snapshot.count, 1, "failed write is queued for retry")
    }

    /// Cross-session reset: `failedUpsertCount` must go back to zero on a new
    /// session preload (mirrors the F3 cross-session leak fix).
    func test_taskWithPreloaded_resetsFailedUpsertCount() async {
        var state = ReviewSessionFeature.State()
        state.failedUpsertCount = 5

        let mock = MockRetryStore()
        let store = TestStore(initialState: state) {
            ReviewSessionFeature()
        } withDependencies: {
            // drainRetryQueueEffect captures `repo`; provide a no-op so the
            // dependency resolves even though the queue is empty.
            $0.localRepository.upsertSRS = { _, _, _ in }
            $0.localRepository.todayReviewCards = { _, _, _ in [] }
            $0.localRepository.distractorCards = { _, _, _ in [] }
            $0.upsertRetry = mock.client()
            $0.continuousClock = ImmediateClock()
            $0.date.now = Date(timeIntervalSince1970: 1_700_000_000)
        }
        store.exhaustivity = .off

        await store.send(.view(.taskWithPreloaded(queue: [], srs: [:], distractors: [])))
        XCTAssertEqual(store.state.failedUpsertCount, 0)
    }
}
