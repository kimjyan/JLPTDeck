import Foundation
import SwiftData

/// Persistent SRS state for a single card.
/// The domain layer (`SM2`, `CardScheduler`) operates on `SRSSnapshot` values
/// derived from this model, so SwiftData never leaks across the boundary.
@Model
final class SRSState {
    var cardID: UUID
    var ease: Double
    var intervalDays: Int
    var reps: Int
    var lapses: Int
    var lastReview: Date?
    var dueDate: Date

    init(
        cardID: UUID,
        ease: Double = 2.5,
        intervalDays: Int = 0,
        reps: Int = 0,
        lapses: Int = 0,
        lastReview: Date? = nil,
        dueDate: Date = Date()
    ) {
        self.cardID = cardID
        self.ease = ease
        self.intervalDays = intervalDays
        self.reps = reps
        self.lapses = lapses
        self.lastReview = lastReview
        self.dueDate = dueDate
    }
}

extension SRSState {
    /// Project this persistent model into a pure-Swift snapshot for the domain.
    func snapshot() -> SRSSnapshot {
        SRSSnapshot(
            cardID: cardID,
            ease: ease,
            intervalDays: intervalDays,
            reps: reps,
            lapses: lapses,
            lastReview: lastReview,
            dueDate: dueDate
        )
    }

    /// Mutate this state from a domain-produced update and stamp the review time.
    func apply(_ update: SRSUpdate, at now: Date) {
        self.ease = update.ease
        self.intervalDays = update.intervalDays
        self.reps = update.reps
        self.lapses = update.lapses
        self.dueDate = update.dueDate
        self.lastReview = now
    }
}
