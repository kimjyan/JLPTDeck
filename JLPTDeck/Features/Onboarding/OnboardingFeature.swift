import ComposableArchitecture
import Foundation

private nonisolated enum OnboardingCancelID: Hashable, Sendable { case importJob }

@Reducer
struct OnboardingFeature {
    static let totalSteps = 2

    @ObservableState
    struct State: Equatable {
        var stepIndex: Int = 0
        var selectedLevel: JLPTLevel = .n4
        var dailyLimit: Int = 20
        var isImporting: Bool = false
        var importError: String?
        /// Flipped to `true` once the import pipeline finishes successfully.
        /// The hosting View observes this to bridge back to the legacy
        /// `AppRouter` until Phase 4 (RootFeature) lands.
        var isFinished: Bool = false
    }

    enum Action: Equatable {
        case view(ViewAction)
        case `internal`(InternalAction)
        case delegate(DelegateAction)
        case setLevel(JLPTLevel)
        case setDailyLimit(Int)

        @CasePathable
        enum ViewAction: Equatable {
            case onAppear
            case nextTapped
            case backTapped
            case finishTapped
        }
        @CasePathable
        enum InternalAction: Equatable {
            case importSucceeded
            case importFailed(String)
        }
        @CasePathable
        enum DelegateAction: Equatable {
            case completed
        }
    }

    @Dependency(\.localRepository) var repo
    @Dependency(\.userSettings) var settings

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .view(.onAppear):
                state.selectedLevel = settings.loadLevel()
                state.dailyLimit = settings.loadDailyLimit()
                return .none

            case .view(.nextTapped):
                state.stepIndex = min(state.stepIndex + 1, Self.totalSteps - 1)
                return .none

            case .view(.backTapped):
                state.stepIndex = max(state.stepIndex - 1, 0)
                return .none

            case .view(.finishTapped):
                state.isImporting = true
                state.importError = nil
                settings.saveLevel(state.selectedLevel)
                settings.saveDailyLimit(state.dailyLimit)
                return .run { send in
                    do {
                        try await repo.importIfNeeded()
                        await send(.internal(.importSucceeded))
                    } catch {
                        await send(.internal(.importFailed(String(describing: error))))
                    }
                }
                .cancellable(id: OnboardingCancelID.importJob, cancelInFlight: true)

            case .internal(.importSucceeded):
                state.isImporting = false
                state.isFinished = true
                settings.saveOnboardingComplete(true)
                return .send(.delegate(.completed))

            case .internal(.importFailed(let msg)):
                state.isImporting = false
                state.importError = msg
                return .none

            case .setLevel(let level):
                state.selectedLevel = level
                return .none

            case .setDailyLimit(let limit):
                state.dailyLimit = limit
                return .none

            case .delegate:
                return .none
            }
        }
    }

}
