import ComposableArchitecture
import Foundation

private nonisolated enum MistakesCancelID: Hashable, Sendable { case load }

@Reducer
struct MistakesFeature {

    @ObservableState
    struct State: Equatable {
        var cards: [VocabCardDTO] = []
        var srsByCardID: [UUID: SRSSnapshot] = [:]
        var lapseCountByID: [UUID: Int] = [:]
        var distractorPool: [VocabCardDTO] = []
        var isLoading: Bool = false
        var loadError: String? = nil
        var delegateRequestedClose: Bool = false
    }

    enum Action: Equatable {
        case view(ViewAction)
        case `internal`(InternalAction)
        case delegate(DelegateAction)

        @CasePathable
        enum ViewAction: Equatable {
            case task(level: JLPTLevel)
            case reviewMistakesTapped
            case closeTapped
        }
        @CasePathable
        enum InternalAction: Equatable {
            case loadResult(Result<LoadPayload, EquatableError>)
        }
        @CasePathable
        enum DelegateAction: Equatable {
            case requestClose
            case startFocusedReview(queue: [VocabCardDTO], srs: [UUID: SRSSnapshot], distractors: [VocabCardDTO])
        }

        struct LoadPayload: Equatable, @unchecked Sendable {
            let cards: [VocabCardDTO]
            let srs: [UUID: SRSSnapshot]
            let lapseCount: [UUID: Int]
            let distractors: [VocabCardDTO]
        }
    }

    @Dependency(\.localRepository) var repo

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .view(.task(level)):
                state.isLoading = true
                state.loadError = nil
                return .run { [repo] send in
                    do {
                        async let mistakes = repo.mistakenCards(level)
                        async let distractors = repo.distractorCards(level, UUID(), 60)
                        let (m, d) = try await (mistakes, distractors)
                        var cards: [VocabCardDTO] = []
                        var srs: [UUID: SRSSnapshot] = [:]
                        var lapse: [UUID: Int] = [:]
                        for pair in m {
                            cards.append(pair.card)
                            if let s = pair.srs {
                                srs[pair.card.id] = s
                                lapse[pair.card.id] = s.lapses
                            }
                        }
                        let payload = Action.LoadPayload(cards: cards, srs: srs, lapseCount: lapse, distractors: d)
                        await send(.internal(.loadResult(.success(payload))))
                    } catch {
                        await send(.internal(.loadResult(.failure(.init(error)))))
                    }
                }
                .cancellable(id: MistakesCancelID.load, cancelInFlight: true)

            case let .internal(.loadResult(.success(payload))):
                state.isLoading = false
                state.cards = payload.cards
                state.srsByCardID = payload.srs
                state.lapseCountByID = payload.lapseCount
                state.distractorPool = payload.distractors
                return .none

            case let .internal(.loadResult(.failure(err))):
                state.isLoading = false
                state.loadError = err.message
                return .none

            case .view(.reviewMistakesTapped):
                guard !state.cards.isEmpty else { return .none }
                return .send(.delegate(.startFocusedReview(
                    queue: state.cards,
                    srs: state.srsByCardID,
                    distractors: state.distractorPool
                )))

            case .view(.closeTapped):
                state.delegateRequestedClose = true
                return .send(.delegate(.requestClose))

            case .delegate:
                return .none
            }
        }
    }
}
