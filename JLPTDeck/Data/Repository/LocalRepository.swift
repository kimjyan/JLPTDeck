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

    /// Returns up to `count` other cards at the same level, distinct from `excluding`
    /// AND distinct from each other by `gloss_ko` (so distractors don't share a meaning).
    /// Useful for building 4-choice MCQ questions.
    func distractorCards(level: JLPTLevel, excluding: UUID, count: Int) throws -> [VocabCard]

    /// Returns VocabCards that have a SRSState with lapses > 0, paired with that SRSState.
    /// Sorted by `lastReview` descending (nil last). Filter by the given JLPT level.
    func mistakenCards(level: JLPTLevel) throws -> [(VocabCard, SRSState)]

    /// F8: hide / unhide a single card. Idempotent — repeated calls with the
    /// same value are no-ops.
    func setHidden(cardID: UUID, hidden: Bool) throws

    /// F8: returns the set of cardIDs the user has marked as hidden.
    /// Used by the scheduler to filter `todayReviewCards`.
    func hiddenCardIDs() throws -> Set<UUID>

    /// F13: snapshot SRSState + UserOverride into the JSON-export DTO.
    /// Caller wraps with metadata (timestamp, app version, schemaVersion).
    func exportSnapshot() throws -> (srs: [SRSStateExport], overrides: [UserOverrideExport])

    /// F13: replace SRS / UserOverride rows with the imported payload's
    /// contents. Upsert by cardID — existing rows are overwritten, missing
    /// ones inserted, rows not in the payload are LEFT ALONE (so a user can
    /// restore a partial backup without wiping unrelated progress).
    func importSnapshot(srs: [SRSStateExport], overrides: [UserOverrideExport]) throws

    /// F15: record a single app-open event with the given timestamp.
    /// Best-effort persistence — failure is non-fatal (logged via thrown error
    /// at the call site if surfaced).
    func recordAppOpen(at date: Date) throws

    /// F15: read all app-open event dates (any order). Caller passes through
    /// `RetentionStats.snapshot(...)` to derive D1/D7.
    func appOpenEventDates() throws -> [Date]
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

        // F8: drop cards the user has marked as hidden. Pure helper lives in
        // Domain so the filter logic is unit-tested without SwiftData.
        let hidden = FeatureFlags.cardOverride
            ? ((try? hiddenCardIDs()) ?? [])
            : []
        let visibleCards = HiddenCardFilter.apply(
            cards: cards,
            hiddenIDs: hidden,
            idOf: { $0.id }
        )

        return visibleCards.map { card in
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

    func mistakenCards(level: JLPTLevel) throws -> [(VocabCard, SRSState)] {
        // Swift 6.2 note: `#Predicate { $0.lapses > 0 }` can be brittle under
        // Approachable Concurrency macro expansion. Since the SRSState table is
        // bounded by learned cards (much smaller than the card pool), full-fetch
        // + Swift filter is simple and safe.
        let levelRaw = level.rawValue
        let states: [SRSState]
        let cards: [VocabCard]
        do {
            let stateDescriptor = FetchDescriptor<SRSState>()
            let allStates = try modelContext.fetch(stateDescriptor)
            states = allStates.filter { $0.lapses > 0 }

            guard !states.isEmpty else { return [] }

            let cardDescriptor = FetchDescriptor<VocabCard>(
                predicate: #Predicate { $0.jlptLevel == levelRaw }
            )
            cards = try modelContext.fetch(cardDescriptor)
        } catch {
            throw RepositoryError.persistenceFailure(error)
        }

        var stateByCardID: [UUID: SRSState] = [:]
        stateByCardID.reserveCapacity(states.count)
        for state in states {
            stateByCardID[state.cardID] = state
        }

        var pairs: [(VocabCard, SRSState)] = []
        pairs.reserveCapacity(states.count)
        for card in cards {
            if let state = stateByCardID[card.id] {
                pairs.append((card, state))
            }
        }

        // Sort by lastReview descending, nil last.
        pairs.sort { lhs, rhs in
            switch (lhs.1.lastReview, rhs.1.lastReview) {
            case let (l?, r?): return l > r
            case (_?, nil):    return true
            case (nil, _?):    return false
            case (nil, nil):   return false
            }
        }
        return pairs
    }

    func distractorCards(level: JLPTLevel, excluding: UUID, count: Int) throws -> [VocabCard] {
        guard count > 0 else { return [] }
        let pool = try cards(for: level)              // existing method, fetches all at level
        var seenGlossKo: Set<String> = []
        var picks: [VocabCard] = []
        let shuffled = pool.shuffled()
        for card in shuffled {
            if card.id == excluding { continue }
            // Skip cards with empty gloss_ko (untranslated). Otherwise dedup by gloss_ko.
            let key = card.gloss_ko
            if key.isEmpty { continue }
            if seenGlossKo.contains(key) { continue }
            seenGlossKo.insert(key)
            picks.append(card)
            if picks.count == count { break }
        }
        return picks
    }

    func setHidden(cardID: UUID, hidden: Bool) throws {
        let descriptor = FetchDescriptor<UserOverride>(
            predicate: #Predicate { $0.cardID == cardID }
        )
        do {
            if let existing = try modelContext.fetch(descriptor).first {
                existing.isHidden = hidden
            } else {
                let row = UserOverride(cardID: cardID, isHidden: hidden)
                modelContext.insert(row)
            }
            try modelContext.save()
        } catch {
            throw RepositoryError.persistenceFailure(error)
        }
    }

    func hiddenCardIDs() throws -> Set<UUID> {
        do {
            let rows = try modelContext.fetch(FetchDescriptor<UserOverride>())
            return Set(rows.compactMap { $0.isHidden ? $0.cardID : nil })
        } catch {
            throw RepositoryError.persistenceFailure(error)
        }
    }

    func exportSnapshot() throws -> (srs: [SRSStateExport], overrides: [UserOverrideExport]) {
        do {
            let srs = try modelContext.fetch(FetchDescriptor<SRSState>()).map { s in
                SRSStateExport(
                    cardID: s.cardID,
                    ease: s.ease,
                    intervalDays: s.intervalDays,
                    reps: s.reps,
                    lapses: s.lapses,
                    lastReviewUnix: s.lastReview?.timeIntervalSince1970,
                    dueDateUnix: s.dueDate.timeIntervalSince1970
                )
            }
            let overrides = try modelContext.fetch(FetchDescriptor<UserOverride>()).map { o in
                UserOverrideExport(cardID: o.cardID, isHidden: o.isHidden, note: o.note)
            }
            return (srs, overrides)
        } catch {
            throw RepositoryError.persistenceFailure(error)
        }
    }

    func recordAppOpen(at date: Date) throws {
        do {
            modelContext.insert(AppOpenEvent(date: date))
            try modelContext.save()
        } catch {
            throw RepositoryError.persistenceFailure(error)
        }
    }

    func appOpenEventDates() throws -> [Date] {
        do {
            return try modelContext.fetch(FetchDescriptor<AppOpenEvent>()).map { $0.date }
        } catch {
            throw RepositoryError.persistenceFailure(error)
        }
    }

    func importSnapshot(srs: [SRSStateExport], overrides: [UserOverrideExport]) throws {
        do {
            for export in srs {
                let cardID = export.cardID
                let descriptor = FetchDescriptor<SRSState>(
                    predicate: #Predicate { $0.cardID == cardID }
                )
                let row = try modelContext.fetch(descriptor).first ?? {
                    let fresh = SRSState(cardID: cardID)
                    modelContext.insert(fresh)
                    return fresh
                }()
                row.ease = export.ease
                row.intervalDays = export.intervalDays
                row.reps = export.reps
                row.lapses = export.lapses
                row.lastReview = export.lastReviewUnix.map { Date(timeIntervalSince1970: $0) }
                row.dueDate = Date(timeIntervalSince1970: export.dueDateUnix)
            }
            for export in overrides {
                let cardID = export.cardID
                let descriptor = FetchDescriptor<UserOverride>(
                    predicate: #Predicate { $0.cardID == cardID }
                )
                if let existing = try modelContext.fetch(descriptor).first {
                    existing.isHidden = export.isHidden
                    existing.note = export.note
                } else {
                    modelContext.insert(UserOverride(
                        cardID: cardID, isHidden: export.isHidden, note: export.note
                    ))
                }
            }
            try modelContext.save()
        } catch {
            throw RepositoryError.persistenceFailure(error)
        }
    }
}
