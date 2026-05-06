import XCTest
@testable import JLPTDeck

final class UpsertRetryStorageTests: XCTestCase {
    private func makeItem(cardID: UUID = UUID(), attempt: Int = 0) -> UpsertRetryItem {
        UpsertRetryItem(
            cardID: cardID,
            ease: 2.5,
            intervalDays: 1,
            reps: 0,
            lapses: 1,
            dueDate: Date(timeIntervalSince1970: 1_700_000_086_400),
            now: Date(timeIntervalSince1970: 1_700_000_000),
            attemptCount: attempt
        )
    }

    func test_decode_emptyData_returnsEmpty() {
        XCTAssertEqual(UpsertRetryStorage.decode(nil), [])
        XCTAssertEqual(UpsertRetryStorage.decode(Data()), [])
    }

    func test_decode_garbage_returnsEmpty() {
        let garbage = "not json".data(using: .utf8)!
        XCTAssertEqual(UpsertRetryStorage.decode(garbage), [])
    }

    func test_encodeDecode_roundTrip_preservesAllFields() throws {
        let id1 = UUID()
        let id2 = UUID()
        let items = [makeItem(cardID: id1, attempt: 2), makeItem(cardID: id2, attempt: 0)]
        let data = UpsertRetryStorage.encode(items)
        XCTAssertGreaterThan(data.count, 0)

        let decoded = UpsertRetryStorage.decode(data)
        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0].cardID, id1)
        XCTAssertEqual(decoded[0].attemptCount, 2)
        XCTAssertEqual(decoded[0].ease, 2.5, accuracy: 0.0001)
        XCTAssertEqual(decoded[0].intervalDays, 1)
        XCTAssertEqual(decoded[0].lapses, 1)
        XCTAssertEqual(decoded[1].cardID, id2)
    }

    func test_toSRSUpdate_preservesFields() {
        let id = UUID()
        let item = makeItem(cardID: id)
        let update = item.toSRSUpdate()
        XCTAssertEqual(update.ease, item.ease, accuracy: 0.0001)
        XCTAssertEqual(update.intervalDays, item.intervalDays)
        XCTAssertEqual(update.reps, item.reps)
        XCTAssertEqual(update.lapses, item.lapses)
        XCTAssertEqual(update.dueDate, item.dueDate)
    }

    func test_userDefaultsKey_isVersioned() {
        // Versioned key prevents collisions if the schema changes later.
        XCTAssertTrue(UpsertRetryStorage.userDefaultsKey.contains(".v"))
    }

    func test_featureFlagDefaultOn() {
        XCTAssertTrue(FeatureFlags.upsertRetry,
                      "v1.0 ships F4 enabled. Flip to false only for emergency rollback.")
    }
}
