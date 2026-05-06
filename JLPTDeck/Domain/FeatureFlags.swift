import Foundation

/// v1.0 feature flags. HIGH-risk additions are gated here so they can be
/// flipped off without code reverts if a regression is found late in the cycle.
public enum FeatureFlags {
    /// F3: Same-session retry uses an in-memory learning step queue and does
    /// NOT update SRS interval. Disable to fall back to the legacy behavior
    /// where every answer (including re-attempts) writes to SRS.
    public static let relearnSeparated: Bool = true

    /// F4: Failed `upsertSRS` calls are persisted to a retry queue and drained
    /// at the next session boundary. Disable to fall back to legacy
    /// silent-fail behavior (loadError set, but no retry).
    public static let upsertRetry: Bool = true

    /// F8: User can hide individual cards. Hidden cards are filtered from
    /// `todayReviewCards`. Disable to drop the menu UI and the filter
    /// (existing `UserOverride` rows remain on disk but become inert).
    /// (Note vs report UI deferred to v1.x — F8 v1.0 scope is hide only.)
    public static let cardOverride: Bool = true

    /// F9: Record per-answer response latency and count slow first-attempt
    /// correct answers (likely-guess heuristic). v1.0 records + displays a
    /// SessionComplete summary; SM-2 scheduling is NOT affected. Disable to
    /// stop recording (counter stays at 0).
    public static let responseLatencyTracking: Bool = true

    /// F13: Settings-side JSON export / import of SRS state + user overrides.
    /// Disable to hide the export buttons (existing files remain readable
    /// via manual import).
    public static let dataExport: Bool = true

    /// F15: Record one `AppOpenEvent` per app launch and surface a local
    /// D1/D7 retention preview in StatsView's debug section. External
    /// transmission: 0. Disable to stop recording (debug section hides).
    public static let eventCounter: Bool = true

    /// F7+F10 (G-SessionComplete): show the next-day review preview and
    /// streak coaching at session completion, plus split first-attempt vs
    /// recovered counters. Disable to fall back to the legacy correct/wrong
    /// chip display only.
    public static let sessionCompleteCoaching: Bool = true

    /// F12 (G-CardView): show JMdict part-of-speech in 1 word after the
    /// answer is revealed. Pure infrastructure — bundled JMdict JSON
    /// currently lacks the `pos` field, so the view falls back to hidden
    /// for every card. Disable to drop the row entirely.
    public static let cardPartOfSpeech: Bool = true

    /// F16 (G-CardView): expose a tap-to-speak button after answer reveal
    /// so the user can hear the headword via AVSpeechSynthesizer. NO
    /// autoplay. Disable to hide the button (audio engine is not started
    /// when this is off).
    public static let cardTTS: Bool = true

    /// F17 (G-CardView): detect 장음/촉음/ん in the reading after the
    /// answer is revealed and show a small badge with a Korean tooltip.
    /// Pure regex check on the kana reading. Disable to skip detection
    /// and hide the badges.
    public static let cardPronunciationTraps: Bool = true
}
