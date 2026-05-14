import Foundation

/// Pure function that picks which cards to study today.
///
/// Policy:
/// 1. Subtract `alreadyReviewedToday` from `limit` to get the remaining
///    daily quota. The daily limit is a calendar-day cap: a session
///    of 20 followed by another session on the same day should yield 0
///    new picks, not another 20.
/// 2. From `due`, keep only cards whose `dueDate <= now`.
/// 3. Sort those ascending by `dueDate`.
/// 4. Take up to `remaining` of them.
/// 5. If fewer than `remaining` were picked, fill the remaining slots
///    from `newCardIDs` in the given order.
/// 6. Never exceed `remaining`. Never include future-dated cards.
public enum CardScheduler {
    public static func pickToday(
        due: [SRSSnapshot],
        newCardIDs: [UUID],
        limit: Int,
        now: Date,
        alreadyReviewedToday: Int = 0
    ) -> [UUID] {
        let remaining = max(0, limit - alreadyReviewedToday)
        guard remaining > 0 else { return [] }

        let readyDue = due
            .filter { $0.dueDate <= now }
            .sorted { $0.dueDate < $1.dueDate }

        let duePick = Array(readyDue.prefix(remaining)).map { $0.cardID }

        if duePick.count >= remaining {
            return duePick
        }

        let newPick = Array(newCardIDs.prefix(remaining - duePick.count))
        return duePick + newPick
    }

    /// Helper: count cards that were last reviewed on the same calendar
    /// day as `now`. Used as the `alreadyReviewedToday` input.
    public static func reviewedTodayCount(
        states: [SRSSnapshot],
        now: Date,
        calendar: Calendar = .current
    ) -> Int {
        states.filter { state in
            guard let last = state.lastReview else { return false }
            return calendar.isDate(last, inSameDayAs: now)
        }.count
    }
}
