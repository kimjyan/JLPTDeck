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
    var loadStreak: @Sendable () -> Int
    var loadLastStudyDate: @Sendable () -> Date?
    var updateStreak: @Sendable () -> Int
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
            },
            loadStreak: {
                defaults.integer(forKey: "jlpt.streak")
            },
            loadLastStudyDate: {
                defaults.object(forKey: "jlpt.lastStudyDate") as? Date
            },
            updateStreak: {
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())
                let last = (defaults.object(forKey: "jlpt.lastStudyDate") as? Date)
                    .map { calendar.startOfDay(for: $0) }
                let current = defaults.integer(forKey: "jlpt.streak")

                let newStreak: Int
                if let last {
                    if last == today {
                        newStreak = max(current, 1)
                    } else if calendar.date(byAdding: .day, value: 1, to: last) == today {
                        newStreak = current + 1
                    } else {
                        newStreak = 1
                    }
                } else {
                    newStreak = 1
                }
                defaults.set(newStreak, forKey: "jlpt.streak")
                defaults.set(today, forKey: "jlpt.lastStudyDate")
                return newStreak
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
