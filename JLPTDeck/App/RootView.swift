import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppRouter.self) private var router
    @Environment(UserSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            switch router.route {
            case .onboarding:
                OnboardingView()
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
