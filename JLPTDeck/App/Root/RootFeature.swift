import ComposableArchitecture
import Foundation

@Reducer
struct RootFeature {

    @ObservableState
    enum State: Equatable {
        case onboarding(OnboardingFeature.State)
        case home          // legacy TabView, no state in TCA yet
        case review(ReviewSessionFeature.State)

        static func initial(onboardingComplete: Bool) -> State {
            onboardingComplete ? .home : .onboarding(OnboardingFeature.State())
        }
    }

    enum Action: Equatable {
        case onboarding(OnboardingFeature.Action)
        case review(ReviewSessionFeature.Action)
        case homeStartReviewTapped     // legacy HomeView "시작하기" still bridges via callback

        case rootDestination(RootDestination)

        @CasePathable
        enum RootDestination: Equatable {
            case showOnboarding
            case showHome
            case showReview
        }
    }

    @Dependency(\.userSettings) var settings

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch (state, action) {
            // Onboarding completion → home
            case (.onboarding, .onboarding(.delegate(.completed))):
                state = .home
                return .none

            // Home start review → review
            case (.home, .homeStartReviewTapped):
                state = .review(ReviewSessionFeature.State())
                return .none

            // Review close → home
            case (.review, .review(.delegate(.requestClose))):
                state = .home
                return .none

            // Direct destination changes (used by tests / programmatic navigation)
            case (_, .rootDestination(.showOnboarding)):
                state = .onboarding(OnboardingFeature.State())
                return .none
            case (_, .rootDestination(.showHome)):
                state = .home
                return .none
            case (_, .rootDestination(.showReview)):
                state = .review(ReviewSessionFeature.State())
                return .none

            // Otherwise: no-op at root level
            default:
                return .none
            }
        }
        .ifCaseLet(\.onboarding, action: \.onboarding) {
            OnboardingFeature()
        }
        .ifCaseLet(\.review, action: \.review) {
            ReviewSessionFeature()
        }
    }
}
