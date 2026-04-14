import SwiftUI
import SwiftData

struct HomeView: View {
    let onStartReview: () -> Void

    @Environment(UserSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext

    @State private var todayCount: Int = 0
    @State private var errorMessage: String?

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

            SettingsView()
                .tabItem {
                    Label("설정", systemImage: "gearshape.fill")
                }
        }
    }

    private var homeTab: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                Text("오늘 학습할 카드 \(todayCount)개")
                    .font(.title)
                    .fontWeight(.semibold)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
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

                Spacer()
            }
            .navigationTitle("JLPTDeck")
            .onAppear(perform: recomputeCount)
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
