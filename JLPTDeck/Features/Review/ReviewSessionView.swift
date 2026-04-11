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
        } else if let card = vm.currentCard {
            VStack(spacing: 16) {
                Text("\(vm.index + 1) / \(vm.queue.count)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                FlashcardView(
                    card: card,
                    showBack: Binding(
                        get: { vm.showBack },
                        set: { vm.showBack = $0 }
                    )
                )
                .padding(.horizontal)

                gradeButtons(vm: vm)
                    .padding(.horizontal)
                    .padding(.bottom)
            }
        }
    }

    private func gradeButtons(vm: ReviewSessionViewModel) -> some View {
        HStack(spacing: 8) {
            gradeButton(title: "Again", color: .red, quality: .again, vm: vm)
            gradeButton(title: "Hard", color: .orange, quality: .hard, vm: vm)
            gradeButton(title: "Good", color: .green, quality: .good, vm: vm)
            gradeButton(title: "Easy", color: .blue, quality: .easy, vm: vm)
        }
    }

    private func gradeButton(
        title: String,
        color: Color,
        quality: SRSQuality,
        vm: ReviewSessionViewModel
    ) -> some View {
        Button {
            HapticsManager.tap()
            do {
                try vm.grade(quality)
            } catch {
                loadError = String(describing: error)
            }
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(color.opacity(0.15))
                .foregroundStyle(color)
                .clipShape(RoundedRectangle(cornerRadius: 10))
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
