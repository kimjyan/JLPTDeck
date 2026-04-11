import Foundation

/// Pure function that picks which cards to study today.
///
/// Policy:
/// 1. From `due`, keep only cards whose `dueDate <= now`.
/// 2. Sort those ascending by `dueDate`.
/// 3. Take up to `limit` of them.
/// 4. If fewer than `limit` were picked, fill the remaining slots from
///    `newCardIDs` in the given order.
/// 5. Never exceed `limit`. Never include future-dated cards.
public enum CardScheduler {
    public static func pickToday(
        due: [SRSSnapshot],
        newCardIDs: [UUID],
        limit: Int,
        now: Date
    ) -> [UUID] {
        guard limit > 0 else { return [] }

        let readyDue = due
            .filter { $0.dueDate <= now }
            .sorted { $0.dueDate < $1.dueDate }

        let duePick = Array(readyDue.prefix(limit)).map { $0.cardID }

        if duePick.count >= limit {
            return duePick
        }

        let remaining = limit - duePick.count
        let newPick = Array(newCardIDs.prefix(remaining))
        return duePick + newPick
    }
}
