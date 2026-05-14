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
        var correctCount: Int = 0
        var wrongCount: Int = 0
        /// F3: IDs of cards that already had their first-attempt SRS write in this
        /// session AND were re-queued for in-session re-exposure. Subsequent
        /// answers for these cards do NOT update SRS state when
        /// `FeatureFlags.relearnSeparated` is true.
        var relearnedCardIDs: Set<UUID> = []
        /// F3: Count of recovered re-attempts (got it right on the second pass
        /// within the session). Display-only; does not affect SRS.
        var relearnedCount: Int = 0
        /// F4: Number of `upsertSRS` failures observed in this session. Each
        /// failure is also enqueued to the persisted retry queue so it can be
        /// re-attempted at the next session boundary. Surfaced in
        /// `SessionCompleteView` so users see how many writes were deferred.
        var failedUpsertCount: Int = 0
        /// F8: Number of `setHidden` persistence failures in this session.
        /// Card vanished from the in-memory queue but failed to persist —
        /// will reappear next session. Surfaced in `SessionCompleteView`.
        var hideFailedCount: Int = 0
        /// F9: Timestamp at which the current question was last presented.
        /// Used to compute response latency in milliseconds when the user
        /// taps an answer. nil if no question is showing yet.
        var currentQuestionPresentedAt: Date? = nil
        /// F9: Card IDs whose first-attempt correct answer was "slow"
        /// (latency >= LatencyPolicy.slowThresholdMs). Display-only —
        /// SM-2 scheduling is NOT affected.
        var slowFirstAttemptIDs: Set<UUID> = []
        /// F9 rev2: per-attempt latency records — captured for EVERY
        /// `answerTapped` (correct/wrong, first/retry). Used by the
        /// SessionComplete count display today and as the input for the
        /// v1.x A/B threshold-tuning analysis (PLAN L18).
        var responseLatencies: [ResponseLatencyRecord] = []
        /// F7 (G-SessionComplete): JLPT level used to load this session.
        /// Captured at `.task` so the next-day preview effect can re-query
        /// the repository for tomorrow's due count when the session ends.
        /// nil for the focused-review (preloaded) entry path.
        var sessionLevel: JLPTLevel? = nil
        /// F7 (G-SessionComplete): daily limit used to load this session.
        var sessionLimit: Int = 20
        /// F7 (G-SessionComplete): cached count of cards that will be due
        /// tomorrow. nil = not yet computed (effect in flight or focused-
        /// review session). Refreshed when the session transitions to
        /// `isComplete` so it reflects today's SRS upserts (best-effort —
        /// races with in-flight upserts are accepted; ±a few cards is
        /// acceptable for motivational copy).
        var nextDayDueCount: Int? = nil
        /// F7 (G-SessionComplete): streak count AFTER today's session is
        /// counted. Computed from `userSettings.loadStreak` +
        /// `loadLastStudyDate` so the SessionComplete view can show "오늘
        /// 학습으로 N일 연속" without waiting for the actual streak update
        /// that happens on session close in `RootFeature`. nil = not yet
        /// computed.
        var streakAfterToday: Int? = nil
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
            case taskWithPreloaded(queue: [VocabCardDTO], srs: [UUID: SRSSnapshot], distractors: [VocabCardDTO])
            case answerTapped(Int)
            case closeTapped
            /// F8: hide the current card and advance to the next.
            case hideCurrentCardTapped
            /// F9 rev2: SwiftUI scenePhase entered background/inactive. Drop
            /// `currentQuestionPresentedAt` so the next answer's latency is
            /// not polluted by the time the app spent suspended.
            case scenePhaseBackgrounded
        }
        @CasePathable
        enum InternalAction: Equatable {
            case loadResult(Result<LoadPayload, EquatableError>)
            case autoAdvanceFired
            case upsertFailed(String)
            /// F8: `setHidden` persistence failed; bump `hideFailedCount`.
            case hidePersistenceFailed
            /// F7 (G-SessionComplete): session preview computed.
            /// `nextDayDue` is a snapshot of cards whose dueDate is on or
            /// before tomorrow's start-of-day; `streakAfterToday` is the
            /// streak the user will land on after today's session is
            /// counted (peek-only, does not mutate UserSettings).
            case sessionPreviewLoaded(nextDayDue: Int, streakAfterToday: Int)
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
    @Dependency(\.upsertRetry) var upsertRetry
    @Dependency(\.userSettings) var userSettings

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .view(.taskWithPreloaded(queue, srs, distractors)):
                state.queue = queue
                state.srsByCardID = srs
                state.distractorPool = distractors
                state.index = 0
                state.selectedAnswerIndex = nil
                state.isAnswerRevealed = false
                state.lastAnswerWasCorrect = nil
                state.correctCount = 0
                state.wrongCount = 0
                state.relearnedCardIDs = []
                state.relearnedCount = 0
                state.failedUpsertCount = 0
                state.hideFailedCount = 0
                state.slowFirstAttemptIDs = []
                state.responseLatencies = []
                state.currentQuestionPresentedAt = nil
                state.nextDayDueCount = nil
                state.streakAfterToday = nil
                state.loadError = nil
                state.delegateRequestedClose = false
                regenerateQuestion(state: &state)
                // Kill any in-flight regular loadEffect so a late
                // .internal(.loadResult(.success)) can't overwrite the
                // preloaded queue (focused-review race fix).
                return .merge(
                    .cancel(id: ReviewSessionCancelID.loadToday),
                    drainRetryQueueEffect()
                )

            case let .view(.task(level, limit)):
                // Focused-review preload already populated the queue; skip
                // the regular repo fetch to avoid overwriting it.
                guard state.queue.isEmpty else { return .none }
                state.sessionLevel = level
                state.sessionLimit = limit
                return loadEffect(level: level, limit: limit)

            case let .view(.answerTapped(idx)):
                guard !state.isAnswerRevealed,
                      let q = state.currentQuestion,
                      let card = state.currentCard else { return .none }
                state.selectedAnswerIndex = idx
                state.isAnswerRevealed = true
                let isCorrect = idx == q.correctIndex
                state.lastAnswerWasCorrect = isCorrect

                // F9 rev2: compute latency BEFORE branching so retry path
                // also gets recorded. SM-2 input never reads these values.
                let isRetry = !RelearnPolicy.shouldUpdateSRS(
                    cardID: card.id,
                    relearnedIDs: state.relearnedCardIDs,
                    flagEnabled: FeatureFlags.relearnSeparated
                )
                if FeatureFlags.responseLatencyTracking {
                    let latency = LatencyPolicy.latencyMs(
                        presentedAt: state.currentQuestionPresentedAt,
                        now: date.now
                    )
                    let slow = LatencyPolicy.isSlow(latencyMs: latency)
                    state.responseLatencies.append(ResponseLatencyRecord(
                        cardID: card.id,
                        latencyMs: latency,
                        isCorrect: isCorrect,
                        isFirstAttempt: !isRetry,
                        isSlow: slow
                    ))
                    // Existing display-only set: only first-attempt correct
                    // slow answers (the "likely guess" heuristic).
                    if !isRetry && isCorrect && slow {
                        state.slowFirstAttemptIDs.insert(card.id)
                    }
                }

                // F3: same-session re-attempt path. Skip SRS write entirely so
                // the original failure is preserved on the long-term schedule.
                if isRetry {
                    if isCorrect { state.relearnedCount += 1 }
                    return .run { [clock] send in
                        try? await clock.sleep(for: .milliseconds(1200))
                        await send(.internal(.autoAdvanceFired))
                    }
                    .cancellable(id: ReviewSessionCancelID.autoAdvance, cancelInFlight: true)
                }

                if isCorrect { state.correctCount += 1 } else { state.wrongCount += 1 }

                let quality: SRSQuality = isCorrect ? .good : .again
                let now = date.now
                let snapshot = state.srsByCardID[card.id] ?? SRSSnapshot(
                    cardID: card.id, ease: 2.5, intervalDays: 0, reps: 0,
                    lapses: 0, lastReview: nil, dueDate: now
                )
                let update = SM2.nextState(current: snapshot, quality: quality, now: now)
                // Optimistic: update in-memory SRS state immediately. If upsertSRS
                // fails, the disk state lags behind until the next app launch reloads
                // from SwiftData. Acceptable for a learning app — no financial risk.
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
                    .run { [repo, upsertRetry] send in
                        do {
                            try await repo.upsertSRS(cardID, update, now)
                        } catch {
                            // F4: persist failed upsert so the next session
                            // can retry it. Effect-side enqueue keeps the
                            // action signature unchanged.
                            if FeatureFlags.upsertRetry {
                                let item = UpsertRetryItem(
                                    cardID: cardID,
                                    ease: update.ease,
                                    intervalDays: update.intervalDays,
                                    reps: update.reps,
                                    lapses: update.lapses,
                                    dueDate: update.dueDate,
                                    now: now
                                )
                                upsertRetry.enqueue(item)
                            }
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

            case .view(.hideCurrentCardTapped):
                // F8: hide the current card, drop it from the in-memory queue
                // (and any future re-queue), then advance. We do NOT mutate
                // SRS state. Failure to persist the hide is non-blocking —
                // user just sees the card again next session.
                guard FeatureFlags.cardOverride, let card = state.currentCard else { return .none }
                let cardID = card.id
                // Remove all queued occurrences (including F3 re-queue).
                state.queue.removeAll { $0.id == cardID }
                state.relearnedCardIDs.remove(cardID)
                state.selectedAnswerIndex = nil
                state.isAnswerRevealed = false
                state.lastAnswerWasCorrect = nil
                regenerateQuestion(state: &state)
                return .merge(
                    .cancel(id: ReviewSessionCancelID.autoAdvance),
                    .run { [repo] send in
                        do {
                            try await repo.setHidden(cardID, true)
                        } catch {
                            // F8 rev2: surface persistence failure via counter
                            // (non-blocking — same pattern as F4 upsertFailed).
                            await send(.internal(.hidePersistenceFailed))
                        }
                    }
                )

            case .view(.scenePhaseBackgrounded):
                // F9 rev2: drop the timestamp so the next answer's latency
                // is not polluted by background-suspended time. The next
                // `regenerateQuestion` call (or no-op if user just resumed
                // mid-question) re-stamps if appropriate.
                state.currentQuestionPresentedAt = nil
                return .none

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
                state.correctCount = 0
                state.wrongCount = 0
                state.relearnedCardIDs = []
                state.relearnedCount = 0
                state.failedUpsertCount = 0
                state.hideFailedCount = 0
                state.slowFirstAttemptIDs = []
                state.responseLatencies = []
                state.currentQuestionPresentedAt = nil
                state.nextDayDueCount = nil
                state.streakAfterToday = nil
                state.loadError = nil
                regenerateQuestion(state: &state)
                // F7: if the queue is empty (zero-card session edge case),
                // we'll never hit autoAdvanceFired → fire the preview now.
                if FeatureFlags.sessionCompleteCoaching && state.isComplete,
                   let level = state.sessionLevel {
                    return .merge(
                        drainRetryQueueEffect(),
                        sessionPreviewEffect(level: level, limit: state.sessionLimit)
                    )
                }
                return drainRetryQueueEffect()

            case let .internal(.loadResult(.failure(err))):
                state.loadError = err.message
                return .none

            case .internal(.autoAdvanceFired):
                // Re-queue wrong cards at the end so the user gets another
                // attempt within the same session (immediate re-exposure).
                if state.lastAnswerWasCorrect == false, let card = state.currentCard {
                    state.queue.append(card)
                    if FeatureFlags.relearnSeparated {
                        // F3: mark the re-queued card so its second answer
                        // skips the SRS update path.
                        state.relearnedCardIDs.insert(card.id)
                    }
                }
                state.index += 1
                state.selectedAnswerIndex = nil
                state.isAnswerRevealed = false
                state.lastAnswerWasCorrect = nil
                regenerateQuestion(state: &state)
                // F7: when the session has just transitioned to complete and
                // the regular load path captured a level, fetch tomorrow's
                // due count + the streak peek so SessionCompleteView can
                // render motivational copy. Focused-review (taskWithPreloaded
                // → no level) silently skips this — the preview block hides.
                if FeatureFlags.sessionCompleteCoaching && state.isComplete,
                   let level = state.sessionLevel {
                    return sessionPreviewEffect(level: level, limit: state.sessionLimit)
                }
                return .none

            case let .internal(.sessionPreviewLoaded(due, streakAfter)):
                state.nextDayDueCount = due
                state.streakAfterToday = streakAfter
                return .none

            case .internal(.hidePersistenceFailed):
                // Card already gone from in-memory queue; persistence retry
                // is not implemented (v1.x). Counter for SessionComplete.
                state.hideFailedCount += 1
                return .none

            case .internal(.upsertFailed):
                // F4 (rev3): SRS save failure is non-fatal AND non-blocking.
                // We persist the failed write to the retry queue (effect-side)
                // and bump the counter for SessionComplete display. We do NOT
                // set `loadError` here — `loadError` drives the view-level
                // errorState that blocks the entire quiz flow, and a per-card
                // save failure must not collapse the session UI.
                //
                // `loadError` is reserved for fatal load failures coming from
                // `.loadResult(.failure)`.
                state.failedUpsertCount += 1
                return .none

            case .delegate:
                return .none
            }
        }
    }

    /// F7 (G-SessionComplete): compute next-day due count + the streak the
    /// user will land on after today's session is counted. Both reads are
    /// non-mutating (the actual streak update happens on session close in
    /// `RootFeature` via `userSettings.updateStreak`). Errors degrade to
    /// `nextDayDue = 0` so the UI shows a sensible-but-conservative number.
    private func sessionPreviewEffect(level: JLPTLevel, limit: Int) -> Effect<Action> {
        let nowSnapshot = date.now
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: nowSnapshot) ?? nowSnapshot
        return .run { [repo, userSettings] send in
            var nextDayDue = 0
            do {
                let pairs = try await repo.todayReviewCards(limit, level, tomorrow)
                var due: [SRSSnapshot] = []
                var newIDs: [UUID] = []
                for pair in pairs {
                    if let s = pair.srs {
                        due.append(s)
                    } else {
                        newIDs.append(pair.card.id)
                    }
                }
                let picks = CardScheduler.pickToday(
                    due: due, newCardIDs: newIDs, limit: limit, now: tomorrow
                )
                nextDayDue = picks.count
            } catch {
                nextDayDue = 0
            }

            // Peek-only streak calculation. Mirror the live update logic in
            // `UserSettingsClient.updateStreak` but do NOT write — the close
            // path (RootFeature delegate) is the single mutation site so we
            // don't double-count when the user re-opens SessionComplete.
            let cur = userSettings.loadStreak()
            let last = userSettings.loadLastStudyDate()
            let today = calendar.startOfDay(for: nowSnapshot)
            let lastDay = last.map { calendar.startOfDay(for: $0) }
            let afterToday: Int
            if lastDay == today {
                afterToday = max(cur, 1)
            } else if let lastDay,
                      calendar.date(byAdding: .day, value: 1, to: lastDay) == today {
                afterToday = cur + 1
            } else {
                afterToday = 1
            }

            await send(.internal(.sessionPreviewLoaded(
                nextDayDue: nextDayDue,
                streakAfterToday: afterToday
            )))
        }
    }

    /// F4: best-effort retry of previously failed upserts. Side-effect only;
    /// does not feed actions back into the reducer (so it does not mutate
    /// `failedUpsertCount` or `loadError`). Items that succeed are removed
    /// from the persisted queue; failures stay queued for the next session.
    ///
    /// We snapshot the queue synchronously here (so callers that find an empty
    /// queue can skip the effect entirely and avoid capturing `repo` — which
    /// would force test contexts to provide a `localRepository` test impl
    /// even when no drain is needed).
    private func drainRetryQueueEffect() -> Effect<Action> {
        guard FeatureFlags.upsertRetry else { return .none }
        let pending = upsertRetry.list()
        guard !pending.isEmpty else { return .none }
        return .run { [repo, upsertRetry] _ in
            await UpsertRetryDrain.drain(
                items: pending,
                upsertSRS: { id, update, now in
                    try await repo.upsertSRS(id, update, now)
                },
                onSuccess: { id in upsertRetry.remove(id) }
            )
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
                // Daily-limit cap: subtract cards already reviewed today
                // so a second session on the same calendar day does NOT
                // pick another full batch of `limit` new cards.
                let alreadyToday = CardScheduler.reviewedTodayCount(
                    states: due, now: nowSnapshot
                )
                let pickedIDs = CardScheduler.pickToday(
                    due: due,
                    newCardIDs: newIDs,
                    limit: limit,
                    now: nowSnapshot,
                    alreadyReviewedToday: alreadyToday
                )
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
    ///
    /// Side effect (F9): stamps `currentQuestionPresentedAt` with `date.now`
    /// when a fresh question is generated, so `answerTapped` can compute
    /// response latency. Cleared to nil when no card remains (session done).
    private func regenerateQuestion(state: inout State) {
        guard let card = state.currentCard else {
            state.currentQuestion = nil
            state.currentQuestionPresentedAt = nil
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
            input: .init(
                cardID: card.id,
                headword: card.headword,
                reading: card.reading,
                glossKo: card.gloss_ko,
                pos: card.pos
            ),
            distractors: picks,
            rng: &rng
        )
        if FeatureFlags.responseLatencyTracking {
            state.currentQuestionPresentedAt = date.now
        }
    }
}
