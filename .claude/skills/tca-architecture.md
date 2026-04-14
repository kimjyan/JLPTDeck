---
name: tca-architecture
description: JLPTDeck 프로젝트의 TCA(The Composable Architecture) 규약. SwiftUI/Swift/iOS 코드 작성, Reducer/Feature/State/Action/Effect/Store 설계, 의존성 주입(@Dependency), @Observable ViewModel 리팩터링, 네비게이션 구성, TestStore 테스트 작성 시 반드시 이 skill 을 먼저 로드할 것. JLPTDeck 의 Features/* 아래 신규 파일이나 기존 ViewModel 수정 시에도 자동 적용.
---

# JLPTDeck TCA 규약

이 프로젝트는 UI 레이어를 **TCA (pointfreeco/swift-composable-architecture 1.15+)** 로 점진 전환 중이다. 새 피처는 예외 없이 TCA 로 작성한다.

## 의존성

- Swift Package: `https://github.com/pointfreeco/swift-composable-architecture`
- 최소 버전: **1.15+** (`@Reducer`, `@ObservableState` 매크로 필수)
- iOS 17+, Swift 6
- Xcode 16 synchronized file groups 를 사용하므로 새 파일은 올바른 폴더에 두면 자동 인식

## 파일 구조

각 Feature 는 다음 2~3 파일로 구성한다:

```
JLPTDeck/Features/<FeatureName>/
├── <FeatureName>Feature.swift   // Reducer (State, Action, body)
├── <FeatureName>View.swift       // SwiftUI View + StoreOf<>
└── <FeatureName>ViewModel.swift  // ← 삭제 대상 (기존 @Observable VM)
```

도메인/데이터 레이어는 그대로 유지:

```
JLPTDeck/Domain/   ← 순수 Swift, TCA 에서 Reducer 내부에서 호출
JLPTDeck/Data/     ← SwiftData + LocalRepository, @Dependency 로 래핑
```

## Reducer 표준 형태

```swift
import ComposableArchitecture

@Reducer
struct OnboardingFeature {

    @ObservableState
    struct State: Equatable {
        var stepIndex: Int = 0
        var isImporting: Bool = false
        var importError: String?
        // SwiftData 모델은 state 에 직접 넣지 않는다. UUID 만 들고 필요할 때 repo 로 hydrate.
    }

    enum Action {
        case view(View)
        case `internal`(Internal)
        case delegate(Delegate)

        enum View: Equatable {
            case nextTapped
            case backTapped
            case finishTapped
        }
        enum Internal: Equatable {
            case importFinished(Result<Void, EquatableError>)
        }
        enum Delegate: Equatable {
            case completed
        }
    }

    @Dependency(\.localRepository) var repo
    @Dependency(\.userSettings) var settings

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .view(.nextTapped):
                state.stepIndex += 1
                return .none

            case .view(.finishTapped):
                state.isImporting = true
                return .run { send in
                    do {
                        try await repo.importIfNeeded()
                        await send(.internal(.importFinished(.success(()))))
                    } catch {
                        await send(.internal(.importFinished(.failure(.init(error)))))
                    }
                }
                .cancellable(id: CancelID.import, cancelInFlight: true)

            case .internal(.importFinished(.success)):
                state.isImporting = false
                return .send(.delegate(.completed))

            case .internal(.importFinished(.failure(let err))):
                state.isImporting = false
                state.importError = err.message
                return .none

            case .view, .delegate:
                return .none
            }
        }
    }

    enum CancelID: Hashable { case `import` }
}
```

### 핵심 규칙

1. **Action 은 3-way namespace**: `view` (UI→Reducer), `internal` (async 결과), `delegate` (parent 로 이벤트 버블).
2. **State 는 `Equatable`**. 단, SwiftData `@Model` 객체는 `Equatable` 이 어려우니 `UUID` 만 저장하고 repo 로 fetch.
3. **사이드 이펙트는 `.run { send in ... }`**. 직접 mutate 금지.
4. **취소 가능한 이펙트는 `.cancellable(id:)`**, 매 호출마다 `cancelInFlight: true` 고려.
5. **parent 가 child 에 반응해야 하면 `.delegate` 케이스를 정의**, 직접 parent state 수정 금지.

## 의존성 (Dependencies)

기존 `LocalRepository` 프로토콜과 `UserSettings` 등을 `@Dependency` 로 래핑한다.

```swift
// JLPTDeck/App/Dependencies/LocalRepositoryClient.swift
import ComposableArchitecture
import Foundation

struct LocalRepositoryClient: Sendable {
    var importIfNeeded: @Sendable () async throws -> Void
    var todayReviewCards: @Sendable (_ limit: Int, _ level: JLPTLevel, _ now: Date) async throws -> [(VocabCard, SRSState?)]
    var upsertSRS: @Sendable (_ cardID: UUID, _ update: SRSUpdate, _ now: Date) async throws -> Void
    var distractorCards: @Sendable (_ level: JLPTLevel, _ excluding: UUID, _ count: Int) async throws -> [VocabCard]
}

extension LocalRepositoryClient: DependencyKey {
    static var liveValue: Self {
        // liveValue 구성 시 @MainActor SwiftData ModelContext 에 접근해야 하므로
        // 각 메서드 안에서 `await MainActor.run { ... }` 로 래핑.
        fatalError("wire live in JLPTDeckApp via withDependencies")
    }

    static var testValue: Self = .unimplemented
    static var previewValue: Self = .mock
}

extension DependencyValues {
    var localRepository: LocalRepositoryClient {
        get { self[LocalRepositoryClient.self] }
        set { self[LocalRepositoryClient.self] = newValue }
    }
}
```

**SwiftData 주의사항**: `ModelContext` 는 `@MainActor` 격리이므로 `@Sendable` closure 안에서 직접 쓸 수 없다. `await MainActor.run { modelContext... }` 패턴으로 호출부에서 hop 처리.

## Store 와 View

### Composition Root

```swift
// JLPTDeck/JLPTDeckApp.swift
@main
struct JLPTDeckApp: App {
    let store = Store(initialState: RootFeature.State()) {
        RootFeature()
    } withDependencies: {
        $0.localRepository = .live(modelContainer: sharedModelContainer)
    }

    var body: some Scene {
        WindowGroup { RootView(store: store) }
    }
}
```

### View 바인딩

```swift
struct OnboardingView: View {
    @Bindable var store: StoreOf<OnboardingFeature>

    var body: some View {
        VStack {
            // @ObservableState 덕분에 store.stepIndex 가 바로 관찰됨
            Text("Step \(store.stepIndex)")

            // Picker 같은 양방향 바인딩은 $store.field 로
            // (단, 해당 필드가 State 안에 있고 Action 에 대응 case 가 있어야 함 — BindableAction 사용)

            Button("Next") { store.send(.view(.nextTapped)) }
                .disabled(store.isImporting)
        }
    }
}
```

### 네비게이션

경우에 따라 두 방식 선택:

- **단순 라우팅**: `enum Destination: Equatable { case home, review }` + parent state 에 `var destination: Destination?` + switch 로 뷰 분기
- **스택 네비게이션**: `StackState` + `NavigationStack(path: $store.scope(state: \.path, action: \.path))`
- **현재 `AppRouter.Route` → RootFeature State 의 enum 으로 이식**

## Effect 패턴

### 단순 async 호출
```swift
return .run { send in
    let cards = try await repo.todayReviewCards(limit, level, Date())
    await send(.internal(.queueLoaded(cards)))
}
```

### 타이머 / 지연 후 액션 (예: 자동 advance)
```swift
return .run { send in
    try await Task.sleep(for: .milliseconds(1200))
    await send(.internal(.autoAdvance))
}
.cancellable(id: CancelID.autoAdvance, cancelInFlight: true)
```

### 이펙트 안에서 에러 → `.delegate` 대신 `.internal` 로 흡수 후 표시

## 테스트 (TestStore)

```swift
import ComposableArchitecture
import XCTest
@testable import JLPTDeck

@MainActor
final class OnboardingFeatureTests: XCTestCase {
    func test_finishTapped_triggersImportAndDelegate() async {
        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        } withDependencies: {
            $0.localRepository.importIfNeeded = { /* no-op */ }
        }

        await store.send(.view(.finishTapped)) {
            $0.isImporting = true
        }
        await store.receive(.internal(.importFinished(.success(())))) {
            $0.isImporting = false
        }
        await store.receive(.delegate(.completed))
    }
}
```

### 기존 XCTest 유지

- `SM2Tests`, `SchedulerTests`, `SRSStateTests`, `QuizGeneratorTests` 는 Domain 레이어 테스트이므로 **변경 없음**.
- 기존 `ReviewSessionViewModelTests` 는 Reducer 로 마이그레이션 시 `ReviewSessionFeatureTests` 로 대체.

## 마이그레이션 순서 (향후 별도 plan)

1. **Dependencies 레이어** 세팅 — `LocalRepositoryClient`, `UserSettingsClient`, Date/UUID live/test values
2. **OnboardingFeature** — 단순, 스텝 3개 + Importer 호출 1회
3. **ReviewSessionFeature** — 복잡, `submitAnswer` → SM2 → upsertSRS + `Task.sleep` 자동 advance 를 모두 effect 로 이전
4. **RootFeature** — `AppRouter.Route` 를 RootFeature State 의 destination enum 으로 이식
5. **Stats/Settings Feature** — 마지막, 읽기 전용이라 간단

각 단계마다 25/25 테스트 회귀 실행.

## Swift 6.2 + Approachable Concurrency 함정

이 프로젝트는 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (Approachable Concurrency 활성). 다음 함정 주의:

1. **`some ReducerOf<Self>` 금지** — Swift 6 매크로 expander 가 `Self` 해석 중 circular reference. **`some Reducer<State, Action>` 명시 사용**.
2. **`@Reducer` 안의 nested enum `View`/`Internal`/`Delegate` 명명 주의** — `View` 는 SwiftUI.View 와 충돌. **`ViewAction` / `InternalAction` / `DelegateAction` 사용**.
3. **`BindableAction` + `BindingReducer` 가 매크로 expansion 깨뜨릴 수 있음** — 단순 setter actions (`.setFoo(Foo)`) 로 우회. View 에서 `Binding(get:set:)` 으로 store ↔ binding 어댑트.
4. **CancelID enum 은 file-scope `private nonisolated`** — Reducer 안에 nested 로 두면 main-actor isolated Hashable 이 되어 `.cancellable(id:)` 의 Sendable 제약 위반.
5. **빌드 시 `-skipMacroValidation` 필수** — TCA / 의존 패키지의 macro fingerprint 승인 CLI 우회.

## 금지 사항

- `@Observable` 신규 ViewModel 작성 금지 (기존 것은 마이그레이션 대기 중 유지)
- Reducer 안에서 `try await` 직접 호출 금지 — 반드시 `.run` effect 안에서
- State 에 `ModelContext`, `Store` 참조, non-Equatable 타입 넣기 금지
- `ViewStore` 사용 금지 (구버전 API) — `@Bindable var store` 패턴 고정
- 전역 mutable 싱글톤 접근 금지 — 모두 `@Dependency` 경유
