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
                Divider()
                Group {
                    if let err = store.loadError {
                        errorState(err)
                    } else if store.isComplete {
                        SessionCompleteView(
                        completedCount: store.queue.count,
                        onDone: { store.send(.view(.closeTapped)) }
                    )
                    } else if let q = store.currentQuestion {
                        VStack(spacing: 16) {
                            Text("\(min(store.index + 1, store.queue.count)) / \(store.queue.count)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
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
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") { store.send(.view(.closeTapped)) }
                }
            }
        }
        .task { await store.send(.view(.task(level: level, limit: dailyLimit))).finish() }
        .onChange(of: store.delegateRequestedClose) { _, requested in
            if requested { onClose() }
        }
    }

    @ViewBuilder
    private func errorState(_ msg: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("불러오기 실패")
                .font(.headline)
            Text(msg).font(.caption).foregroundStyle(.secondary)
            Button("닫기") { store.send(.view(.closeTapped)) }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
