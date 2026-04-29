import Foundation
import Observation

@Observable
final class UserSettings {
    private enum Keys {
        static let level = "jlpt.level"
        static let dailyLimit = "jlpt.dailyLimit"
    }

    var selectedLevel: JLPTLevel
    var dailyLimit: Int

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let raw = defaults.string(forKey: Keys.level),
           let level = JLPTLevel(rawValue: raw) {
            self.selectedLevel = level
        } else {
            self.selectedLevel = .n4
        }

        let storedLimit = defaults.integer(forKey: Keys.dailyLimit)
        self.dailyLimit = storedLimit > 0 ? storedLimit : 20
    }

    func save() {
        defaults.set(selectedLevel.rawValue, forKey: Keys.level)
        defaults.set(dailyLimit, forKey: Keys.dailyLimit)
    }
}
