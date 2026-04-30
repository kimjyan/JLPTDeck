import ComposableArchitecture
import SwiftUI

struct ReviewSessionView: View {
    @Bindable var store: StoreOf<ReviewSessionFeature>
    let level: JLPTLevel
    let dailyLimit: Int
    var onClose: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Group {
                    if let err = store.loadError {
                        errorState(err)
                    } else if store.isComplete {
                        SessionCompleteView(
                        completedCount: store.queue.count,
                        correctCount: store.correctCount,
                        wrongCount: store.wrongCount,
                        onDone: { store.send(.view(.closeTapped)) }
                    )
                    } else if let q = store.currentQuestion {
                        VStack(spacing: 12) {
                            progressBar
                            QuizCardView(
                                question: q,
                                selectedIndex: store.selectedAnswerIndex,
                                isRevealed: store.isAnswerRevealed,
                                onSelect: { idx in
                                    store.send(.view(.answerTapped(idx)))
                                    if idx == q.correctIndex {
                                        HapticsManager.success()
                                    } else {
                                        HapticsManager.error()
                                    }
                                }
                            )
                            .padding(.horizontal)
                            .padding(.bottom)
                        }
                    } else {
                        ProgressView()
                            .tint(Theme.accent)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Theme.bg.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") { store.send(.view(.closeTapped)) }
                        .foregroundStyle(Theme.secondary)
                }
            }
        }
        .tint(Theme.accent)
        .task { await store.send(.view(.task(level: level, limit: dailyLimit))).finish() }
        .onChange(of: store.delegateRequestedClose) { _, requested in
            if requested { onClose() }
        }
    }

    private var progressBar: some View {
        let total = max(store.queue.count, 1)
        let current = min(store.index + 1, store.queue.count)
        return VStack(spacing: 8) {
            HStack {
                Text("\(current) / \(total)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.secondary)
                Spacer()
                if store.correctCount + store.wrongCount > 0 {
                    HStack(spacing: 10) {
                        Label("\(store.correctCount)", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Theme.green)
                        Label("\(store.wrongCount)", systemImage: "xmark.circle.fill")
                            .foregroundStyle(Theme.red)
                    }
                    .font(.system(size: 13, weight: .medium))
                    .labelStyle(.titleAndIcon)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.surface2)
                    Capsule()
                        .fill(Theme.accent)
                        .frame(width: geo.size.width * CGFloat(current) / CGFloat(total))
                        .animation(.easeInOut(duration: 0.25), value: current)
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    @ViewBuilder
    private func errorState(_ msg: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(Theme.orange)
            Text("불러오기 실패")
                .font(.headline)
                .foregroundStyle(Theme.text)
            Text(msg).font(.caption).foregroundStyle(Theme.secondary)
            Button("닫기") { store.send(.view(.closeTapped)) }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
