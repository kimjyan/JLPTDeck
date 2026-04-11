import SwiftUI
import SwiftData

struct ReviewSessionView: View {
    @Environment(AppRouter.self) private var router
    @Environment(UserSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext

    @State private var vm: ReviewSessionViewModel?
    @State private var loadError: String?

    var body: some View {
        NavigationStack {
            Group {
                if let vm {
                    content(vm: vm)
                } else if let loadError {
                    VStack(spacing: 12) {
                        Text("불러오기 실패")
                            .font(.headline)
                        Text(loadError)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("닫기") { router.route = .home }
                    }
                    .padding()
                } else {
                    ProgressView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") { router.route = .home }
                }
            }
        }
        .task {
            await loadSession()
        }
    }

    @ViewBuilder
    private func content(vm: ReviewSessionViewModel) -> some View {
        if vm.isComplete {
            SessionCompleteView(completedCount: vm.completedCount)
        } else if let q = vm.currentQuestion {
            VStack(spacing: 16) {
                Text("\(vm.index + 1) / \(vm.queue.count)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                QuizCardView(
                    question: q,
                    selectedIndex: vm.selectedAnswerIndex,
                    isRevealed: vm.isAnswerRevealed
                ) { idx in
                    vm.submitAnswer(idx)
                    if vm.lastAnswerWasCorrect == true {
                        HapticsManager.success()
                    } else {
                        HapticsManager.error()
                    }
                    Task {
                        try? await Task.sleep(nanoseconds: 1_200_000_000)
                        withAnimation { vm.advance() }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
    }

    @MainActor
    private func loadSession() async {
        if vm != nil { return }
        let repo = SwiftDataLocalRepository(modelContext: modelContext)
        let newVM = ReviewSessionViewModel(repo: repo)
        do {
            try await newVM.loadToday(
                level: settings.selectedLevel,
                limit: settings.dailyLimit
            )
            self.vm = newVM
        } catch {
            self.loadError = String(describing: error)
        }
    }
}
