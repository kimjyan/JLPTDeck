import Foundation
import SwiftData

/// Abstraction over the local SwiftData store used by feature code.
///
/// Task 1 owns `SRSState` / `SRSUpdate` / `CardScheduler`; those types are referenced
/// by this protocol and its concrete implementation but are defined in the Domain layer.
protocol LocalRepository {
    func importIfNeeded() async throws

    func cards(for level: JLPTLevel) throws -> [VocabCard]

    /// Returns cards paired with their SRS state (nil == brand-new card).
    /// Caller feeds these to `CardScheduler` to pick/order. The returned list
    /// is unsorted and intentionally loose on `limit` — see the implementation
    /// note in `SwiftDataLocalRepository.todayReviewCards` for the memory cap policy.
    func todayReviewCards(
        limit: Int,
        level: JLPTLevel,
        now: Date
    ) throws -> [(VocabCard, SRSState?)]

    func upsertSRS(cardID: UUID, update: SRSUpdate, now: Date) throws
}

final class SwiftDataLocalRepository: LocalRepository {
    private let modelContext: ModelContext
    private let bundle: Bundle

    init(modelContext: ModelContext, bundle: Bundle = .main) {
        self.modelContext = modelContext
        self.bundle = bundle
    }

    func importIfNeeded() async throws {
        let importer = JMdictImporter(modelContext: modelContext, bundle: bundle)
        try await importer.importIfNeeded()
    }

    func cards(for level: JLPTLevel) throws -> [VocabCard] {
        let levelRaw = level.rawValue
        let descriptor = FetchDescriptor<VocabCard>(
            predicate: #Predicate { $0.jlptLevel == levelRaw },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            throw RepositoryError.persistenceFailure(error)
        }
    }

    /// Memory cap policy: we cap the fetched candidate pool at `limit * 3` so that
    /// very large decks (5k+ cards) never get fully loaded into memory. Task 3's
    /// `CardScheduler` picks and orders the final session from this candidate slice.
    /// The cap is a soft hint — callers that truly need the full deck should use
    /// `cards(for:)` directly.
    func todayReviewCards(
        limit: Int,
        level: JLPTLevel,
        now: Date
    ) throws -> [(VocabCard, SRSState?)] {
        let levelRaw = level.rawValue
        var cardDescriptor = FetchDescriptor<VocabCard>(
            predicate: #Predicate { $0.jlptLevel == levelRaw },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        cardDescriptor.fetchLimit = max(limit * 3, limit)

        let cards: [VocabCard]
        let states: [SRSState]
        do {
            cards = try modelContext.fetch(cardDescriptor)
            // Fetch all SRSState rows — this table is bounded by the number of
            // cards the user has actually reviewed, so it's much smaller than
            // the card pool in practice.
            let stateDescriptor = FetchDescriptor<SRSState>()
            states = try modelContext.fetch(stateDescriptor)
        } catch {
            throw RepositoryError.persistenceFailure(error)
        }

        var stateByCardID: [UUID: SRSState] = [:]
        stateByCardID.reserveCapacity(states.count)
        for state in states {
            stateByCardID[state.cardID] = state
        }

        return cards.map { card in
            (card, stateByCardID[card.id])
        }
    }

    func upsertSRS(cardID: UUID, update: SRSUpdate, now: Date) throws {
        let descriptor = FetchDescriptor<SRSState>(
            predicate: #Predicate { $0.cardID == cardID }
        )
        do {
            let existing = try modelContext.fetch(descriptor).first
            if let state = existing {
                state.apply(update, at: now)
            } else {
                let fresh = SRSState(cardID: cardID)
                modelContext.insert(fresh)
                fresh.apply(update, at: now)
            }
            try modelContext.save()
        } catch {
            throw RepositoryError.persistenceFailure(error)
        }
    }
}
