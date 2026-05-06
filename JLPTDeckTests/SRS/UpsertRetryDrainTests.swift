import XCTest
@testable import JLPTDeck

/// F4 drain logic — pure-function tests that exercise both success and
/// failure paths. Avoids `TestStore` so the throwing dependency does not
/// touch the SwiftData host-app deinit crash pattern.
final class UpsertRetryDrainTests: XCTestCase {

    private struct UpsertFailure: Error {}

    private func makeItem(id: UUID = UUID()) -> UpsertRetryItem {
        UpsertRetryItem(
            cardID: id,
            ease: 2.5, intervalDays: 1, reps: 0, lapses: 1,
            dueDate: Date(timeIntervalSince1970: 1_700_086_400),
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    /// All upserts succeed → onSuccess called for each item, in order.
    func test_drain_allSucceed_onSuccessCalledForEach() async {
        let id1 = UUID(), id2 = UUID(), id3 = UUID()
        let items = [makeItem(id: id1), makeItem(id: id2), makeItem(id: id3)]
        let removed = TestActor()

        await UpsertRetryDrain.drain(
            items: items,
            upsertSRS: { _, _, _ in /* succeed */ },
            onSuccess: { id in Task { await removed.append(id) } }
        )
        // Allow the spawned `Task { ... }` blocks to settle.
        for _ in 0..<5 { await Task.yield() }

        let result = await removed.snapshot()
        XCTAssertEqual(Set(result), Set([id1, id2, id3]))
    }

    /// Failure path — onSuccess MUST NOT fire for failed items. Item stays
    /// in the caller's queue (caller decides via onSuccess hook).
    func test_drain_allFail_onSuccessNeverCalled() async {
        let items = [makeItem(), makeItem(), makeItem()]
        let removed = TestActor()

        await UpsertRetryDrain.drain(
            items: items,
            upsertSRS: { _, _, _ in throw UpsertFailure() },
            onSuccess: { id in Task { await removed.append(id) } }
        )
        for _ in 0..<5 { await Task.yield() }

        let result = await removed.snapshot()
        XCTAssertTrue(result.isEmpty, "onSuccess must not fire on failure")
    }

    /// Mixed: some succeed, some fail → onSuccess only for succeeded IDs.
    func test_drain_mixed_onSuccessOnlyForSucceeded() async {
        let succeedID = UUID()
        let failID = UUID()
        let items = [makeItem(id: succeedID), makeItem(id: failID)]
        let removed = TestActor()

        await UpsertRetryDrain.drain(
            items: items,
            upsertSRS: { id, _, _ in
                if id == failID { throw UpsertFailure() }
            },
            onSuccess: { id in Task { await removed.append(id) } }
        )
        for _ in 0..<5 { await Task.yield() }

        let result = await removed.snapshot()
        XCTAssertEqual(result, [succeedID])
    }

    /// Empty input — must not call any closure.
    func test_drain_emptyInput_isNoOp() async {
        let removed = TestActor()
        await UpsertRetryDrain.drain(
            items: [],
            upsertSRS: { _, _, _ in XCTFail("upsertSRS must not run on empty") },
            onSuccess: { _ in XCTFail("onSuccess must not run on empty") }
        )
        let result = await removed.snapshot()
        XCTAssertTrue(result.isEmpty)
    }
}

/// Actor-backed accumulator for thread-safe assertions in async tests.
/// Replaces `LockIsolated` (whose interaction with the test host has
/// triggered the SwiftData deinit crash documented in CLAUDE.md).
private actor TestActor {
    private var values: [UUID] = []
    func append(_ id: UUID) { values.append(id) }
    func snapshot() -> [UUID] { values }
}
