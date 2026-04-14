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
}
