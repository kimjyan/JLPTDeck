import ComposableArchitecture
import SwiftData
import SwiftUI

@main
struct JLPTDeckApp: App {
    @State private var settings = UserSettings()   // legacy, still used by Stats/Settings/Home
    let sharedModelContainer: ModelContainer
    let store: StoreOf<RootFeature>

    init() {
        let schema = Schema([
            VocabCard.self,
            SRSState.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
        self.sharedModelContainer = container

        // Wire TCA dependencies so any Store created after this point inherits
        // live wiring without needing an explicit `withDependencies` closure.
        prepareDependencies {
            $0.localRepository = .live(container: container)
        }

        // Decide initial route from UserDefaults (matches UserSettingsClient key).
        let onboardingDone = UserDefaults.standard.bool(forKey: "jlpt.onboardingComplete")
        let initial = RootFeature.State.initial(onboardingComplete: onboardingDone)

        store = Store(initialState: initial) { RootFeature() }
    }

    var body: some Scene {
        WindowGroup {
            RootView(store: store)
                .environment(settings)
        }
        .modelContainer(sharedModelContainer)
    }
}
