import Foundation

/// F4: a single SRS upsert that failed at write time and is queued for retry
/// on the next session boundary.
///
/// Unix timestamps (not `Date`) are stored so `Codable` round-trips are stable
/// across `JSONEncoder` configuration changes.
public struct UpsertRetryItem: Codable, Equatable, Sendable {
    public let cardID: UUID
    public let ease: Double
    public let intervalDays: Int
    public let reps: Int
    public let lapses: Int
    public let dueDateUnix: TimeInterval
    public let nowUnix: TimeInterval
    /// How many drain attempts have already been tried. Drain logic may use
    /// this for backoff or eviction; v1.0 just tracks it.
    public var attemptCount: Int

    public init(
        cardID: UUID,
        ease: Double,
        intervalDays: Int,
        reps: Int,
        lapses: Int,
        dueDate: Date,
        now: Date,
        attemptCount: Int = 0
    ) {
        self.cardID = cardID
        self.ease = ease
        self.intervalDays = intervalDays
        self.reps = reps
        self.lapses = lapses
        self.dueDateUnix = dueDate.timeIntervalSince1970
        self.nowUnix = now.timeIntervalSince1970
        self.attemptCount = attemptCount
    }

    public var dueDate: Date { Date(timeIntervalSince1970: dueDateUnix) }
    public var now: Date { Date(timeIntervalSince1970: nowUnix) }

    public func toSRSUpdate() -> SRSUpdate {
        SRSUpdate(
            ease: ease,
            intervalDays: intervalDays,
            reps: reps,
            dueDate: dueDate,
            lapses: lapses
        )
    }
}

/// Pure encode/decode helpers for the persisted retry queue. Lives at the
/// Domain layer so tests do not need `UserDefaults`.
public enum UpsertRetryStorage {
    public static let userDefaultsKey = "jlpt.upsertRetryQueue.v1"

    public static func encode(_ items: [UpsertRetryItem]) -> Data {
        (try? JSONEncoder().encode(items)) ?? Data()
    }

    public static func decode(_ data: Data?) -> [UpsertRetryItem] {
        guard let data, !data.isEmpty else { return [] }
        return (try? JSONDecoder().decode([UpsertRetryItem].self, from: data)) ?? []
    }
}

/// Pure drain logic. Extracted so it can be tested without `TestStore` (whose
/// fire-and-forget effects forced the legacy test to rely on `Task.yield()`
/// loops, and whose throwing dependencies have tripped the host-app deinit
/// crash documented in CLAUDE.md).
public enum UpsertRetryDrain {
    /// Iterate `items` and call `upsertSRS` for each. On success, invoke
    /// `onSuccess(cardID)` so the caller can `remove` from the persisted
    /// queue. On failure, leave the item alone (no eviction in v1.0).
    public static func drain(
        items: [UpsertRetryItem],
        upsertSRS: @Sendable (UUID, SRSUpdate, Date) async throws -> Void,
        onSuccess: @Sendable (UUID) -> Void
    ) async {
        for item in items {
            do {
                try await upsertSRS(item.cardID, item.toSRSUpdate(), item.now)
                onSuccess(item.cardID)
            } catch {
                // Leave in queue. attemptCount eviction is reserved for v1.x.
            }
        }
    }
}
