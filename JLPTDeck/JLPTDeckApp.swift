import SwiftUI
import SwiftData
import ComposableArchitecture

@main
struct JLPTDeckApp: App {
    @State private var settings = UserSettings()
    @State private var router = AppRouter()

    let sharedModelContainer: ModelContainer

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

        // Install the TCA live `LocalRepositoryClient` now that the container
        // exists. Any Store created after this point inherits the live wiring
        // without needing an explicit `withDependencies` trailing closure.
        prepareDependencies {
            $0.localRepository = .live(container: container)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(router)
        }
        .modelContainer(sharedModelContainer)
    }
}
