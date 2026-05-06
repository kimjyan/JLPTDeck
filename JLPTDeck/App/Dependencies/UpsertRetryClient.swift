import ComposableArchitecture
import Foundation

/// F4: dependency client for the persisted upsert-retry queue. Backed by
/// `UserDefaults` in `liveValue` so retries survive app launches; tests can
/// inject an in-memory implementation.
struct UpsertRetryClient: Sendable {
    var list: @Sendable () -> [UpsertRetryItem]
    var enqueue: @Sendable (UpsertRetryItem) -> Void
    var remove: @Sendable (UUID) -> Void
    var clear: @Sendable () -> Void
}

extension UpsertRetryClient: DependencyKey {
    static let liveValue: UpsertRetryClient = {
        let defaults = UserDefaults.standard
        let lock = NSLock()
        let key = UpsertRetryStorage.userDefaultsKey

        @Sendable func read() -> [UpsertRetryItem] {
            UpsertRetryStorage.decode(defaults.data(forKey: key))
        }

        @Sendable func write(_ items: [UpsertRetryItem]) {
            defaults.set(UpsertRetryStorage.encode(items), forKey: key)
        }

        return UpsertRetryClient(
            list: {
                lock.lock(); defer { lock.unlock() }
                return read()
            },
            enqueue: { item in
                lock.lock(); defer { lock.unlock() }
                var items = read()
                // Replace existing entry for the same card so we always retry
                // the latest intended state, not a stale one.
                items.removeAll { $0.cardID == item.cardID }
                items.append(item)
                write(items)
            },
            remove: { cardID in
                lock.lock(); defer { lock.unlock() }
                var items = read()
                items.removeAll { $0.cardID == cardID }
                write(items)
            },
            clear: {
                lock.lock(); defer { lock.unlock() }
                defaults.removeObject(forKey: key)
            }
        )
    }()

    static let testValue: UpsertRetryClient = UpsertRetryClient(
        list: { [] },
        enqueue: { _ in },
        remove: { _ in },
        clear: { }
    )
}

extension DependencyValues {
    var upsertRetry: UpsertRetryClient {
        get { self[UpsertRetryClient.self] }
        set { self[UpsertRetryClient.self] = newValue }
    }
}
