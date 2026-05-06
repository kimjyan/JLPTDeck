import Foundation

/// Build-time constants surfaced in the Settings "데이터 출처" section.
/// Centralised so the dataset/version strings live in exactly one place
/// and a data refresh only touches this file (plus the bundled JSON).
enum JLPTDeckMetadata {
    /// F6: dataset version. Format: `YYYY-MM-DD-rN` where N is the
    /// re-pull/translation revision count. Bumped manually when:
    /// - JMdict source pull is refreshed
    /// - Korean translation batch (`gloss_ko`) is regenerated
    /// - Tanos JLPT list is re-imported
    static let datasetVersion = "2026-04-15-r1"

    /// F6: dataset row count, surfaced for sanity ("7,316개"). Matches
    /// CLAUDE.md and is just informational.
    static let datasetCardCount = 7_316
}
