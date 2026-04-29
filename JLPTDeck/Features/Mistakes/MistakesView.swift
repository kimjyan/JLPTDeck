import ComposableArchitecture
import SwiftUI

/// Root-integrated view. RootView scopes the store and passes legacy UserSettings
/// via a small adapter (mirroring ReviewSessionViewLegacyAdapter).
struct MistakesView: View {
    @Bindable var store: StoreOf<MistakesFeature>
    let level: JLPTLevel
    var onClose: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if store.isLoading {
                    ProgressView()
                } else if let err = store.loadError {
                    errorState(err)
                } else if store.cards.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(store.cards, id: \.id) { card in
                            MistakeRow(
                                card: card,
                                lapses: store.lapseCountByID[card.id] ?? 0,
                                lastReview: store.srsByCardID[card.id]?.lastReview
                            )
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("틀린 단어")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") { store.send(.view(.closeTapped)) }
                }
            }
            .safeAreaInset(edge: .bottom) {
                reviewButton
            }
            .task(id: level) { store.send(.view(.task(level: level))) }
            .onChange(of: store.delegateRequestedClose) { _, closed in
                if closed { onClose() }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.largeTitle)
                .foregroundStyle(Theme.green)
            Text("아직 틀린 단어가 없어요").font(.headline).foregroundStyle(Theme.text)
            Text("복습 중 오답이 생기면 여기에 모입니다.")
                .font(.footnote).foregroundStyle(Theme.secondary)
        }
    }

    @ViewBuilder
    private func errorState(_ msg: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(Theme.orange)
            Text("불러오기 실패").font(.headline).foregroundStyle(Theme.text)
            Text(msg).font(.caption).foregroundStyle(Theme.secondary)
        }
        .padding()
    }

    private var reviewButton: some View {
        Button {
            store.send(.view(.reviewMistakesTapped))
        } label: {
            Text(store.cards.isEmpty ? "복습할 단어가 없어요" : "틀린 단어만 복습 (\(store.cards.count)개)")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .disabled(store.cards.isEmpty)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

private struct MistakeRow: View {
    let card: VocabCardDTO
    let lapses: Int
    let lastReview: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(card.headword).font(.title3).bold().foregroundStyle(Theme.text)
                Text(card.reading).font(.caption).foregroundStyle(Theme.secondary)
                Spacer()
                Text("\(lapses)회 틀림")
                    .font(.caption2)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Theme.redChipBg)
                    .foregroundStyle(Theme.red)
                    .clipShape(Capsule())
            }
            Text(card.gloss_ko).font(.subheadline).foregroundStyle(Theme.secondary)
            if let d = lastReview {
                Text("마지막 복습: \(d.formatted(.relative(presentation: .named)))")
                    .font(.caption2).foregroundStyle(Theme.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}
