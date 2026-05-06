import ComposableArchitecture
import XCTest
@testable import JLPTDeck

/// G-SessionComplete (F7+F10) reducer tests. Covers the next-day preview
/// effect, the streak-after-today peek calculation, and the focused-review
/// (no-level) skip path. Uses the same mock-repo pattern as
/// `RelearnReducerTests` / `UpsertRetryReducerTests` to avoid the
/// `LockIsolated`-driven simulator deinit crash documented in CLAUDE.md.
@MainActor
final class SessionPreviewReducerTests: XCTestCase {

    // MARK: helpers

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

    // MARK: tests

    /// Direct receipt of `.sessionPreviewLoaded` must populate both state
    /// fields. (Pure-reduce check — no effect plumbing.)
    func test_sessionPreviewLoaded_setsState() async {
        let store = TestStore(initialState: ReviewSessionFeature.State()) {
            ReviewSessionFeature()
        } withDependencies: {
            $0.continuousClock = ImmediateClock()
            $0.date.now = Date(timeIntervalSince1970: 1_700_000_000)
        }
        store.exhaustivity = .off

        await store.send(.internal(.sessionPreviewLoaded(
            nextDayDue: 17, streakAfterToday: 4
        )))

        XCTAssertEqual(store.state.nextDayDueCount, 17)
        XCTAssertEqual(store.state.streakAfterToday, 4)
    }

    /// Completing the last card via `autoAdvanceFired` while a level was
    /// captured at `.task` must fire the preview effect, which in turn:
    ///   - calls `todayReviewCards` with `now = today + 1day` to count
    ///     tomorrow's due cards
    ///   - reads `loadStreak` + `loadLastStudyDate` and computes the
    ///     streak-after-today peek
    ///   - sends `.sessionPreviewLoaded` back to the reducer
    func test_completionFromAutoAdvance_firesPreview() async {
        let card = makeCard()
        let now = Date(timeIntervalSince1970: 1_700_000_000)        // day T
        let yesterday = now.addingTimeInterval(-86_400)             // day T-1

        var state = ReviewSessionFeature.State()
        state.queue = [card]
        state.currentQuestion = seedQuestion(for: card)
        state.sessionLevel = .n4
        state.sessionLimit = 20

        let preloadedDue: [VocabCardDTO.WithSRS] = (0..<5).map { _ in
            VocabCardDTO.WithSRS(card: makeCard(id: UUID()), srs: nil)
        }

        let store = TestStore(initialState: state) {
            ReviewSessionFeature()
        } withDependencies: {
            $0.localRepository.upsertSRS = { _, _, _ in /* succeed */ }
            $0.localRepository.todayReviewCards = { _, _, _ in preloadedDue }
            $0.localRepository.distractorCards = { _, _, _ in [] }
            $0.continuousClock = ImmediateClock()
            $0.date.now = now
            // Streak: studied yesterday → today's session continues to N+1.
            $0.userSettings.loadStreak = { 3 }
            $0.userSettings.loadLastStudyDate = { yesterday }
        }
        store.exhaustivity = .off

        await store.send(.view(.answerTapped(state.currentQuestion!.correctIndex)))
        await store.receive(\.internal.autoAdvanceFired)
        await store.receive(\.internal.sessionPreviewLoaded)

        XCTAssertTrue(store.state.isComplete)
        XCTAssertEqual(store.state.nextDayDueCount, 5,
                       "scheduler picked all 5 new cards under the 20-limit")
        XCTAssertEqual(store.state.streakAfterToday, 4,
                       "yesterday + today → streak 3 → 4")
    }

    /// Focused-review (taskWithPreloaded) sets no level → preview is
    /// silently skipped. The completion path must NOT crash on a nil
    /// `sessionLevel`. State preview fields stay nil so the view block
    /// hides without rendering.
    func test_completionFromAutoAdvance_skipsPreviewForFocusedReview() async {
        let card = makeCard()
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        var state = ReviewSessionFeature.State()
        state.queue = [card]
        state.currentQuestion = seedQuestion(for: card)
        // sessionLevel intentionally nil — focused-review path.

        let store = TestStore(initialState: state) {
            ReviewSessionFeature()
        } withDependencies: {
            $0.localRepository.upsertSRS = { _, _, _ in }
            $0.localRepository.todayReviewCards = { _, _, _ in
                XCTFail("preview must not query repo when sessionLevel is nil")
                return []
            }
            $0.localRepository.distractorCards = { _, _, _ in [] }
            $0.continuousClock = ImmediateClock()
            $0.date.now = now
            $0.userSettings.loadStreak = { 99 }
            $0.userSettings.loadLastStudyDate = { nil }
        }
        store.exhaustivity = .off

        await store.send(.view(.answerTapped(state.currentQuestion!.correctIndex)))
        await store.receive(\.internal.autoAdvanceFired)

        XCTAssertTrue(store.state.isComplete)
        XCTAssertNil(store.state.nextDayDueCount,
                     "focused review must leave preview field unset")
        XCTAssertNil(store.state.streakAfterToday)
    }

    /// Streak peek correctness — same-day re-open. User already studied
    /// today (lastStudyDate == today), streak was already updated to 5
    /// on that earlier session. Today's second session must keep streak
    /// at 5 (no double-count).
    func test_streakPeek_sameDayReopen_keepsCurrent() async {
        let card = makeCard()
        let calendar = Calendar.current
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let todayStart = calendar.startOfDay(for: now)

        var state = ReviewSessionFeature.State()
        state.queue = [card]
        state.currentQuestion = seedQuestion(for: card)
        state.sessionLevel = .n4
        state.sessionLimit = 20

        let store = TestStore(initialState: state) {
            ReviewSessionFeature()
        } withDependencies: {
            $0.localRepository.upsertSRS = { _, _, _ in }
            $0.localRepository.todayReviewCards = { _, _, _ in [] }
            $0.localRepository.distractorCards = { _, _, _ in [] }
            $0.continuousClock = ImmediateClock()
            $0.date.now = now
            $0.userSettings.loadStreak = { 5 }
            // Same-day: lastStudyDate is start-of-today.
            $0.userSettings.loadLastStudyDate = { todayStart }
        }
        store.exhaustivity = .off

        await store.send(.view(.answerTapped(state.currentQuestion!.correctIndex)))
        await store.receive(\.internal.autoAdvanceFired)
        await store.receive(\.internal.sessionPreviewLoaded)

        XCTAssertEqual(store.state.streakAfterToday, 5,
                       "same-day re-open must not bump the streak")
    }

    /// Streak peek correctness — broken streak (gap > 1 day or no prior
    /// study). Today is day 1.
    func test_streakPeek_brokenOrFresh_resetsToOne() async {
        let card = makeCard()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let weekAgo = now.addingTimeInterval(-7 * 86_400)

        var state = ReviewSessionFeature.State()
        state.queue = [card]
        state.currentQuestion = seedQuestion(for: card)
        state.sessionLevel = .n4
        state.sessionLimit = 20

        let store = TestStore(initialState: state) {
            ReviewSessionFeature()
        } withDependencies: {
            $0.localRepository.upsertSRS = { _, _, _ in }
            $0.localRepository.todayReviewCards = { _, _, _ in [] }
            $0.localRepository.distractorCards = { _, _, _ in [] }
            $0.continuousClock = ImmediateClock()
            $0.date.now = now
            $0.userSettings.loadStreak = { 12 }
            $0.userSettings.loadLastStudyDate = { weekAgo }
        }
        store.exhaustivity = .off

        await store.send(.view(.answerTapped(state.currentQuestion!.correctIndex)))
        await store.receive(\.internal.autoAdvanceFired)
        await store.receive(\.internal.sessionPreviewLoaded)

        XCTAssertEqual(store.state.streakAfterToday, 1,
                       "missed a day → today resets to 1")
    }

    /// `.task` entry must capture level + limit so that the autoAdvance
    /// completion branch can re-fire the preview effect with the correct
    /// JLPTLevel. (Regression guard against future refactors that drop
    /// the level capture.)
    func test_taskCapturesSessionLevelAndLimit() async {
        let store = TestStore(initialState: ReviewSessionFeature.State()) {
            ReviewSessionFeature()
        } withDependencies: {
            $0.localRepository.todayReviewCards = { _, _, _ in [] }
            $0.localRepository.distractorCards = { _, _, _ in [] }
            $0.localRepository.upsertSRS = { _, _, _ in }
            $0.continuousClock = ImmediateClock()
            $0.date.now = Date(timeIntervalSince1970: 1_700_000_000)
            $0.userSettings.loadStreak = { 0 }
            $0.userSettings.loadLastStudyDate = { nil }
        }
        store.exhaustivity = .off

        await store.send(.view(.task(level: .n2, limit: 35)))

        XCTAssertEqual(store.state.sessionLevel, .n2)
        XCTAssertEqual(store.state.sessionLimit, 35)
    }

    /// Cross-session leak guard: preview fields must reset on
    /// `.taskWithPreloaded` so a stale value from a prior session does not
    /// briefly flash on the new session's complete screen.
    func test_taskWithPreloaded_resetsPreviewFields() async {
        var state = ReviewSessionFeature.State()
        state.nextDayDueCount = 99
        state.streakAfterToday = 99

        let store = TestStore(initialState: state) {
            ReviewSessionFeature()
        } withDependencies: {
            $0.localRepository.upsertSRS = { _, _, _ in }
            $0.localRepository.todayReviewCards = { _, _, _ in [] }
            $0.localRepository.distractorCards = { _, _, _ in [] }
            $0.continuousClock = ImmediateClock()
            $0.date.now = Date(timeIntervalSince1970: 1_700_000_000)
        }
        store.exhaustivity = .off

        await store.send(.view(.taskWithPreloaded(queue: [], srs: [:], distractors: [])))

        XCTAssertNil(store.state.nextDayDueCount)
        XCTAssertNil(store.state.streakAfterToday)
    }
}
