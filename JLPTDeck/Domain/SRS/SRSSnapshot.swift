import Foundation

/// Pure-Swift read-only view of a card's SRS state.
/// The domain (SM2, CardScheduler) operates on snapshots so it does not
/// depend on SwiftData, enabling future KMP/Android ports.
public struct SRSSnapshot: Equatable {
    public let cardID: UUID
    public let ease: Double
    public let intervalDays: Int
    public let reps: Int
    public let lapses: Int
    public let lastReview: Date?
    public let dueDate: Date

    public init(
        cardID: UUID,
        ease: Double,
        intervalDays: Int,
        reps: Int,
        lapses: Int,
        lastReview: Date?,
        dueDate: Date
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
