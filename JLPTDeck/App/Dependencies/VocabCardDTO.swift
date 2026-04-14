import Foundation

/// Value-type snapshot of a VocabCard. Sendable, Equatable — used to cross
/// TCA effect boundaries without dragging @Model references across actors.
struct VocabCardDTO: Equatable, Sendable, Identifiable {
    let id: UUID
    let headword: String
    let reading: String
    let gloss: String
    let gloss_ko: String
    let jlptLevel: String

    /// Paired snapshot for review: card + its current SRS state (nil = new card).
    /// `@unchecked Sendable` because `SRSSnapshot` lives in Domain and is a pure
    /// value type (all stored props are Sendable) but not yet declared Sendable.
    /// We don't want to touch Domain here — see Phase 3 for that.
    struct WithSRS: Equatable, @unchecked Sendable {
        let card: VocabCardDTO
        let srs: SRSSnapshot?
    }
}
