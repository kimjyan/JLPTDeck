import ComposableArchitecture
import XCTest
@testable import JLPTDeck

@MainActor
final class RootFeatureTests: XCTestCase {

    func test_initial_onboardingNotComplete_goesToOnboarding() {
        let s = RootFeature.State.initial(onboardingComplete: false)
        if case .onboarding = s {
            // ok
        } else {
            XCTFail("expected .onboarding, got \(s)")
        }
    }

    func test_initial_onboardingComplete_goesToHome() {
        let s = RootFeature.State.initial(onboardingComplete: true)
        if case .home = s {
            // ok
        } else {
            XCTFail("expected .home, got \(s)")
        }
    }

    func test_onboardingCompleted_movesToHome() async {
        let store = TestStore(
            initialState: RootFeature.State.onboarding(OnboardingFeature.State())
        ) {
            RootFeature()
        }
        store.exhaustivity = .off

        await store.send(.onboarding(.delegate(.completed))) {
            $0 = .home
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
        }
        store.exhaustivity = .off

        await store.send(.review(.delegate(.requestClose))) {
            $0 = .home
        }
    }

    func test_rootDestination_showOnboarding_fromHome() async {
        let store = TestStore(initialState: .home) {
            RootFeature()
        }
        store.exhaustivity = .off

        await store.send(.rootDestination(.showOnboarding)) {
            $0 = .onboarding(OnboardingFeature.State())
        }
    }

    func test_rootDestination_showHome_fromOnboarding() async {
        let store = TestStore(
            initialState: RootFeature.State.onboarding(OnboardingFeature.State())
        ) {
            RootFeature()
        }
        store.exhaustivity = .off

        await store.send(.rootDestination(.showHome)) {
            $0 = .home
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
