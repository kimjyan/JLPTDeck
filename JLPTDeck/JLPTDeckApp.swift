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
            UserOverride.self,   // F8: per-card hide / report
            AppOpenEvent.self,   // F15: local D1/D7 retention counter
        ])
        // F14 (UI smoke test): when launched with `-uitest_reset_state`,
        // use an in-memory store so each test run starts from a fresh
        // empty DB. The auto-import on HomeView populates new cards on
        // demand. Production launches (no arg) use the on-disk store
        // path unchanged.
        let isUITestReset = ProcessInfo.processInfo.arguments.contains("-uitest_reset_state")
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isUITestReset
        )

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

        store = Store(initialState: .home) { RootFeature() }

        // F15: record one app-open event per launch. Best-effort —
        // failure is non-fatal (debug section just shows fewer days).
        if FeatureFlags.eventCounter {
            let repo = SwiftDataLocalRepository(modelContext: container.mainContext)
            try? repo.recordAppOpen(at: Date())
        }
    }

    /// F18 (CP3.5 screenshots): when launched with
    /// `-uitest_force_dark` or `-uitest_force_light`, override the root
    /// view's color scheme so the screenshot harness can deterministically
    /// capture both modes without flipping system Settings. Production
    /// launches (no arg) inherit the system appearance.
    private var forcedColorScheme: ColorScheme? {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-uitest_force_dark")  { return .dark  }
        if args.contains("-uitest_force_light") { return .light }
        return nil
    }

    var body: some Scene {
        WindowGroup {
            RootView(store: store)
                .environment(settings)
                .preferredColorScheme(forcedColorScheme)
        }
        .modelContainer(sharedModelContainer)
    }
}
