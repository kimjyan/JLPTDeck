import Foundation

/// F15: pure helpers that derive D1 / D7 retention from a list of app-open
/// dates. Lives at the Domain layer so unit tests don't need SwiftData.
///
/// Definitions (single-user local proxy — no external SDK):
/// - install date = earliest event date (calendar day)
/// - D1 retained = at least one event on `install + 1 day` (calendar day)
/// - D7 retained = at least one event in `install + 1 ... install + 7` days
///
/// Returns nil counts when the user has not yet been installed long enough
/// (e.g. install was today → D1 unknown until tomorrow).
public enum RetentionStats {
    public struct Snapshot: Equatable {
        public let installDate: Date?
        public let totalOpenDays: Int          // unique calendar days with at least one event
        public let d1Retained: Bool?           // nil if not yet day 1
        public let d7Retained: Bool?           // nil if not yet day 7
        public let lastOpenDate: Date?

        public init(installDate: Date?, totalOpenDays: Int, d1Retained: Bool?, d7Retained: Bool?, lastOpenDate: Date?) {
            self.installDate = installDate
            self.totalOpenDays = totalOpenDays
            self.d1Retained = d1Retained
            self.d7Retained = d7Retained
            self.lastOpenDate = lastOpenDate
        }
    }

    /// - Parameters:
    ///   - eventDates: all `AppOpenEvent.date` values (any order)
    ///   - now: current time (injected for determinism)
    ///   - calendar: `Calendar` for day bucketing (default: `.current`)
    public static func snapshot(
        eventDates: [Date],
        now: Date,
        calendar: Calendar = .current
    ) -> Snapshot {
        guard let earliest = eventDates.min() else {
            return Snapshot(installDate: nil, totalOpenDays: 0,
                            d1Retained: nil, d7Retained: nil, lastOpenDate: nil)
        }
        let installDay = calendar.startOfDay(for: earliest)
        let nowDay = calendar.startOfDay(for: now)
        let lastOpen = eventDates.max()

        // Unique calendar days touched by an event.
        let openDays = Set(eventDates.map { calendar.startOfDay(for: $0) })

        let daysSinceInstall = calendar.dateComponents([.day], from: installDay, to: nowDay).day ?? 0

        // D1 / D7 windows are defined relative to install day.
        // D1 = at least one event on `install + 1` (if that day has happened).
        let d1: Bool?
        if daysSinceInstall < 1 {
            d1 = nil
        } else {
            let d1Day = calendar.date(byAdding: .day, value: 1, to: installDay)!
            d1 = openDays.contains(d1Day)
        }
        // D7 = at least one event in `install + 1 ... install + 7`.
        let d7: Bool?
        if daysSinceInstall < 7 {
            d7 = nil
        } else {
            var found = false
            for offset in 1...7 {
                if let day = calendar.date(byAdding: .day, value: offset, to: installDay),
                   openDays.contains(day) { found = true; break }
            }
            d7 = found
        }

        return Snapshot(
            installDate: installDay,
            totalOpenDays: openDays.count,
            d1Retained: d1,
            d7Retained: d7,
            lastOpenDate: lastOpen
        )
    }
}
