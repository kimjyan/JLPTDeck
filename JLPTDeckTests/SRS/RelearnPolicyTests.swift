import XCTest
@testable import JLPTDeck

final class RelearnPolicyTests: XCTestCase {
    func test_firstAttempt_updatesSRS() {
        let cardID = UUID()
        XCTAssertTrue(
            RelearnPolicy.shouldUpdateSRS(
                cardID: cardID,
                relearnedIDs: [],
                flagEnabled: true
            ),
            "First attempt (id not in relearned set) must update SRS"
        )
    }

    func test_reattemptOfRelearnedCard_skipsSRS() {
        let cardID = UUID()
        XCTAssertFalse(
            RelearnPolicy.shouldUpdateSRS(
                cardID: cardID,
                relearnedIDs: [cardID],
                flagEnabled: true
            ),
            "Re-attempt of an already-relearned card must skip SRS update"
        )
    }

    func test_unrelatedCardInSet_stillUpdatesSRS() {
        let target = UUID()
        let other = UUID()
        XCTAssertTrue(
            RelearnPolicy.shouldUpdateSRS(
                cardID: target,
                relearnedIDs: [other],
                flagEnabled: true
            ),
            "Other cards in relearned set must not affect target card decision"
        )
    }

    func test_flagDisabled_alwaysUpdatesSRS_evenIfRelearned() {
        let cardID = UUID()
        XCTAssertTrue(
            RelearnPolicy.shouldUpdateSRS(
                cardID: cardID,
                relearnedIDs: [cardID],
                flagEnabled: false
            ),
            "When the feature flag is OFF, SRS must always update (legacy behavior)"
        )
    }

    func test_flagDisabled_emptySet_updatesSRS() {
        XCTAssertTrue(
            RelearnPolicy.shouldUpdateSRS(
                cardID: UUID(),
                relearnedIDs: [],
                flagEnabled: false
            )
        )
    }

    func test_flagEnabledByDefault_inFeatureFlags() {
        XCTAssertTrue(
            FeatureFlags.relearnSeparated,
            "v1.0 ships with F3 enabled. Flip to false only for emergency rollback."
        )
    }
}
