import ComposableArchitecture
import SwiftUI

struct OnboardingView: View {
    @Bindable var store: StoreOf<OnboardingFeature>
    /// Bridge back to the legacy `AppRouter` until Phase 4 lands RootFeature.
    var onComplete: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                if store.stepIndex == 0 {
                    LevelPickerSection(
                        selection: store.selectedLevel,
                        onChange: { store.send(.setLevel($0)) }
                    )
                } else {
                    DailyLimitSection(
                        limit: store.dailyLimit,
                        onChange: { store.send(.setDailyLimit($0)) }
                    )
                }
                Spacer()
                if store.isImporting {
                    ProgressView("불러오는 중…")
                }
                if let err = store.importError {
                    Text(err).foregroundStyle(.red).font(.footnote)
                }
                controls
            }
            .padding()
            .navigationTitle("설정")
            .task { store.send(.view(.onAppear)) }
            .onChange(of: store.isFinished) { _, newValue in
                if newValue { onComplete() }
            }
        }
    }

    private var controls: some View {
        HStack {
            if store.stepIndex > 0 {
                Button("이전") { store.send(.view(.backTapped)) }
                    .buttonStyle(.bordered)
            }
            Spacer()
            if store.stepIndex == 1 {
                Button("시작") { store.send(.view(.finishTapped)) }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.isImporting)
            } else {
                Button("다음") { store.send(.view(.nextTapped)) }
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

private struct LevelPickerSection: View {
    let selection: JLPTLevel
    let onChange: (JLPTLevel) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("JLPT 레벨").font(.headline)
            Picker("레벨", selection: Binding(get: { selection }, set: onChange)) {
                ForEach(JLPTLevel.allCases, id: \.self) { level in
                    Text(level.rawValue.uppercased()).tag(level)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

private struct DailyLimitSection: View {
    let limit: Int
    let onChange: (Int) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("일일 학습량").font(.headline)
            Stepper(
                value: Binding(get: { limit }, set: onChange),
                in: 10...50,
                step: 5
            ) {
                Text("\(limit) 카드/일")
            }
        }
    }
}
