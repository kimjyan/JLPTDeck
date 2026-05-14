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
        .tint(Theme.accent)
    }

    private var mistakesTab: some View {
        NavigationStack {
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("틀린 단어")
        }
    }

    private var homeTab: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                if isImporting {
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(Theme.accent)
                        Text("단어 불러오는 중...")
                            .font(.footnote)
                            .foregroundStyle(Theme.secondary)
                    }
                } else {
                    if streak > 0 {
                        Label("\(streak)일 연속", systemImage: "flame.fill")
                            .font(.headline)
                            .foregroundStyle(Theme.orange)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Theme.orange.opacity(0.12), in: Capsule())
                    }

                    VStack(spacing: 8) {
                        Text("오늘 학습할 카드")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.secondary)
                        Text("\(todayCount)")
                            .font(.system(size: 72, weight: .bold))
                            .tracking(-2)
                            .foregroundStyle(Theme.text)
                            .contentTransition(.numericText())
                        Text("\(settings.selectedLevel.rawValue.uppercased()) · 하루 \(settings.dailyLimit)개")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.tertiary)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(Theme.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    Button {
                        onStartReview()
                    } label: {
                        Text("시작하기")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.buttonRadius)
                                    .fill(todayCount == 0 ? Theme.tertiary : Theme.accent)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(todayCount == 0)
                    .padding(.horizontal, 32)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.bg.ignoresSafeArea())
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
            var allStates: [SRSSnapshot] = []
            var newIDs: [UUID] = []
            for (card, state) in pairs {
                if let state {
                    let snap = state.snapshot()
                    due.append(snap)
                    allStates.append(snap)
                } else {
                    newIDs.append(card.id)
                }
            }
            let alreadyToday = CardScheduler.reviewedTodayCount(
                states: allStates, now: now
            )
            let picks = CardScheduler.pickToday(
                due: due,
                newCardIDs: newIDs,
                limit: settings.dailyLimit,
                now: now,
                alreadyReviewedToday: alreadyToday
            )
            todayCount = picks.count
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
            todayCount = 0
        }
    }
}
