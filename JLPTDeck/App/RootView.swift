import SwiftUI
import SwiftData
import ComposableArchitecture

struct RootView: View {
    @Environment(AppRouter.self) private var router
    @Environment(UserSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            switch router.route {
            case .onboarding:
                OnboardingView(
                    store: Store(initialState: OnboardingFeature.State()) {
                        OnboardingFeature()
                    },
                    onComplete: {
                        // Keep the legacy @Observable UserSettings in sync so
                        // any remaining consumers see the updated flag.
                        settings.onboardingComplete = true
                        router.route = .home
                    }
                )
            case .home:
                HomeView()
            case .review:
                ReviewSessionView()
            }
        }
        .task {
            // Set initial route from persisted onboarding flag.
            if settings.onboardingComplete {
                router.route = .home
            } else {
                router.route = .onboarding
            }
        }
    }
}
