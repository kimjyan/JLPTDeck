import ComposableArchitecture
import XCTest
@testable import JLPTDeck

@MainActor
final class OnboardingFeatureTests: XCTestCase {

    func test_initialState_defaults() {
        let s = OnboardingFeature.State()
        XCTAssertEqual(s.stepIndex, 0)
        XCTAssertEqual(s.selectedLevel, .n4)
        XCTAssertEqual(s.dailyLimit, 20)
        XCTAssertFalse(s.isImporting)
        XCTAssertNil(s.importError)
        XCTAssertFalse(s.isFinished)
    }

    func test_onAppear_loadsSettingsValues() async {
        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        } withDependencies: {
            $0.userSettings.loadLevel = { .n2 }
            $0.userSettings.loadDailyLimit = { 35 }
            $0.userSettings.loadOnboardingComplete = { false }
            $0.userSettings.saveLevel = { _ in }
            $0.userSettings.saveDailyLimit = { _ in }
            $0.userSettings.saveOnboardingComplete = { _ in }
        }
        await store.send(.view(.onAppear)) {
            $0.selectedLevel = .n2
            $0.dailyLimit = 35
        }
    }

    func test_nextTapped_advancesUpToOne() async {
        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        }
        await store.send(.view(.nextTapped)) { $0.stepIndex = 1 }
        // Already at cap — no state change.
        await store.send(.view(.nextTapped))
    }

    func test_backTapped_floorsAtZero() async {
        var initial = OnboardingFeature.State()
        initial.stepIndex = 1
        let store = TestStore(initialState: initial) {
            OnboardingFeature()
        }
        await store.send(.view(.backTapped)) { $0.stepIndex = 0 }
        // Already floored — no state change.
        await store.send(.view(.backTapped))
    }

    func test_setLevel_mutates() async {
        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        }
        await store.send(.setLevel(.n1)) { $0.selectedLevel = .n1 }
    }

    func test_setDailyLimit_mutates() async {
        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        }
        await store.send(.setDailyLimit(40)) { $0.dailyLimit = 40 }
    }

    func test_finishTapped_success_savesAndCompletes() async {
        let savedLevel = LockIsolated<JLPTLevel?>(nil)
        let savedLimit = LockIsolated<Int?>(nil)
        let savedComplete = LockIsolated<Bool?>(nil)

        var initial = OnboardingFeature.State()
        initial.selectedLevel = .n3
        initial.dailyLimit = 30

        let store = TestStore(initialState: initial) {
            OnboardingFeature()
        } withDependencies: {
            $0.localRepository.importIfNeeded = { /* success */ }
            $0.userSettings.loadLevel = { .n4 }
            $0.userSettings.loadDailyLimit = { 20 }
            $0.userSettings.loadOnboardingComplete = { false }
            $0.userSettings.saveLevel = { level in savedLevel.setValue(level) }
            $0.userSettings.saveDailyLimit = { v in savedLimit.setValue(v) }
            $0.userSettings.saveOnboardingComplete = { v in savedComplete.setValue(v) }
        }

        await store.send(.view(.finishTapped)) {
            $0.isImporting = true
            $0.importError = nil
        }
        await store.receive(\.internal.importSucceeded) {
            $0.isImporting = false
            $0.isFinished = true
        }
        await store.receive(\.delegate.completed)

        XCTAssertEqual(savedLevel.value, .n3)
        XCTAssertEqual(savedLimit.value, 30)
        XCTAssertEqual(savedComplete.value, true)
    }

    func test_finishTapped_failure_setsErrorNoComplete() async {
        struct BoomError: Error {}
        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        } withDependencies: {
            $0.localRepository.importIfNeeded = { throw BoomError() }
            $0.userSettings.loadLevel = { .n4 }
            $0.userSettings.loadDailyLimit = { 20 }
            $0.userSettings.loadOnboardingComplete = { false }
            $0.userSettings.saveLevel = { _ in }
            $0.userSettings.saveDailyLimit = { _ in }
            $0.userSettings.saveOnboardingComplete = { _ in }
        }

        await store.send(.view(.finishTapped)) {
            $0.isImporting = true
            $0.importError = nil
        }
        await store.receive(\.internal.importFailed) {
            $0.isImporting = false
            $0.importError = String(describing: BoomError())
        }
        // No .delegate(.completed) follow-up — TestStore would fail on unhandled action.
    }
}
