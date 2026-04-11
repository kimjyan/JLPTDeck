import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class ReviewSessionViewModel {
    var queue: [VocabCard] = []
    var index: Int = 0
    var selectedAnswerIndex: Int? = nil
    var isAnswerRevealed: Bool = false
    var lastAnswerWasCorrect: Bool? = nil

    private(set) var currentQuestion: QuizQuestion? = nil

    private let repo: any LocalRepository
    private var stateByCardID: [UUID: SRSState] = [:]
    private var distractorPool: [VocabCard] = []
    private var questionCacheByCardID: [UUID: QuizQuestion] = [:]

    init(repo: any LocalRepository) { self.repo = repo }

    var isComplete: Bool { index >= queue.count }
    var currentCard: VocabCard? { isComplete ? nil : queue[index] }
    var completedCount: Int { queue.count }

    /// Loads today's queue and prefetches a distractor pool for the session.
    func loadToday(level: JLPTLevel, limit: Int) async throws {
        let now = Date()
        let pairs = try repo.todayReviewCards(limit: limit, level: level, now: now)

        var due: [SRSSnapshot] = []
        var newIDs: [UUID] = []
        var cardByID: [UUID: VocabCard] = [:]
        stateByCardID.removeAll()
        for (card, state) in pairs {
            cardByID[card.id] = card
            if let state {
                due.append(state.snapshot())
                stateByCardID[card.id] = state
            } else {
                newIDs.append(card.id)
            }
        }
        let pickedIDs = CardScheduler.pickToday(due: due, newCardIDs: newIDs, limit: limit, now: now)
        queue = pickedIDs.compactMap { cardByID[$0] }
        index = 0
        selectedAnswerIndex = nil
        isAnswerRevealed = false
        lastAnswerWasCorrect = nil
        questionCacheByCardID.removeAll()

        // Prefetch a distractor pool larger than the daily quota so each card has fresh choices.
        // We exclude a dummy UUID — actual exclusion happens per-card during question generation.
        distractorPool = try repo.distractorCards(level: level, excluding: UUID(), count: max(20, limit * 4))

        // Generate the first question if queue is non-empty.
        regenerateCurrentQuestion()
    }

    /// Regenerates `currentQuestion` for the card at `index`. Caches per cardID.
    private func regenerateCurrentQuestion() {
        guard let card = currentCard else {
            currentQuestion = nil
            return
        }
        if let cached = questionCacheByCardID[card.id] {
            currentQuestion = cached
            return
        }
        // Pick 3 distractor glosses from the pool, excluding the current card and dedup by gloss_ko
        var seen: Set<String> = [card.gloss_ko]
        var picks: [String] = []
        for d in distractorPool.shuffled() {
            if d.id == card.id { continue }
            if d.gloss_ko.isEmpty { continue }
            if seen.contains(d.gloss_ko) { continue }
            seen.insert(d.gloss_ko)
            picks.append(d.gloss_ko)
            if picks.count == 3 { break }
        }
        var rng = SystemRandomNumberGenerator()
        let q = QuizGenerator.make(
            input: .init(cardID: card.id, headword: card.headword, reading: card.reading, glossKo: card.gloss_ko),
            distractors: picks,
            rng: &rng
        )
        questionCacheByCardID[card.id] = q
        currentQuestion = q
    }

    /// User picked an answer. Reveals correctness, applies SM2 grade, schedules advance.
    func submitAnswer(_ choiceIndex: Int) {
        guard !isAnswerRevealed, let q = currentQuestion else { return }
        selectedAnswerIndex = choiceIndex
        isAnswerRevealed = true
        let isCorrect = choiceIndex == q.correctIndex
        lastAnswerWasCorrect = isCorrect
        let quality: SRSQuality = isCorrect ? .good : .again
        do {
            try gradeCurrent(quality: quality)
        } catch {
            // Persistence failure — surface via lastAnswerWasCorrect remaining set,
            // but log to console for now. UI can choose to retry.
            print("upsertSRS failed: \(error)")
        }
    }

    /// Advance to the next card. Called by the View after the reveal animation.
    func advance() {
        index += 1
        selectedAnswerIndex = nil
        isAnswerRevealed = false
        lastAnswerWasCorrect = nil
        regenerateCurrentQuestion()
    }

    private func gradeCurrent(quality: SRSQuality) throws {
        guard let card = currentCard else { return }
        let now = Date()
        let snapshot: SRSSnapshot
        if let existing = stateByCardID[card.id] {
            snapshot = existing.snapshot()
        } else {
            snapshot = SRSSnapshot(
                cardID: card.id, ease: 2.5, intervalDays: 0, reps: 0,
                lapses: 0, lastReview: nil, dueDate: now
            )
        }
        let update = SM2.nextState(current: snapshot, quality: quality, now: now)
        try repo.upsertSRS(cardID: card.id, update: update, now: now)
    }
}
