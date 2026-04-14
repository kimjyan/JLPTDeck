import ComposableArchitecture
import XCTest
@testable import JLPTDeck

@MainActor
final class MistakesFeatureTests: XCTestCase {

    private func makeCard(
        _ id: UUID = UUID(),
        headword: String = "食べる",
        reading: String = "たべる",
        gloss_ko: String = "먹다"
    ) -> VocabCardDTO {
        VocabCardDTO(
            id: id,
            headword: headword,
            reading: reading,
            gloss: "to eat",
            gloss_ko: gloss_ko,
            jlptLevel: "n4"
        )
    }

    private func makeSRS(
        cardID: UUID,
        lapses: Int = 1,
        lastReview: Date = Date()
    ) -> SRSSnapshot {
        SRSSnapshot(
            cardID: cardID,
            ease: 2.5,
            intervalDays: 1,
            reps: 0,
            lapses: lapses,
            lastReview: lastReview,
            dueDate: lastReview.addingTimeInterval(86400)
        )
    }

    func test_task_happyPath_populatesState() async {
        let card1 = makeCard()
        let card2 = makeCard(headword: "飲む", reading: "のむ", gloss_ko: "마시다")
        let pairs: [VocabCardDTO.WithSRS] = [
            .init(card: card1, srs: makeSRS(cardID: card1.id, lapses: 2)),
            .init(card: card2, srs: makeSRS(cardID: card2.id, lapses: 1))
        ]
        let distractors = (0..<5).map { i in
            makeCard(headword: "x\(i)", reading: "x\(i)", gloss_ko: "뜻\(i)")
        }

        let store = TestStore(initialState: MistakesFeature.State()) {
            MistakesFeature()
        } withDependencies: {
            $0.localRepository.mistakenCards = { _ in pairs }
            $0.localRepository.distractorCards = { _, _, _ in distractors }
        }
        store.exhaustivity = .off

        await store.send(.view(.task(level: .n4))) {
            $0.isLoading = true
        }
        await store.receive(\.internal.loadResult.success)

        XCTAssertEqual(store.state.cards.count, 2)
        XCTAssertEqual(store.state.distractorPool.count, 5)
        XCTAssertFalse(store.state.isLoading)
        XCTAssertNil(store.state.loadError)
    }

    func test_task_failurePath_setsError() async {
        struct BoomError: Error {}
        let store = TestStore(initialState: MistakesFeature.State()) {
            MistakesFeature()
        } withDependencies: {
            $0.localRepository.mistakenCards = { _ in throw BoomError() }
            $0.localRepository.distractorCards = { _, _, _ in [] }
        }
        store.exhaustivity = .off

        await store.send(.view(.task(level: .n4)))
        await store.receive(\.internal.loadResult.failure)

        XCTAssertNotNil(store.state.loadError)
        XCTAssertFalse(store.state.isLoading)
    }

    func test_reviewMistakesTapped_emptyCards_noop() async {
        let store = TestStore(initialState: MistakesFeature.State()) {
            MistakesFeature()
        }
        store.exhaustivity = .off

        await store.send(.view(.reviewMistakesTapped))
        // No delegate expected — exhaustivity=.off lets us simply not receive.
    }

    func test_reviewMistakesTapped_nonEmpty_delegatesStartFocusedReview() async {
        let card = makeCard()
        let srs = makeSRS(cardID: card.id, lapses: 2)
        let distractor = makeCard(headword: "飲む", reading: "のむ", gloss_ko: "마시다")

        var initial = MistakesFeature.State()
        initial.cards = [card]
        initial.srsByCardID = [card.id: srs]
        initial.distractorPool = [distractor]

        let store = TestStore(initialState: initial) {
            MistakesFeature()
        }
        store.exhaustivity = .off

        await store.send(.view(.reviewMistakesTapped))
        await store.receive(\.delegate.startFocusedReview) { _ in
            // no state change expected from delegate itself
        }
    }

    func test_closeTapped_delegatesAndFlagsClose() async {
        let store = TestStore(initialState: MistakesFeature.State()) {
            MistakesFeature()
        }
        store.exhaustivity = .off

        await store.send(.view(.closeTapped))
        await store.receive(\.delegate.requestClose)

        XCTAssertTrue(store.state.delegateRequestedClose)
    }
}
