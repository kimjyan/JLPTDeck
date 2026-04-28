# JLPTDeck

## 프로젝트 스펙
- iOS 17+, SwiftUI, SwiftData, TCA (1.25+)
- Swift 6.2, Approachable Concurrency (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`)
- SRS 알고리즘: SM-2 (순수 Swift, FSRS 교체 가능)
- 데이터: 7,316 단어 (N4:666 / N3:2140 / N2:1811 / N1:2699), 영어+한국어 뜻 번들
- 학습 방식: **한국어 4지선다 Active Recall** (정답=.good, 오답=.again 자동 grade)
- 오답 카드 세션 내 재출제 (큐 뒤에 다시 넣기)
- 온보딩: 레벨 선택 → 일일 학습량 설정

## 아키텍처

### The Composable Architecture (TCA)
- **새 피처는 반드시 TCA로 작성**. 프로젝트 로컬 skill: `.claude/skills/tca-architecture.md` 를 먼저 읽을 것.
- `@Reducer` + `@ObservableState` + `some Reducer<State, Action>` (NOT `ReducerOf<Self>`)
- `@CasePathable` nested action enums: `ViewAction`/`InternalAction`/`DelegateAction`
- `@Dependency` for LocalRepositoryClient, UserSettingsClient, ContinuousClock, Date
- `VocabCardDTO` (Sendable value type) for crossing actor boundaries

### TCA Features (완성)
| Feature | State | Key Actions |
|---|---|---|
| `RootFeature` | `.onboarding` / `.home` / `.review` / `.mistakes` | 라우팅 전환, child delegate 수신 |
| `OnboardingFeature` | stepIndex, level, limit, isImporting | task→import→complete delegate |
| `ReviewSessionFeature` | queue, index, currentQuestion, SRS map | task/taskWithPreloaded, answerTapped→SM2→upsert+autoAdvance |
| `MistakesFeature` | lapsed cards list, distractorPool | task→load, reviewMistakesTapped→focused review delegate |

### Legacy (유지 중)
- `HomeView` — TabView (홈/통계/설정/틀린단어), `@Environment(UserSettings.self)` 사용
- `StatsView` / `SettingsView` — modelContext 직접 접근, TCA 미전환

### Domain (순수 Swift — TCA 무관)
- `SM2.nextState(current:quality:now:)` — SRS 알고리즘
- `CardScheduler.pickToday(due:newCardIDs:limit:now:)` — 큐 스케줄링
- `QuizGenerator.make(input:distractors:rng:)` — 4지선다 생성

### Data (SwiftData + Repository)
- `VocabCard` @Model, `SRSState` @Model
- `LocalRepository` protocol → `SwiftDataLocalRepository`
- `JMdictImporter` — 번들 JSON → SwiftData 벌크 insert

## 빌드
```bash
xcodebuild -project JLPTDeck.xcodeproj -scheme JLPTDeck \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -skipMacroValidation build
```

## 테스트 (48/48 green)
```bash
xcodebuild test -project JLPTDeck.xcodeproj -scheme JLPTDeck \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -skipMacroValidation \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1 \
  -only-testing:JLPTDeckTests/SM2Tests \
  -only-testing:JLPTDeckTests/SchedulerTests \
  -only-testing:JLPTDeckTests/SRSStateTests \
  -only-testing:JLPTDeckTests/QuizGeneratorTests \
  -only-testing:JLPTDeckTests/OnboardingFeatureTests \
  -only-testing:JLPTDeckTests/ReviewSessionFeatureTests \
  -only-testing:JLPTDeckTests/RootFeatureTests \
  -only-testing:JLPTDeckTests/MistakesFeatureTests
```

### Deferred tests (SwiftData/Swift 6 host-app deinit crash)
- DistractorCardsTests, JMdictImporterTests, LocalRepositoryTests
- ReviewSessionFeatureTests: answerTapped correct/wrong (disabled_)

## Swift 6.2 Approachable Concurrency 함정
1. `some Reducer<State, Action>` (NOT `some ReducerOf<Self>` — circular ref)
2. Nested action enum은 `ViewAction` (NOT `View` — SwiftUI 충돌)
3. `BindableAction` + `BindingReducer` 매크로 깨짐 → explicit set actions
4. `CancelID`는 file-scope `private nonisolated enum` (main-actor isolation 우회)
5. `-skipMacroValidation` 필수 (TCA macro fingerprint)
6. `@CasePathable` nested enum에 명시 (TestStore receive 에 필수)
