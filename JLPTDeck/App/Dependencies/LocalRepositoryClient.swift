import ComposableArchitecture
import Foundation

/// TCA `@Dependency` client mirroring the `LocalRepository` protocol as
/// Sendable async closures. Concrete live wiring lives in
/// `LocalRepositoryClient+Live.swift` and is installed from `JLPTDeckApp`
/// once the `ModelContainer` is available.
struct LocalRepositoryClient: Sendable {
    var importIfNeeded: @Sendable () async throws -> Void
    var cards: @Sendable (_ level: JLPTLevel) async throws -> [VocabCardDTO]
    var todayReviewCards: @Sendable (_ limit: Int, _ level: JLPTLevel, _ now: Date) async throws -> [VocabCardDTO.WithSRS]
    var upsertSRS: @Sendable (_ cardID: UUID, _ update: SRSUpdate, _ now: Date) async throws -> Void
    var distractorCards: @Sendable (_ level: JLPTLevel, _ excluding: UUID, _ count: Int) async throws -> [VocabCardDTO]
    var cardCount: @Sendable (_ level: JLPTLevel) async throws -> Int
    var mistakenCards: @Sendable (_ level: JLPTLevel) async throws -> [VocabCardDTO.WithSRS]
    /// F8: hide / unhide a single card. Hidden cards are filtered from
    /// `todayReviewCards`.
    var setHidden: @Sendable (_ cardID: UUID, _ hidden: Bool) async throws -> Void

    /// F13: snapshot SRSState + UserOverride for JSON export.
    var exportSnapshot: @Sendable () async throws -> (srs: [SRSStateExport], overrides: [UserOverrideExport])

    /// F13: upsert SRSState + UserOverride from a previously exported payload.
    var importSnapshot: @Sendable (_ srs: [SRSStateExport], _ overrides: [UserOverrideExport]) async throws -> Void

    /// F15: record a single app-open event with the given timestamp.
    var recordAppOpen: @Sendable (_ date: Date) async throws -> Void

    /// F15: read all app-open event dates (for D1/D7 retention computation).
    var appOpenEventDates: @Sendable () async throws -> [Date]
}
