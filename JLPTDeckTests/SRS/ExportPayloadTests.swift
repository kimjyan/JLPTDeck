import XCTest
@testable import JLPTDeck

final class ExportPayloadTests: XCTestCase {
    private func makePayload() -> ExportPayload {
        let id1 = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let id2 = UUID()
        return ExportPayload(
            schemaVersion: 1,
            exportedAtUnix: 1_700_000_000,
            appVersion: "1.0 (1)",
            srsStates: [
                SRSStateExport(
                    cardID: id1, ease: 2.3, intervalDays: 6, reps: 2, lapses: 1,
                    lastReviewUnix: 1_700_000_000, dueDateUnix: 1_700_086_400
                ),
                SRSStateExport(
                    cardID: id2, ease: 2.5, intervalDays: 1, reps: 0, lapses: 0,
                    lastReviewUnix: nil, dueDateUnix: 1_700_086_400
                )
            ],
            userOverrides: [
                UserOverrideExport(cardID: id1, isHidden: true, note: nil),
                UserOverrideExport(cardID: id2, isHidden: false, note: "wrong reading")
            ]
        )
    }

    func test_roundTrip_preservesAllFields() throws {
        let original = makePayload()
        let data = try ExportPayloadCodec.encode(original)
        XCTAssertGreaterThan(data.count, 0)
        let decoded = try ExportPayloadCodec.decode(data)
        XCTAssertEqual(decoded, original)
    }

    func test_encode_isPrettyPrinted() throws {
        let data = try ExportPayloadCodec.encode(makePayload())
        let s = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(s.contains("\n"), "pretty-printed output should contain newlines for human inspection")
        // Sorted keys → schemaVersion appears before srsStates alphabetically.
        let schemaIdx = s.range(of: "\"schemaVersion\"")?.lowerBound
        let srsIdx = s.range(of: "\"srsStates\"")?.lowerBound
        if let schemaIdx, let srsIdx {
            XCTAssertLessThan(schemaIdx, srsIdx)
        }
    }

    func test_decode_garbageThrows() {
        let garbage = "not json at all".data(using: .utf8)!
        XCTAssertThrowsError(try ExportPayloadCodec.decode(garbage))
    }

    func test_decode_emptyDataThrows() {
        XCTAssertThrowsError(try ExportPayloadCodec.decode(Data()))
    }

    func test_currentSchemaVersionIsOne() {
        XCTAssertEqual(ExportPayloadCodec.currentSchemaVersion, 1)
    }

    func test_featureFlagDefaultOn() {
        XCTAssertTrue(FeatureFlags.dataExport)
    }

    func test_nilLastReview_roundTrips() throws {
        let p = ExportPayload(
            exportedAtUnix: 0, appVersion: "x",
            srsStates: [SRSStateExport(
                cardID: UUID(), ease: 2.5, intervalDays: 0, reps: 0, lapses: 0,
                lastReviewUnix: nil, dueDateUnix: 0
            )],
            userOverrides: []
        )
        let decoded = try ExportPayloadCodec.decode(try ExportPayloadCodec.encode(p))
        XCTAssertNil(decoded.srsStates.first?.lastReviewUnix)
    }
}
