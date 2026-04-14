import ComposableArchitecture
import SwiftUI

struct RootView: View {
    @Bindable var store: StoreOf<RootFeature>

    var body: some View {
        switch store.state {
        case .onboarding:
            if let scoped = store.scope(state: \.onboarding, action: \.onboarding) {
                OnboardingView(store: scoped)
            }
        case .home:
            HomeView(
                onStartReview: { store.send(.homeStartReviewTapped) }
            )
        case .review:
            if let scoped = store.scope(state: \.review, action: \.review) {
                ReviewSessionViewLegacyAdapter(store: scoped)
            }
        }
    }
}

/// Bridge: ReviewSessionView's current API takes level/limit/onClose params,
/// but RootFeature owns navigation. We pass legacy UserSettings for the params
/// and ignore onClose (delegate handles it).
private struct ReviewSessionViewLegacyAdapter: View {
    let store: StoreOf<ReviewSessionFeature>
    @Environment(UserSettings.self) private var settings
    var body: some View {
        ReviewSessionView(
            store: store,
            level: settings.selectedLevel,
            dailyLimit: settings.dailyLimit,
            onClose: { /* delegate handles routing */ }
        )
    }
}
