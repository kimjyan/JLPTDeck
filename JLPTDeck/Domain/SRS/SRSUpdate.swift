import Foundation

/// Immutable result of running the SM-2 step for a card.
/// Consumed by the data layer to mutate its persistent SRS state.
public struct SRSUpdate: Equatable {
    public let ease: Double
    public let intervalDays: Int
    public let reps: Int
    public let dueDate: Date
    public let lapses: Int

    public init(ease: Double, intervalDays: Int, reps: Int, dueDate: Date, lapses: Int) {
        self.ease = ease
        self.intervalDays = intervalDays
        self.reps = reps
        self.dueDate = dueDate
        self.lapses = lapses
    }
}
