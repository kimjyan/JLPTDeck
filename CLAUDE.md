# JLPTDeck

## 프로젝트 스펙
- iOS 17+, SwiftUI, SwiftData, TCA (1.25+)
- Swift 6.2, Approachable Concurrency (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`)
- SRS 알고리즘: SM-2 (순수 Swift, FSRS 교체 가능)
- 데이터: 7,316 단어 (N4:666 / N3:2140 / N2:1811 / N1:2699), 영어+한국어 뜻 번들
- 학습 방식: 한국어 뜻 4지선다 인식 학습 (정답=.good, 오답=.again 자동 grade)
- 오답 카드 세션 내 재출제 (큐 뒤에 다시 넣기) — F3 이후 같은 세션 재시도는 SRS 분리
- 온보딩: 제거됨 (`98f9947`) — 첫 실행도 홈, 기본값 N4 / 일 20개

## 아키텍처

### The Composable Architecture (TCA)
- 새 피처는 반드시 TCA로 작성. 프로젝트 로컬 skill: `.claude/skills/tca-architecture.md` 를 먼저 읽을 것.
- `@Reducer` + `@ObservableState` + `some Reducer<State, Action>` (NOT `ReducerOf<Self>`)
- `@CasePathable` nested action enums: `ViewAction`/`InternalAction`/`DelegateAction`
- `@Dependency` for LocalRepositoryClient, UserSettingsClient, ContinuousClock, Date, UpsertRetryClient
- `VocabCardDTO` (Sendable value type) for crossing actor boundaries

### TCA Features (완성)
| Feature | State | Key Actions |
|---|---|---|
| `RootFeature` | `.home` / `.review` / `.mistakes` | 라우팅 전환, child delegate 수신, streak update |
| `ReviewSessionFeature` | queue, index, currentQuestion, SRS map, F3~F10 보강 | task/taskWithPreloaded, answerTapped→SM2→upsert+autoAdvance, sessionPreviewLoaded |
| `MistakesFeature` | lapsed cards list, distractorPool | task→load, reviewMistakesTapped→focused review delegate |

### Legacy (유지 중)
- `HomeView` — TabView (홈/통계/설정/틀린단어), `@Environment(UserSettings.self)` 사용
- `StatsView` / `SettingsView` — modelContext 직접 접근, TCA 미전환

### Domain (순수 Swift — TCA 무관)
- `SM2.nextState(current:quality:now:)` — SRS 알고리즘
- `CardScheduler.pickToday(due:newCardIDs:limit:now:)` — 큐 스케줄링
- `QuizGenerator.make(input:distractors:rng:)` — 4지선다 생성
- `RelearnPolicy.shouldUpdateSRS(...)` (F3) — 같은 세션 재시도 분리
- `HiddenCardFilter.apply(...)` (F8) — 숨김 카드 필터
- `LatencyPolicy` + `ResponseLatencyRecord` (F9) — 응답 시간 측정
- `ExportPayload` + `ExportPayloadCodec` (F13) — JSON export 스키마
- `RetentionStats.snapshot(...)` (F15) — D1/D7 pure helper
- `PronunciationTraps.detect(...)` (F17) — 장음/촉음/ん 검출

### Data (SwiftData + Repository)
- `VocabCard` @Model (F12: `pos: String?` optional 추가)
- `SRSState` @Model
- `UserOverride` @Model (F8 — hide / note)
- `AppOpenEvent` @Model (F15 — D1/D7 카운터)
- `LocalRepository` protocol → `SwiftDataLocalRepository`
- `JMdictImporter` — 번들 JSON → SwiftData 벌크 insert

### Feature Flags (`Domain/FeatureFlags.swift`)
HIGH/MED 위험 항목 모두 compile-time flag로 가드:
- `relearnSeparated` (F3), `upsertRetry` (F4), `cardOverride` (F8),
  `responseLatencyTracking` (F9), `dataExport` (F13), `eventCounter` (F15),
  `sessionCompleteCoaching` (F7+F10), `cardPartOfSpeech` (F12),
  `cardTTS` (F16), `cardPronunciationTraps` (F17)
- 모두 default `true`. 회귀 시 OFF + 재빌드 1회로 폴백.

### UI Theme 정책
- 모든 색상은 `Theme.{bg|surface|text|secondary|accent|red|green|orange|...}` 토큰 통과
- 하드코딩 색상 금지 (grep 검증). 의도적 `.foregroundStyle(.white)` 3곳 = accent 배경 버튼 텍스트만 허용
- `Color(light:dark:)` UIColor 동적 트레이트 대응 — 라이트/다크 자동

## 빌드
```bash
xcodebuild -project JLPTDeck.xcodeproj -scheme JLPTDeck \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -skipMacroValidation build
```

## 테스트 (127 unit + 1 UI smoke green)
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
  -only-testing:JLPTDeckTests/MistakesFeatureTests \
  -only-testing:JLPTDeckTests/RelearnPolicyTests \
  -only-testing:JLPTDeckTests/RelearnReducerTests \
  -only-testing:JLPTDeckTests/UpsertRetryStorageTests \
  -only-testing:JLPTDeckTests/UpsertRetryDrainTests \
  -only-testing:JLPTDeckTests/UpsertRetryReducerTests \
  -only-testing:JLPTDeckTests/HideCardReducerTests \
  -only-testing:JLPTDeckTests/HiddenCardFilterTests \
  -only-testing:JLPTDeckTests/HideCardPersistenceTests \
  -only-testing:JLPTDeckTests/LatencyPolicyTests \
  -only-testing:JLPTDeckTests/LatencyReducerTests \
  -only-testing:JLPTDeckTests/ExportPayloadTests \
  -only-testing:JLPTDeckTests/ExportImportPersistenceTests \
  -only-testing:JLPTDeckTests/RetentionStatsTests \
  -only-testing:JLPTDeckTests/AppOpenEventPersistenceTests \
  -only-testing:JLPTDeckTests/SessionPreviewReducerTests \
  -only-testing:JLPTDeckTests/PronunciationTrapsTests
```

### F14 smoke UI test
```bash
xcodebuild test -project JLPTDeck.xcodeproj -scheme JLPTDeck \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -skipMacroValidation \
  -only-testing:JLPTDeckUITests/JLPTDeckUITests/test_smoke_homeToSessionComplete
```
launch arg `-uitest_reset_state` (in-memory store) + `-jlpt.dailyLimit 1` 로 1답 완료 검증.

### F18 라이트/다크 모드 스크린샷 캡처 (CP3.5)
```bash
xcodebuild test -project JLPTDeck.xcodeproj -scheme JLPTDeck \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -skipMacroValidation \
  -only-testing:JLPTDeckUITests/SpotCheckScreenshotTests
```
launch arg `-uitest_force_light/dark`로 색상 모드 강제. xcresult attachments에 16 PNG.

### Deferred tests (SwiftData/Swift 6 host-app deinit crash)
- DistractorCardsTests, JMdictImporterTests, LocalRepositoryTests
- ReviewSessionFeatureTests: answerTapped correct/wrong (disabled_)
- HideCardPersistenceTests: round-trip (disabled_) — schema smoke만 active
- ExportImportPersistenceTests: round-trip (disabled_)
- AppOpenEventPersistenceTests: round-trip (disabled_) — schema smoke만 active
- L9 (post-v1.0)에서 부활 시도. 사용자 메모 `defer-jlptdeck-simulator-crash`가 명시적으로 "do NOT re-attempt fixes" 요구.

## Swift 6.2 Approachable Concurrency 함정
1. `some Reducer<State, Action>` (NOT `some ReducerOf<Self>` — circular ref)
2. Nested action enum은 `ViewAction` (NOT `View` — SwiftUI 충돌)
3. `BindableAction` + `BindingReducer` 매크로 깨짐 → explicit set actions
4. `CancelID`는 file-scope `private nonisolated enum` (main-actor isolation 우회)
5. `-skipMacroValidation` 필수 (TCA macro fingerprint)
6. `@CasePathable` nested enum에 명시 (TestStore receive 에 필수)

## 출시 자료
- `LICENSE` — MIT (소스) + JMdict CC BY-SA 4.0 + Tanos 비공식 추정 명시
- `AppStore/` — App Store Connect 입력 자료 (메타데이터 + 스크린샷 5장)
- `docs/beta-data-sop.md` — 베타 회수 SOP (메인테이너 이메일 토큰 치환 필요)
- `docs/finishing-debt.md` — F18 (UI-B) 정체 메모 + spot check 결과
- `docs/deployment-firebase.md` — Firebase App Distribution 베타 배포 가이드

## 배포 (Firebase App Distribution)
**중요**: 외부 송신 0 원칙 유지 — Firebase SDK 통합 X, IPA 호스팅 + 알림만.

```bash
# 1회 셋업
bundle install --path vendor/bundle
cp .env.example .env  # → FIREBASE_APP_ID 등 입력

# 배포 (빌드 + 업로드 + 테스터 알림)
bundle exec fastlane beta

# 이미 빌드된 IPA만 업로드
bundle exec fastlane beta_existing_ipa ipa_path:./build/fastlane/JLPTDeck.ipa
```

GitHub Actions: `.github/workflows/firebase-distribute.yml` (수동 trigger).
세부 가이드는 `docs/deployment-firebase.md`.
