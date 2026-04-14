import ComposableArchitecture
import Foundation

private nonisolated enum ReviewSessionCancelID: Hashable, Sendable {
    case loadToday
    case autoAdvance
    case upsert(UUID)   // per-card so concurrent grades can coexist
}

@Reducer
struct ReviewSessionFeature {

    @ObservableState
    struct State: Equatable {
        var queue: [VocabCardDTO] = []
        var index: Int = 0
        var srsByCardID: [UUID: SRSSnapshot] = [:]
        /// Pre-fetched at session start. Each entry is one possible distractor.
        /// Per-card we filter and pick 3 from this pool.
        var distractorPool: [VocabCardDTO] = []
        /// Stored — DO NOT compute on every render. Random pick at advance time
        /// then frozen until the next card.
        var currentQuestion: QuizQuestion? = nil
        var selectedAnswerIndex: Int? = nil
        var isAnswerRevealed: Bool = false
        var lastAnswerWasCorrect: Bool? = nil
        var loadError: String? = nil
        /// View-side bridge for `.delegate(.requestClose)`. The View observes this
        /// via `onChange` to call its `onClose` closure. Phase 4 will replace this
        /// with parent reducer composition (RootFeature listening to the delegate).
        var delegateRequestedClose: Bool = false

        var isComplete: Bool { index >= queue.count }
        var currentCard: VocabCardDTO? { isComplete ? nil : queue[index] }
    }

    enum Action: Equatable {
        case view(ViewAction)
        case `internal`(InternalAction)
        case delegate(DelegateAction)

        @CasePathable
        enum ViewAction: Equatable {
            case task(level: JLPTLevel, limit: Int)   // .task on appear
            case answerTapped(Int)
            case closeTapped
        }
        @CasePathable
        enum InternalAction: Equatable {
            case loadResult(Result<LoadPayload, EquatableError>)
            case autoAdvanceFired
            case upsertFailed(String)
        }
        @CasePathable
        enum DelegateAction: Equatable {
            case requestClose
        }

        struct LoadPayload: Equatable, @unchecked Sendable {
            let queue: [VocabCardDTO]
            let srs: [UUID: SRSSnapshot]
            let distractors: [VocabCardDTO]
        }
    }

    @Dependency(\.localRepository) var repo
    @Dependency(\.continuousClock) var clock
    @Dependency(\.date) var date

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .view(.task(level, limit)):
                return loadEffect(level: level, limit: limit)

            case let .view(.answerTapped(idx)):
                guard !state.isAnswerRevealed,
                      let q = state.currentQuestion,
                      let card = state.currentCard else { return .none }
                state.selectedAnswerIndex = idx
                state.isAnswerRevealed = true
                let isCorrect = idx == q.correctIndex
                state.lastAnswerWasCorrect = isCorrect

                let quality: SRSQuality = isCorrect ? .good : .again
                let now = date.now
                let snapshot = state.srsByCardID[card.id] ?? SRSSnapshot(
                    cardID: card.id, ease: 2.5, intervalDays: 0, reps: 0,
                    lapses: 0, lastReview: nil, dueDate: now
                )
                let update = SM2.nextState(current: snapshot, quality: quality, now: now)
                state.srsByCardID[card.id] = SRSSnapshot(
                    cardID: card.id,
                    ease: update.ease,
                    intervalDays: update.intervalDays,
                    reps: update.reps,
                    lapses: update.lapses,
                    lastReview: now,
                    dueDate: update.dueDate
                )
                let cardID = card.id
                return .merge(
                    .run { [repo] send in
                        do {
                            try await repo.upsertSRS(cardID, update, now)
                        } catch {
                            await send(.internal(.upsertFailed(String(describing: error))))
                        }
                    }
                    .cancellable(id: ReviewSessionCancelID.upsert(cardID), cancelInFlight: true),
                    .run { [clock] send in
                        try? await clock.sleep(for: .milliseconds(1200))
                        await send(.internal(.autoAdvanceFired))
                    }
                    .cancellable(id: ReviewSessionCancelID.autoAdvance, cancelInFlight: true)
                )

            case .view(.closeTapped):
                // Simpler approach per plan: flip the bridge flag directly AND fire
                // the delegate for future parent composition (Phase 4).
                state.delegateRequestedClose = true
                return .merge(
                    .cancel(id: ReviewSessionCancelID.autoAdvance),
                    .send(.delegate(.requestClose))
                )

            case let .internal(.loadResult(.success(payload))):
                state.queue = payload.queue
                state.srsByCardID = payload.srs
                state.distractorPool = payload.distractors
                state.index = 0
                state.selectedAnswerIndex = nil
                state.isAnswerRevealed = false
                state.lastAnswerWasCorrect = nil
                state.loadError = nil
                regenerateQuestion(state: &state)
                return .none

            case let .internal(.loadResult(.failure(err))):
                state.loadError = err.message
                return .none

            case .internal(.autoAdvanceFired):
                state.index += 1
                state.selectedAnswerIndex = nil
                state.isAnswerRevealed = false
                state.lastAnswerWasCorrect = nil
                regenerateQuestion(state: &state)
                return .none

            case let .internal(.upsertFailed(msg)):
                // Non-fatal — keep going, but log to error state for surfacing.
                state.loadError = "save failed: \(msg)"
                return .none

            case .delegate:
                return .none
            }
        }
    }

    private func loadEffect(level: JLPTLevel, limit: Int) -> Effect<Action> {
        let nowSnapshot = date.now
        return .run { [repo] send in
            do {
                let pairs = try await repo.todayReviewCards(limit, level, nowSnapshot)
                var due: [SRSSnapshot] = []
                var newIDs: [UUID] = []
                var byID: [UUID: VocabCardDTO] = [:]
                var srs: [UUID: SRSSnapshot] = [:]
                for pair in pairs {
                    byID[pair.card.id] = pair.card
                    if let s = pair.srs {
                        due.append(s)
                        srs[pair.card.id] = s
                    } else {
                        newIDs.append(pair.card.id)
                    }
                }
                let pickedIDs = CardScheduler.pickToday(due: due, newCardIDs: newIDs, limit: limit, now: nowSnapshot)
                let queue = pickedIDs.compactMap { byID[$0] }

                let distractors = try await repo.distractorCards(level, UUID(), max(20, limit * 4))

                let payload = Action.LoadPayload(queue: queue, srs: srs, distractors: distractors)
                await send(.internal(.loadResult(.success(payload))))
            } catch {
                await send(.internal(.loadResult(.failure(.init(error)))))
            }
        }
        .cancellable(id: ReviewSessionCancelID.loadToday, cancelInFlight: true)
    }

    /// Pure-ish: picks 3 distractor glosses from pool, dedups by gloss_ko, calls QuizGenerator.
    /// Uses SystemRandomNumberGenerator inline — we accept non-determinism here for live play.
    /// Tests can be deterministic by injecting via TestStore with a controlled clock and
    /// asserting only on shape (count == 4, correctChoice presence) not order.
    private func regenerateQuestion(state: inout State) {
        guard let card = state.currentCard else {
            state.currentQuestion = nil
            return
        }
        var seen: Set<String> = [card.gloss_ko]
        var picks: [String] = []
        for d in state.distractorPool.shuffled() {
            if d.id == card.id { continue }
            if d.gloss_ko.isEmpty { continue }
            if seen.contains(d.gloss_ko) { continue }
            seen.insert(d.gloss_ko)
            picks.append(d.gloss_ko)
            if picks.count == 3 { break }
        }
        var rng = SystemRandomNumberGenerator()
        state.currentQuestion = QuizGenerator.make(
            input: .init(cardID: card.id, headword: card.headword, reading: card.reading, glossKo: card.gloss_ko),
            distractors: picks,
            rng: &rng
        )
    }
}
