import Foundation

/// F8: pure helper that drops user-hidden cards from a candidate review pool.
/// Lives at the Domain layer so it can be unit-tested without SwiftData.
public enum HiddenCardFilter {
    /// - Parameters:
    ///   - cards: candidate cards in original order
    ///   - hiddenIDs: set of card IDs the user has marked as hidden
    /// - Returns: `cards` minus any whose `id` is in `hiddenIDs`. Order preserved.
    public static func apply<C: Collection>(
        cards: C,
        hiddenIDs: Set<UUID>,
        idOf: (C.Element) -> UUID
    ) -> [C.Element] {
        guard !hiddenIDs.isEmpty else { return Array(cards) }
        return cards.filter { !hiddenIDs.contains(idOf($0)) }
    }
}
