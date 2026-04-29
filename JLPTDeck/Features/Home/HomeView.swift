import SwiftUI
import SwiftData

struct HomeView: View {
    let onStartReview: () -> Void
    let onShowMistakes: () -> Void

    @Environment(UserSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext

    @State private var todayCount: Int = 0
    @State private var streak: Int = 0
    @State private var errorMessage: String?
    @State private var isImporting = false

    var body: some View {
        TabView {
            homeTab
                .tabItem {
                    Label("홈", systemImage: "house.fill")
                }

            StatsView()
                .tabItem {
                    Label("통계", systemImage: "chart.bar.fill")
                }

            mistakesTab
                .tabItem {
                    Label("틀린 단어", systemImage: "exclamationmark.bubble.fill")
                }

            SettingsView()
                .tabItem {
                    Label("설정", systemImage: "gearshape.fill")
                }
        }
    }

    private var mistakesTab: some View {
        VStack {
            Spacer()
            Button {
                onShowMistakes()
            } label: {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.bubble.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Theme.red)
                    Text("틀린 단어 보기").font(.headline).foregroundStyle(Theme.text)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .buttonStyle(.plain)
            Spacer()
        }
    }

    private var homeTab: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                if isImporting {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("단어 불러오는 중...")
                            .font(.footnote)
                            .foregroundStyle(Theme.secondary)
                    }
                } else {
                    if streak > 0 {
                        Label("\(streak)일 연속", systemImage: "flame.fill")
                            .font(.headline)
                            .foregroundStyle(Theme.orange)
                    }

                    Text("오늘 학습할 카드 \(todayCount)개")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Theme.text)

                    Text("\(settings.selectedLevel.rawValue.uppercased()) · \(settings.dailyLimit)개/일")
                        .font(.caption)
                        .foregroundStyle(Theme.secondary)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(Theme.red)
                    }

                    Button {
                        onStartReview()
                    } label: {
                        Text("시작하기")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(todayCount == 0)
                    .padding(.horizontal, 32)
                }

                Spacer()
            }
            .navigationTitle("JLPTDeck")
            .onAppear {
                // Auto-import on first launch (idempotent — skips if cards exist)
                var descriptor = FetchDescriptor<VocabCard>()
                descriptor.fetchLimit = 1
                let count = (try? modelContext.fetchCount(descriptor)) ?? 0
                if count == 0 {
                    isImporting = true
                    let importer = JMdictImporter(modelContext: modelContext, bundle: .main)
                    Task {
                        try? await importer.importIfNeeded()
                        isImporting = false
                        recomputeCount()
                    }
                } else {
                    recomputeCount()
                }
                streak = UserDefaults.standard.integer(forKey: "jlpt.streak")
            }
        }
    }

    private func recomputeCount() {
        let repo = SwiftDataLocalRepository(modelContext: modelContext)
        let now = Date()
        do {
            let pairs = try repo.todayReviewCards(
                limit: settings.dailyLimit,
                level: settings.selectedLevel,
                now: now
            )
            var due: [SRSSnapshot] = []
            var newIDs: [UUID] = []
            for (card, state) in pairs {
                if let state {
                    due.append(state.snapshot())
                } else {
                    newIDs.append(card.id)
                }
            }
            let picks = CardScheduler.pickToday(
                due: due,
                newCardIDs: newIDs,
                limit: settings.dailyLimit,
                now: now
            )
            todayCount = picks.count
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
            todayCount = 0
        }
    }
}
