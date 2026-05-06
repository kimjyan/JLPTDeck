import Foundation
import SwiftData

/// F8: per-card user override (hide / report). Lets users immediately quiet
/// a problematic card without waiting for the next bundled-data hotfix.
///
/// SwiftData adds new `@Model` types via implicit schema migration; existing
/// VocabCard/SRSState data is unaffected.
@Model
final class UserOverride {
    @Attribute(.unique) var cardID: UUID
    var isHidden: Bool
    /// Free-form user note (e.g. "wrong translation"). Optional. Future:
    /// surface to the maintainer via JSON export (F13).
    var note: String?
    var createdAt: Date

    init(
        cardID: UUID,
        isHidden: Bool = false,
        note: String? = nil,
        createdAt: Date = .now
    ) {
        self.cardID = cardID
        self.isHidden = isHidden
        self.note = note
        self.createdAt = createdAt
    }
}
