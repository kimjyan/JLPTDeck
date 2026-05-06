import Foundation

/// F13: top-level JSON shape for the SRS-state backup file.
/// Versioned `schemaVersion` so future formats can be detected and migrated.
public struct ExportPayload: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let exportedAtUnix: TimeInterval
    public let appVersion: String
    public let srsStates: [SRSStateExport]
    public let userOverrides: [UserOverrideExport]

    public init(
        schemaVersion: Int = 1,
        exportedAtUnix: TimeInterval,
        appVersion: String,
        srsStates: [SRSStateExport],
        userOverrides: [UserOverrideExport]
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAtUnix = exportedAtUnix
        self.appVersion = appVersion
        self.srsStates = srsStates
        self.userOverrides = userOverrides
    }
}

public struct SRSStateExport: Codable, Equatable, Sendable {
    public let cardID: UUID
    public let ease: Double
    public let intervalDays: Int
    public let reps: Int
    public let lapses: Int
    public let lastReviewUnix: TimeInterval?
    public let dueDateUnix: TimeInterval

    public init(
        cardID: UUID, ease: Double, intervalDays: Int, reps: Int, lapses: Int,
        lastReviewUnix: TimeInterval?, dueDateUnix: TimeInterval
    ) {
        self.cardID = cardID
        self.ease = ease
        self.intervalDays = intervalDays
        self.reps = reps
        self.lapses = lapses
        self.lastReviewUnix = lastReviewUnix
        self.dueDateUnix = dueDateUnix
    }
}

public struct UserOverrideExport: Codable, Equatable, Sendable {
    public let cardID: UUID
    public let isHidden: Bool
    public let note: String?

    public init(cardID: UUID, isHidden: Bool, note: String?) {
        self.cardID = cardID
        self.isHidden = isHidden
        self.note = note
    }
}

/// Pure encode/decode helpers. Lives at the Domain layer so tests run
/// without `UserDefaults`, `FileManager`, or SwiftData.
public enum ExportPayloadCodec {
    public static let currentSchemaVersion: Int = 1

    public static func encode(_ payload: ExportPayload) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(payload)
    }

    public static func decode(_ data: Data) throws -> ExportPayload {
        try JSONDecoder().decode(ExportPayload.self, from: data)
    }
}
