import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(UserSettings.self) private var settings
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel = OnboardingViewModel()

    var body: some View {
        NavigationStack {
            VStack {
                if viewModel.isImporting {
                    importingView
                } else {
                    stepContent
                }
            }
            .navigationTitle("시작하기")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        VStack(spacing: 24) {
            switch viewModel.stepIndex {
            case 0:
                LevelPickerView()
            default:
                DailyLimitView()
            }

            Spacer()

            HStack {
                if viewModel.stepIndex > 0 {
                    Button("이전") {
                        viewModel.back()
                    }
                    .buttonStyle(.bordered)
                }
                Spacer()
                if viewModel.stepIndex < 1 {
                    Button("다음") {
                        viewModel.next()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("완료") {
                        Task { await runFinish() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    private var importingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("단어를 불러오는 중…")
                .font(.body)
                .foregroundStyle(.secondary)
            if let err = viewModel.importError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding()
            }
        }
    }

    @MainActor
    private func runFinish() async {
        let repo = SwiftDataLocalRepository(modelContext: modelContext)
        await viewModel.finish(repo: repo, settings: settings, router: router)
    }
}
