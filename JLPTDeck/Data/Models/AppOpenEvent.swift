import Foundation
import SwiftData

/// F15: lightweight per-launch event row used by the local D1/D7 retention
/// counter. v1.0 records ONE event per app `init` (or first foreground per
/// session). External transmission: 0 — these rows live in SwiftData and
/// are surfaced only in the maintainer-facing debug section of `StatsView`
/// and (v1.x) in the F13 export payload (schema v2).
@Model
final class AppOpenEvent {
    var id: UUID
    var date: Date

    init(id: UUID = UUID(), date: Date = .now) {
        self.id = id
        self.date = date
    }
}
