import Foundation
import Observation

@Observable
final class OnboardingViewModel {
    var stepIndex: Int = 0
    var isImporting: Bool = false
    var importError: String?

    func next() {
        stepIndex = min(stepIndex + 1, 1)
    }

    func back() {
        stepIndex = max(stepIndex - 1, 0)
    }

    @MainActor
    func finish(
        repo: LocalRepository,
        settings: UserSettings,
        router: AppRouter
    ) async {
        isImporting = true
        defer { isImporting = false }

        settings.onboardingComplete = true
        settings.save()

        do {
            try await repo.importIfNeeded()
        } catch {
            importError = String(describing: error)
            return
        }

        router.route = .home
    }
}
