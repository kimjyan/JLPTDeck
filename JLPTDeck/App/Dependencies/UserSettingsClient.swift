import ComposableArchitecture
import Foundation

/// TCA `@Dependency` client wrapping the legacy `UserSettings` / `UserDefaults`
/// storage. Uses the same keys so legacy `@Observable UserSettings` continues
/// to read/write the same values during the phased migration.
struct UserSettingsClient: Sendable {
    var loadLevel: @Sendable () -> JLPTLevel
    var loadDailyLimit: @Sendable () -> Int
    var loadOnboardingComplete: @Sendable () -> Bool
    var saveLevel: @Sendable (JLPTLevel) -> Void
    var saveDailyLimit: @Sendable (Int) -> Void
    var saveOnboardingComplete: @Sendable (Bool) -> Void
}

extension UserSettingsClient: DependencyKey {
    static let liveValue: UserSettingsClient = {
        let defaults = UserDefaults.standard
        return UserSettingsClient(
            loadLevel: {
                JLPTLevel(rawValue: defaults.string(forKey: "jlpt.level") ?? "n4") ?? .n4
            },
            loadDailyLimit: {
                let v = defaults.integer(forKey: "jlpt.dailyLimit")
                return v == 0 ? 20 : v
            },
            loadOnboardingComplete: {
                defaults.bool(forKey: "jlpt.onboardingComplete")
            },
            saveLevel: { level in
                defaults.set(level.rawValue, forKey: "jlpt.level")
            },
            saveDailyLimit: { v in
                defaults.set(v, forKey: "jlpt.dailyLimit")
            },
            saveOnboardingComplete: { v in
                defaults.set(v, forKey: "jlpt.onboardingComplete")
            }
        )
    }()
}

extension DependencyValues {
    var userSettings: UserSettingsClient {
        get { self[UserSettingsClient.self] }
        set { self[UserSettingsClient.self] = newValue }
    }
}
