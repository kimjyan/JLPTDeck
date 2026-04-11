import XCTest
import SwiftData
@testable import JLPTDeck

final class LocalRepositoryTests: XCTestCase {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([VocabCard.self, SRSState.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func loadFixtureEntries(file: StaticString = #filePath) throws -> [JMdictEntry] {
        let thisFile = URL(fileURLWithPath: "\(file)")
        let url = thisFile
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent("jmdict_sample.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([JMdictEntry].self, from: data)
    }

    @MainActor
    func test_cardsForLevel_returnsOnlyMatchingLevel() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let importer = JMdictImporter(modelContext: context)
        try importer.importEntries(try loadFixtureEntries())

        let repo = SwiftDataLocalRepository(modelContext: context)

        XCTAssertEqual(try repo.cards(for: .n4).count, 2)
        XCTAssertEqual(try repo.cards(for: .n3).count, 2)
        XCTAssertEqual(try repo.cards(for: .n2).count, 2)
        XCTAssertEqual(try repo.cards(for: .n1).count, 2)
    }

    @MainActor
    func test_todayReviewCards_newCardsHaveNilSRSState() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let importer = JMdictImporter(modelContext: context)
        try importer.importEntries(try loadFixtureEntries())

        let repo = SwiftDataLocalRepository(modelContext: context)
        let pairs = try repo.todayReviewCards(limit: 10, level: .n4, now: Date())

        XCTAssertFalse(pairs.isEmpty)
        for (card, state) in pairs {
            XCTAssertEqual(card.jlptLevel, "n4")
            XCTAssertNil(state, "brand-new card should have no SRSState")
        }
    }

    @MainActor
    func test_upsertSRS_createsThenMutates() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let importer = JMdictImporter(modelContext: context)
        try importer.importEntries(try loadFixtureEntries())

        let repo = SwiftDataLocalRepository(modelContext: context)
        let n4Cards = try repo.cards(for: .n4)
        let target = try XCTUnwrap(n4Cards.first)

        let now = Date()
        let initialSnapshot = SRSSnapshot(
            cardID: target.id,
            ease: 2.5,
            intervalDays: 0,
            reps: 0,
            lapses: 0,
            lastReview: nil,
            dueDate: now
        )
        let firstUpdate = SM2.nextState(current: initialSnapshot, quality: .good, now: now)
        try repo.upsertSRS(cardID: target.id, update: firstUpdate, now: now)

        let afterFirst = try context.fetch(FetchDescriptor<SRSState>())
        XCTAssertEqual(afterFirst.count, 1)
        XCTAssertEqual(afterFirst.first?.cardID, target.id)

        let laterNow = now.addingTimeInterval(60 * 60 * 24)
        let postFirstSnapshot = afterFirst.first!.snapshot()
        let secondUpdate = SM2.nextState(current: postFirstSnapshot, quality: .good, now: laterNow)
        try repo.upsertSRS(cardID: target.id, update: secondUpdate, now: laterNow)

        let afterSecond = try context.fetch(FetchDescriptor<SRSState>())
        XCTAssertEqual(afterSecond.count, 1, "upsert should mutate, not create duplicates")
    }
}
