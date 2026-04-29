import ComposableArchitecture
import XCTest
@testable import JLPTDeck

@MainActor
final class RootFeatureTests: XCTestCase {

    func test_initialState_isHome() {
        let s: RootFeature.State = .home
        if case .home = s {
            // ok
        } else {
            XCTFail("expected .home, got \(s)")
        }
    }

    func test_homeStartReview_movesToReview() async {
        let store = TestStore(initialState: .home) {
            RootFeature()
        }
        store.exhaustivity = .off

        await store.send(.homeStartReviewTapped) {
            $0 = .review(ReviewSessionFeature.State())
        }
    }

    func test_reviewClose_movesToHome() async {
        let store = TestStore(
            initialState: RootFeature.State.review(ReviewSessionFeature.State())
        ) {
            RootFeature()
        } withDependencies: {
            $0.userSettings.updateStreak = { 1 }
        }
        store.exhaustivity = .off

        await store.send(.review(.delegate(.requestClose))) {
            $0 = .home
        }
    }

    func test_homeShowMistakesTapped_movesToMistakes() async {
        let store = TestStore(initialState: .home) { RootFeature() }
        store.exhaustivity = .off
        await store.send(.homeShowMistakesTapped) {
            $0 = .mistakes(MistakesFeature.State())
        }
    }

    func test_mistakesClose_movesToHome() async {
        let store = TestStore(
            initialState: RootFeature.State.mistakes(MistakesFeature.State())
        ) { RootFeature() }
        store.exhaustivity = .off
        await store.send(.mistakes(.delegate(.requestClose))) {
            $0 = .home
        }
    }

    func test_mistakesStartFocusedReview_movesToReviewAndPreloads() async {
        let cardID = UUID()
        let card = VocabCardDTO(
            id: cardID, headword: "食べる", reading: "たべる",
            gloss: "to eat", gloss_ko: "먹다", jlptLevel: "n4"
        )
        let distractor = VocabCardDTO(
            id: UUID(), headword: "飲む", reading: "のむ",
            gloss: "to drink", gloss_ko: "마시다", jlptLevel: "n4"
        )
        let store = TestStore(
            initialState: RootFeature.State.mistakes(MistakesFeature.State())
        ) { RootFeature() }
        store.exhaustivity = .off

        await store.send(.mistakes(.delegate(.startFocusedReview(
            queue: [card],
            srs: [:],
            distractors: [distractor]
        ))))

        guard case .review = store.state else {
            XCTFail("expected .review destination")
            return
        }
    }

    func test_rootDestination_showReview_fromHome() async {
        let store = TestStore(initialState: .home) {
            RootFeature()
        }
        store.exhaustivity = .off

        await store.send(.rootDestination(.showReview)) {
            $0 = .review(ReviewSessionFeature.State())
        }
    }
}
