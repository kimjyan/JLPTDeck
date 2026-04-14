import ComposableArchitecture
import SwiftData
import Foundation

extension LocalRepositoryClient: DependencyKey {
    /// Default `liveValue` is a not-configured stub. `JLPTDeckApp` installs the
    /// real implementation via `prepareDependencies { $0.localRepository = .live(container:) }`
    /// once the SwiftData `ModelContainer` has been built.
    static let liveValue: LocalRepositoryClient = .notConfigured

    static var notConfigured: LocalRepositoryClient {
        LocalRepositoryClient(
            importIfNeeded: { fatalError("localRepository not configured — wire in JLPTDeckApp") },
            cards: { _ in fatalError("localRepository not configured") },
            todayReviewCards: { _, _, _ in fatalError("localRepository not configured") },
            upsertSRS: { _, _, _ in fatalError("localRepository not configured") },
            distractorCards: { _, _, _ in fatalError("localRepository not configured") },
            cardCount: { _ in fatalError("localRepository not configured") },
            mistakenCards: { _ in fatalError("localRepository not configured") }
        )
    }

    static func live(container: ModelContainer) -> LocalRepositoryClient {
        LocalRepositoryClient(
            importIfNeeded: {
                try await _runOnMainAsync(container) { repo in
                    try await repo.importIfNeeded()
                }
            },
            cards: { level in
                try await _runOnMain(container) { repo in
                    try repo.cards(for: level).map(VocabCardDTO.init(from:))
                }
            },
            todayReviewCards: { limit, level, now in
                try await _runOnMain(container) { repo in
                    try repo.todayReviewCards(limit: limit, level: level, now: now).map { (card, state) in
                        VocabCardDTO.WithSRS(card: .init(from: card), srs: state?.snapshot())
                    }
                }
            },
            upsertSRS: { cardID, update, now in
                try await _runOnMain(container) { repo in
                    try repo.upsertSRS(cardID: cardID, update: update, now: now)
                }
            },
            distractorCards: { level, excluding, count in
                try await _runOnMain(container) { repo in
                    try repo.distractorCards(level: level, excluding: excluding, count: count).map(VocabCardDTO.init(from:))
                }
            },
            cardCount: { level in
                try await _runOnMain(container) { repo in
                    try repo.cards(for: level).count
                }
            },
            mistakenCards: { level in
                try await _runOnMain(container) { repo in
                    try repo.mistakenCards(level: level).map { pair in
                        VocabCardDTO.WithSRS(card: .init(from: pair.0), srs: pair.1.snapshot())
                    }
                }
            }
        )
    }
}

@MainActor
private func _runOnMain<T: Sendable>(
    _ container: ModelContainer,
    _ body: (SwiftDataLocalRepository) throws -> T
) async throws -> T {
    let repo = SwiftDataLocalRepository(modelContext: container.mainContext)
    return try body(repo)
}

@MainActor
private func _runOnMainAsync<T: Sendable>(
    _ container: ModelContainer,
    _ body: (SwiftDataLocalRepository) async throws -> T
) async throws -> T {
    let repo = SwiftDataLocalRepository(modelContext: container.mainContext)
    return try await body(repo)
}

extension VocabCardDTO {
    init(from card: VocabCard) {
        self.init(
            id: card.id,
            headword: card.headword,
            reading: card.reading,
            gloss: card.gloss,
            gloss_ko: card.gloss_ko,
            jlptLevel: card.jlptLevel
        )
    }
}

extension DependencyValues {
    var localRepository: LocalRepositoryClient {
        get { self[LocalRepositoryClient.self] }
        set { self[LocalRepositoryClient.self] = newValue }
    }
}
