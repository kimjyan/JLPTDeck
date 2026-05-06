import Foundation

/// F3: Decides whether an answer should advance the SM-2 SRS state.
///
/// First attempts always update SRS. Same-session re-attempts (cards that were
/// re-queued after a wrong first answer) are treated as a learning step and do
/// NOT update SRS, so a recovered re-attempt does not paper over the original
/// failure on the long-term schedule.
///
/// Pure value function — no I/O, no actor. Tested at the Domain layer to avoid
/// the host-app SwiftData simulator crash that blocks `ReviewSessionFeature`
/// integration tests.
public enum RelearnPolicy {
    /// - Returns: `true` if the SM-2 update should be applied for this answer.
    public static func shouldUpdateSRS(
        cardID: UUID,
        relearnedIDs: Set<UUID>,
        flagEnabled: Bool
    ) -> Bool {
        if !flagEnabled { return true }
        return !relearnedIDs.contains(cardID)
    }
}
