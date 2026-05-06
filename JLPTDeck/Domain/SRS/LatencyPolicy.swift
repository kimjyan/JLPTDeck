import Foundation

/// F9: per-attempt latency record. Captured for EVERY `answerTapped`
/// (correct or wrong, first or retry). Lives in session state for the
/// SessionComplete display + future export. SM-2 scheduling never reads
/// these — measurement-only path.
public struct ResponseLatencyRecord: Equatable, Sendable {
    public let cardID: UUID
    public let latencyMs: Int?           // nil if presentedAt was nil (e.g. background return)
    public let isCorrect: Bool
    public let isFirstAttempt: Bool      // false for F3 same-session relearn retries
    public let isSlow: Bool              // LatencyPolicy.isSlow result, fixed at insert time

    public init(cardID: UUID, latencyMs: Int?, isCorrect: Bool, isFirstAttempt: Bool, isSlow: Bool) {
        self.cardID = cardID
        self.latencyMs = latencyMs
        self.isCorrect = isCorrect
        self.isFirstAttempt = isFirstAttempt
        self.isSlow = isSlow
    }
}

/// F9: response-latency policy. Pure helpers — no SRS state mutation, no
/// scheduling effect. v1.0 only USES the threshold for a visual marker
/// ("slow first attempt" count on SessionComplete). v1.x A/B may flip this
/// into an SM-2 quality auto-step (`.hard` enum is already defined).
public enum LatencyPolicy {
    /// Above this many milliseconds, a first-attempt correct answer is flagged
    /// as "slow" — likely a guess after lengthy elimination rather than a
    /// confident recognition. v1.x A/B will tune this against next-day recall.
    public static let slowThresholdMs: Int = 5_000

    /// - Returns: latency in milliseconds (rounded). nil if `presentedAt` was
    ///   not recorded (e.g. session resumed mid-question).
    public static func latencyMs(presentedAt: Date?, now: Date) -> Int? {
        guard let presentedAt else { return nil }
        let delta = now.timeIntervalSince(presentedAt)
        guard delta >= 0 else { return nil }
        return Int((delta * 1_000).rounded())
    }

    /// True iff `latencyMs` is non-nil and meets-or-exceeds the slow
    /// threshold. Inclusive boundary (`>=`) so the UI copy "5초 이상"
    /// matches the policy precisely.
    public static func isSlow(latencyMs: Int?) -> Bool {
        guard let latencyMs else { return false }
        return latencyMs >= slowThresholdMs
    }
}
