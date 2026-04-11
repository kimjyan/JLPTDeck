import Foundation
import SwiftData

enum JMdictImportError: Error {
    case bundleResourceMissing
    case decodeFailed(Error)
}

/// Imports the bundled `jmdict_n4_n1.json` into the SwiftData store as `VocabCard` rows.
///
/// Idempotent: `importIfNeeded()` is a no-op if any `VocabCard` already exists.
/// We decode the JSON on a detached task (off the main actor) and then insert on
/// whichever actor the `ModelContext` is bound to. Inserts are batched and `save()`
/// is called once per batch so that a crash mid-import still leaves a consistent,
/// partially-populated store that `importIfNeeded` will finish on next launch.
final class JMdictImporter {
    static let resourceName = "jmdict_n4_n1"
    static let resourceExtension = "json"
    static let batchSize = 500

    private let modelContext: ModelContext
    private let bundle: Bundle

    init(modelContext: ModelContext, bundle: Bundle = .main) {
        self.modelContext = modelContext
        self.bundle = bundle
    }

    func importIfNeeded() async throws {
        // Short-circuit if any cards already exist.
        var existingDescriptor = FetchDescriptor<VocabCard>()
        existingDescriptor.fetchLimit = 1
        let existing = try modelContext.fetch(existingDescriptor)
        if !existing.isEmpty { return }

        guard let url = bundle.url(
            forResource: Self.resourceName,
            withExtension: Self.resourceExtension
        ) else {
            throw JMdictImportError.bundleResourceMissing
        }

        // Decode off the caller's actor to keep UI responsive on large imports.
        let entries: [JMdictEntry]
        do {
            entries = try await Task.detached(priority: .userInitiated) {
                let data = try Data(contentsOf: url)
                return try JSONDecoder().decode([JMdictEntry].self, from: data)
            }.value
        } catch {
            throw JMdictImportError.decodeFailed(error)
        }

        try insertInBatches(entries)
    }

    /// Exposed for tests — inserts an explicitly provided decoded array.
    func importEntries(_ entries: [JMdictEntry]) throws {
        var existingDescriptor = FetchDescriptor<VocabCard>()
        existingDescriptor.fetchLimit = 1
        let existing = try modelContext.fetch(existingDescriptor)
        if !existing.isEmpty { return }
        try insertInBatches(entries)
    }

    private func insertInBatches(_ entries: [JMdictEntry]) throws {
        var buffer: [JMdictEntry] = []
        buffer.reserveCapacity(Self.batchSize)

        for entry in entries {
            buffer.append(entry)
            if buffer.count >= Self.batchSize {
                try flush(buffer)
                buffer.removeAll(keepingCapacity: true)
            }
        }
        if !buffer.isEmpty {
            try flush(buffer)
        }
    }

    private func flush(_ batch: [JMdictEntry]) throws {
        for entry in batch {
            let card = VocabCard(
                headword: entry.headword,
                reading: entry.reading,
                gloss: entry.gloss,
                gloss_ko: entry.gloss_ko,
                jlptLevel: entry.jlptLevel.rawValue
            )
            modelContext.insert(card)
        }
        try modelContext.save()
    }
}
