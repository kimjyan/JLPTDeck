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
                onStartReview: { store.send(.homeStartReviewTapped) },
                onShowMistakes: { store.send(.homeShowMistakesTapped) }
            )
        case .review:
            if let scoped = store.scope(state: \.review, action: \.review) {
                ReviewSessionViewLegacyAdapter(store: scoped)
            }
        case .mistakes:
            if let scoped = store.scope(state: \.mistakes, action: \.mistakes) {
                MistakesViewLegacyAdapter(store: scoped)
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

private struct MistakesViewLegacyAdapter: View {
    let store: StoreOf<MistakesFeature>
    @Environment(UserSettings.self) private var settings
    var body: some View {
        MistakesView(
            store: store,
            level: settings.selectedLevel,
            onClose: { /* delegate handles routing */ }
        )
    }
}
