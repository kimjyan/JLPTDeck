import XCTest
@testable import JLPTDeck

final class HiddenCardFilterTests: XCTestCase {
    private struct StubCard {
        let id: UUID
        let label: String
    }

    func test_emptyHiddenSet_returnsInputUnchanged() {
        let cards = [
            StubCard(id: UUID(), label: "A"),
            StubCard(id: UUID(), label: "B"),
        ]
        let result = HiddenCardFilter.apply(cards: cards, hiddenIDs: [], idOf: { $0.id })
        XCTAssertEqual(result.map(\.label), ["A", "B"])
    }

    func test_dropsHiddenCards_preservesOrder() {
        let id1 = UUID(), id2 = UUID(), id3 = UUID()
        let cards = [
            StubCard(id: id1, label: "A"),
            StubCard(id: id2, label: "B"),
            StubCard(id: id3, label: "C"),
        ]
        let result = HiddenCardFilter.apply(
            cards: cards, hiddenIDs: [id2], idOf: { $0.id }
        )
        XCTAssertEqual(result.map(\.label), ["A", "C"])
    }

    func test_hiddenSetOfUnrelatedIDs_isNoOp() {
        let cards = [StubCard(id: UUID(), label: "A")]
        let result = HiddenCardFilter.apply(
            cards: cards, hiddenIDs: [UUID(), UUID()], idOf: { $0.id }
        )
        XCTAssertEqual(result.map(\.label), ["A"])
    }

    func test_allHidden_returnsEmpty() {
        let id1 = UUID(), id2 = UUID()
        let cards = [
            StubCard(id: id1, label: "A"),
            StubCard(id: id2, label: "B"),
        ]
        let result = HiddenCardFilter.apply(
            cards: cards, hiddenIDs: [id1, id2], idOf: { $0.id }
        )
        XCTAssertTrue(result.isEmpty)
    }

    func test_emptyInput_returnsEmpty() {
        let cards: [StubCard] = []
        let result = HiddenCardFilter.apply(
            cards: cards, hiddenIDs: [UUID()], idOf: { $0.id }
        )
        XCTAssertTrue(result.isEmpty)
    }

    func test_featureFlagDefaultOn() {
        XCTAssertTrue(FeatureFlags.cardOverride,
                      "v1.0 ships F8 enabled. Flip to false only for emergency rollback.")
    }
}
