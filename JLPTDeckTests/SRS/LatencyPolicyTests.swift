import XCTest
@testable import JLPTDeck

final class LatencyPolicyTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    func test_latencyMs_nilPresentedAt_returnsNil() {
        XCTAssertNil(LatencyPolicy.latencyMs(presentedAt: nil, now: base))
    }

    func test_latencyMs_negativeDelta_returnsNil() {
        let later = base.addingTimeInterval(5)
        XCTAssertNil(LatencyPolicy.latencyMs(presentedAt: later, now: base))
    }

    func test_latencyMs_zeroDelta_returnsZero() {
        XCTAssertEqual(LatencyPolicy.latencyMs(presentedAt: base, now: base), 0)
    }

    func test_latencyMs_oneSecond_returns1000() {
        let now = base.addingTimeInterval(1)
        XCTAssertEqual(LatencyPolicy.latencyMs(presentedAt: base, now: now), 1000)
    }

    func test_latencyMs_subSecond_rounds() {
        let now = base.addingTimeInterval(0.4567)
        XCTAssertEqual(LatencyPolicy.latencyMs(presentedAt: base, now: now), 457)
    }

    func test_isSlow_nil_false() {
        XCTAssertFalse(LatencyPolicy.isSlow(latencyMs: nil))
    }

    func test_isSlow_belowThreshold_false() {
        XCTAssertFalse(LatencyPolicy.isSlow(latencyMs: LatencyPolicy.slowThresholdMs - 1))
        XCTAssertFalse(LatencyPolicy.isSlow(latencyMs: 0))
    }

    func test_isSlow_atOrAboveThreshold_true() {
        // Inclusive boundary so UI copy "5초 이상" matches policy exactly.
        XCTAssertTrue(LatencyPolicy.isSlow(latencyMs: LatencyPolicy.slowThresholdMs))
        XCTAssertTrue(LatencyPolicy.isSlow(latencyMs: LatencyPolicy.slowThresholdMs + 1))
        XCTAssertTrue(LatencyPolicy.isSlow(latencyMs: 100_000))
    }

    func test_thresholdIsFiveSeconds() {
        XCTAssertEqual(LatencyPolicy.slowThresholdMs, 5_000,
                       "v1.0 ships 5s threshold; v1.x A/B will tune.")
    }

    func test_featureFlagDefaultOn() {
        XCTAssertTrue(FeatureFlags.responseLatencyTracking)
    }

    func test_hardQualityEnumExists() {
        // F9 DoD: ".hard enum 정의(미사용)". Defined since F3 — confirm it survives.
        XCTAssertEqual(SRSQuality.hard.rawValue, 3)
    }
}
