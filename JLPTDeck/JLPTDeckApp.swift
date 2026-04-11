import SwiftUI
import SwiftData

@main
struct JLPTDeckApp: App {
    @State private var settings = UserSettings()
    @State private var router = AppRouter()

    let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            VocabCard.self,
            SRSState.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(router)
        }
        .modelContainer(sharedModelContainer)
    }
}
