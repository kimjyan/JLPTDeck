import ComposableArchitecture
import Foundation

@Reducer
struct RootFeature {

    @ObservableState
    enum State: Equatable {
        case onboarding(OnboardingFeature.State)
        case home          // legacy TabView, no state in TCA yet
        case review(ReviewSessionFeature.State)
        case mistakes(MistakesFeature.State)

        static func initial(onboardingComplete: Bool) -> State {
            onboardingComplete ? .home : .onboarding(OnboardingFeature.State())
        }
    }

    enum Action: Equatable {
        case onboarding(OnboardingFeature.Action)
        case review(ReviewSessionFeature.Action)
        case mistakes(MistakesFeature.Action)
        case homeStartReviewTapped     // legacy HomeView "시작하기" still bridges via callback
        case homeShowMistakesTapped

        case rootDestination(RootDestination)

        @CasePathable
        enum RootDestination: Equatable {
            case showOnboarding
            case showHome
            case showReview
            case showMistakes
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

            // Home → Mistakes
            case (.home, .homeShowMistakesTapped):
                state = .mistakes(MistakesFeature.State())
                return .none

            // Review close → home
            case (.review, .review(.delegate(.requestClose))):
                state = .home
                return .none

            // Mistakes → Home
            case (.mistakes, .mistakes(.delegate(.requestClose))):
                state = .home
                return .none

            // Mistakes → Review (focused)
            case let (.mistakes, .mistakes(.delegate(.startFocusedReview(queue, srs, distractors)))):
                state = .review(ReviewSessionFeature.State())
                return .send(.review(.view(.taskWithPreloaded(queue: queue, srs: srs, distractors: distractors))))

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
            case (_, .rootDestination(.showMistakes)):
                state = .mistakes(MistakesFeature.State())
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
        .ifCaseLet(\.mistakes, action: \.mistakes) {
            MistakesFeature()
        }
    }
}
