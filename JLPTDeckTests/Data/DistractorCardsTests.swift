import XCTest
import SwiftData
@testable import JLPTDeck

final class DistractorCardsTests: XCTestCase {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([VocabCard.self, SRSState.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// Inserts a fixed set of 8 cards:
    /// - 4 at n4: two share gloss_ko "생각하다", one "먹다", one "가다"
    /// - 4 at n3: two share gloss_ko "보다", one "읽다", one "쓰다"
    /// Returns the inserted cards in insertion order for tests that need specific IDs.
    @MainActor
    @discardableResult
    private func seed(_ context: ModelContext) -> [VocabCard] {
        let cards: [VocabCard] = [
            // n4
            VocabCard(headword: "思う", reading: "おもう", gloss: "to think", gloss_ko: "생각하다", jlptLevel: "n4"),
            VocabCard(headword: "考える", reading: "かんがえる", gloss: "to consider", gloss_ko: "생각하다", jlptLevel: "n4"),
            VocabCard(headword: "食べる", reading: "たべる", gloss: "to eat", gloss_ko: "먹다", jlptLevel: "n4"),
            VocabCard(headword: "行く", reading: "いく", gloss: "to go", gloss_ko: "가다", jlptLevel: "n4"),
            // n3
            VocabCard(headword: "見る", reading: "みる", gloss: "to see", gloss_ko: "보다", jlptLevel: "n3"),
            VocabCard(headword: "観る", reading: "みる", gloss: "to watch", gloss_ko: "보다", jlptLevel: "n3"),
            VocabCard(headword: "読む", reading: "よむ", gloss: "to read", gloss_ko: "읽다", jlptLevel: "n3"),
            VocabCard(headword: "書く", reading: "かく", gloss: "to write", gloss_ko: "쓰다", jlptLevel: "n3"),
        ]
        for card in cards {
            context.insert(card)
        }
        return cards
    }

    @MainActor
    func test_distractorCards_returnsUpToCount_excludingTarget_uniqueGlossKo() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let inserted = seed(context)

        let repo = SwiftDataLocalRepository(modelContext: context)
        // Pick an n4 card to exclude (the "먹다" one to avoid the dedup pair).
        let target = inserted.first { $0.jlptLevel == "n4" && $0.gloss_ko == "먹다" }!

        let result = try repo.distractorCards(level: .n4, excluding: target.id, count: 3)

        XCTAssertLessThanOrEqual(result.count, 3)
        // With pool: 생각하다 (x2 → 1 after dedup), 가다 → 2 distinct gloss_ko remain.
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.allSatisfy { $0.jlptLevel == "n4" })
        XCTAssertFalse(result.contains { $0.id == target.id })
        let glosses = result.map { $0.gloss_ko }
        XCTAssertEqual(Set(glosses).count, glosses.count, "gloss_ko values must be unique")
    }

    @MainActor
    func test_distractorCards_returnsFewerWhenPoolLimited() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let inserted = seed(context)

        let repo = SwiftDataLocalRepository(modelContext: context)
        // Exclude one of the n3 "보다" pair. Remaining distinct gloss_ko at n3:
        // 보다 (the other one), 읽다, 쓰다 → 3 distinct. Ask for 5, expect 3.
        let target = inserted.first { $0.jlptLevel == "n3" && $0.headword == "見る" }!
        let result = try repo.distractorCards(level: .n3, excluding: target.id, count: 5)

        XCTAssertEqual(result.count, 3)
        let glosses = Set(result.map { $0.gloss_ko })
        XCTAssertEqual(glosses, Set(["보다", "읽다", "쓰다"]))
    }

    @MainActor
    func test_distractorCards_countZero_returnsEmpty() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let inserted = seed(context)

        let repo = SwiftDataLocalRepository(modelContext: context)
        let target = inserted.first { $0.jlptLevel == "n4" }!
        let result = try repo.distractorCards(level: .n4, excluding: target.id, count: 0)

        XCTAssertTrue(result.isEmpty)
    }

    @MainActor
    func test_distractorCards_excludesEmptyGlossKo() throws {
        let container = try makeContainer()
        let context = container.mainContext

        // Custom pool: 3 n4 cards, one with empty gloss_ko.
        let withKo1 = VocabCard(headword: "赤", reading: "あか", gloss: "red", gloss_ko: "빨강", jlptLevel: "n4")
        let withKo2 = VocabCard(headword: "青", reading: "あお", gloss: "blue", gloss_ko: "파랑", jlptLevel: "n4")
        let empty = VocabCard(headword: "黒", reading: "くろ", gloss: "black", gloss_ko: "", jlptLevel: "n4")
        let targetCard = VocabCard(headword: "白", reading: "しろ", gloss: "white", gloss_ko: "하양", jlptLevel: "n4")
        context.insert(withKo1)
        context.insert(withKo2)
        context.insert(empty)
        context.insert(targetCard)

        let repo = SwiftDataLocalRepository(modelContext: context)
        let result = try repo.distractorCards(level: .n4, excluding: targetCard.id, count: 5)

        // Should include withKo1 and withKo2, but NOT empty.
        XCTAssertEqual(result.count, 2)
        XCTAssertFalse(result.contains { $0.id == empty.id })
        XCTAssertFalse(result.contains { $0.gloss_ko.isEmpty })
    }
}
