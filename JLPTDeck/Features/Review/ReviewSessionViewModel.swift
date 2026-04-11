import Foundation
import Observation

@Observable
final class ReviewSessionViewModel {
    var queue: [VocabCard] = []
    var index: Int = 0
    var showBack: Bool = false
    var errorMessage: String?

    var isComplete: Bool { index >= queue.count }
    var currentCard: VocabCard? {
        isComplete ? nil : queue[index]
    }
    var completedCount: Int { queue.count }

    private let repo: LocalRepository
    private var stateByCardID: [UUID: SRSState] = [:]

    init(repo: LocalRepository) {
        self.repo = repo
    }

    @MainActor
    func loadToday(level: JLPTLevel, limit: Int) async throws {
        let now = Date()
        let pairs = try repo.todayReviewCards(limit: limit, level: level, now: now)

        var due: [SRSSnapshot] = []
        var newIDs: [UUID] = []
        var cardByID: [UUID: VocabCard] = [:]
        var states: [UUID: SRSState] = [:]

        for (card, state) in pairs {
            cardByID[card.id] = card
            if let state {
                due.append(state.snapshot())
                states[card.id] = state
            } else {
                newIDs.append(card.id)
            }
        }

        let picks = CardScheduler.pickToday(
            due: due,
            newCardIDs: newIDs,
            limit: limit,
            now: now
        )

        self.stateByCardID = states
        self.queue = picks.compactMap { cardByID[$0] }
        self.index = 0
        self.showBack = false
    }

    func flip() {
        showBack.toggle()
    }

    func grade(_ quality: SRSQuality) throws {
        guard let card = currentCard else { return }
        let now = Date()

        let currentSnapshot: SRSSnapshot
        if let existing = stateByCardID[card.id] {
            currentSnapshot = existing.snapshot()
        } else {
            currentSnapshot = SRSSnapshot(
                cardID: card.id,
                ease: 2.5,
                intervalDays: 0,
                reps: 0,
                lapses: 0,
                lastReview: nil,
                dueDate: now
            )
        }

        let update = SM2.nextState(current: currentSnapshot, quality: quality, now: now)
        try repo.upsertSRS(cardID: card.id, update: update, now: now)

        index += 1
        showBack = false
    }
}
