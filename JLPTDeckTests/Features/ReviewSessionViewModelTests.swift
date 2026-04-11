import XCTest
import SwiftData
@testable import JLPTDeck

@MainActor
final class ReviewSessionViewModelTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([VocabCard.self, SRSState.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func seedCards(_ context: ModelContext, count: Int = 6, level: String = "n4") {
        for i in 0..<count {
            let card = VocabCard(
                headword: "漢字\(i)",
                reading: "かんじ\(i)",
                gloss: "meaning \(i)",
                gloss_ko: "뜻\(i)",
                jlptLevel: level
            )
            context.insert(card)
        }
        try? context.save()
    }

    func test_loadToday_buildsQueueAndQuestion() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedCards(context)
        let repo = SwiftDataLocalRepository(modelContext: context)
        let vm = ReviewSessionViewModel(repo: repo)

        try await vm.loadToday(level: .n4, limit: 5)

        XCTAssertFalse(vm.isComplete)
        XCTAssertEqual(vm.queue.count, 5)
        XCTAssertNotNil(vm.currentQuestion)
        XCTAssertEqual(vm.currentQuestion?.choices.count, 4)
        XCTAssertEqual(vm.selectedAnswerIndex, nil)
        XCTAssertFalse(vm.isAnswerRevealed)
    }

    func test_submitCorrectAnswer_marksGoodAndPersistsState() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedCards(context)
        let repo = SwiftDataLocalRepository(modelContext: context)
        let vm = ReviewSessionViewModel(repo: repo)

        try await vm.loadToday(level: .n4, limit: 5)
        let q = try XCTUnwrap(vm.currentQuestion)

        vm.submitAnswer(q.correctIndex)

        XCTAssertEqual(vm.lastAnswerWasCorrect, true)
        XCTAssertTrue(vm.isAnswerRevealed)

        let states = try context.fetch(FetchDescriptor<SRSState>())
        XCTAssertEqual(states.count, 1)
        let st = try XCTUnwrap(states.first)
        XCTAssertEqual(st.reps, 1, ".good first review should set reps=1")
        XCTAssertEqual(st.lapses, 0)
    }

    func test_submitWrongAnswer_marksAgainAndIncrementsLapses() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedCards(context)
        let repo = SwiftDataLocalRepository(modelContext: context)
        let vm = ReviewSessionViewModel(repo: repo)

        try await vm.loadToday(level: .n4, limit: 5)
        let q = try XCTUnwrap(vm.currentQuestion)
        let wrong = (q.correctIndex + 1) % q.choices.count

        vm.submitAnswer(wrong)

        XCTAssertEqual(vm.lastAnswerWasCorrect, false)

        let states = try context.fetch(FetchDescriptor<SRSState>())
        XCTAssertEqual(states.count, 1)
        let st = try XCTUnwrap(states.first)
        XCTAssertEqual(st.lapses, 1)
        XCTAssertEqual(st.reps, 0)
    }

    func test_advance_resetsStateAndMovesIndex() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedCards(context)
        let repo = SwiftDataLocalRepository(modelContext: context)
        let vm = ReviewSessionViewModel(repo: repo)

        try await vm.loadToday(level: .n4, limit: 5)
        let q = try XCTUnwrap(vm.currentQuestion)
        vm.submitAnswer(q.correctIndex)
        let firstCardID = vm.currentCard?.id

        vm.advance()

        XCTAssertEqual(vm.index, 1)
        XCTAssertNil(vm.selectedAnswerIndex)
        XCTAssertFalse(vm.isAnswerRevealed)
        XCTAssertNil(vm.lastAnswerWasCorrect)
        XCTAssertNotEqual(vm.currentCard?.id, firstCardID)
    }

    func test_secondSubmitDoesNotOverridePersistedState() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        seedCards(context)
        let repo = SwiftDataLocalRepository(modelContext: context)
        let vm = ReviewSessionViewModel(repo: repo)

        try await vm.loadToday(level: .n4, limit: 5)
        let q = try XCTUnwrap(vm.currentQuestion)
        vm.submitAnswer(q.correctIndex)
        // Calling submit again before advance should be a no-op
        vm.submitAnswer((q.correctIndex + 1) % 4)

        XCTAssertEqual(vm.lastAnswerWasCorrect, true) // unchanged
    }
}
