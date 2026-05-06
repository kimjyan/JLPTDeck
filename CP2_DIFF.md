# CP2_DIFF — HIGH/MED 위험도 통합본 (F3 → F4 → F8 → F9 → F13 → F15)

> 2026-05-06. CP2 (D-7 게이트) 작업의 6개 항목 합본.
> 개별 상세는 `CP2_DIFF_F{N}.md`, 검토 결과는 `CP2_REVIEW_F{N}.md`, 빌드/테스트 로그는 `CP2_EVIDENCE/`.
> F13은 (FAIL→fix→FAIL) 2회 후 deadlock → PM 결정으로 PASS_WITH_BLOCKERS 재분류 (`CP2_DEADLOCK.md`).

## 1. 결과 요약

| F | 항목 | 위험도 | 데드라인 | rev | Verdict | 누적 테스트 |
|---|---|---|---|---|---|---|
| F3 | 같은 세션 재시도 SRS 분리 | HIGH | D-7 | rev2 | PASS_WITH_WARNING | 45/45 |
| F4 | upsert 실패 silent 제거 | HIGH | D-7 | rev3 | PASS_WITH_WARNING | 59/59 |
| F8 | 카드 숨기기 (UserOverride) | HIGH | D-7 | rev2 | PASS_WITH_WARNING | 71/71 |
| F9 | 응답 시간 측정 인프라 | HIGH | D-5 | rev2 | PASS_WITH_WARNING | 90/90 |
| F13 | SRS state JSON export/import | MED | D-5 | rev3 | **PASS_WITH_BLOCKERS** (PM 재정의) | 98/98 |
| F15 | 로컬 익명 이벤트 카운터 (D1/D7) | MED | D-5 | rev1 | PASS_WITH_WARNING | 108/108 |

**테스트**: 36 (CP2 진입 시점) → 108 green. 회귀 0건.
**빌드**: 6개 F 모두 BUILD SUCCEEDED.
**외부 송신 grep**: 6개 F 모두 0건.
**Feature flag**: HIGH 4건 모두 `JLPTDeck/Domain/FeatureFlags.swift` compile-time 상수로 추가 (`relearnSeparated`, `upsertRetry`, `cardOverride`, `responseLatencyTracking`). MED 2건 추가 (`dataExport`, `eventCounter`).

## 2. 변경 파일 (전체)

### 신규 (Domain — pure Swift)
- `JLPTDeck/Domain/FeatureFlags.swift` — F3/F4/F8/F9/F13/F15 6개 compile-time flag
- `JLPTDeck/Domain/SRS/RelearnPolicy.swift` (F3)
- `JLPTDeck/Domain/SRS/UpsertRetryItem.swift` (F4)
- `JLPTDeck/Domain/SRS/HiddenCardFilter.swift` (F8)
- `JLPTDeck/Domain/SRS/LatencyPolicy.swift` (F9 — `ResponseLatencyRecord` 포함)
- `JLPTDeck/Domain/SRS/ExportPayload.swift` (F13 — versioned codec)
- `JLPTDeck/Domain/SRS/RetentionStats.swift` (F15 — D1/D7 pure helper)

### 신규 (Data 레이어)
- `JLPTDeck/Data/Models/UserOverride.swift` (F8 — `@Model`, hide/note)
- `JLPTDeck/Data/Models/AppOpenEvent.swift` (F15 — `@Model`, calendar-day 단위)

### 신규 (App Dependencies)
- `JLPTDeck/App/Dependencies/UpsertRetryClient.swift` (F4)

### 신규 (Settings)
- `JLPTDeck/Features/Settings/JSONFileDocument.swift` (F13 — `FileDocument`)

### 수정 (TCA Reducer)
- `JLPTDeck/Features/Review/ReviewSessionFeature.swift` — F3 (relearn 큐), F4 (`failedUpsertCount`, retry drain), F8 (`hideFailedCount`, hide action), F9 (`responseLatencies`, `scenePhaseBackgrounded`), F13 (export trigger 없음 — Settings에서 처리)
- `JLPTDeck/Features/Review/ReviewSessionView.swift` — `@Environment(\.scenePhase)` (F9), wiring (F4/F8)
- `JLPTDeck/Features/Review/SessionCompleteView.swift` — `failedUpsertCount` (F4), `hideFailedCount` (F8), `slowFirstAttemptNotice` (F9)
- `JLPTDeck/Features/Review/QuizCardView.swift` — 카드 메뉴 (F8 hide)
- `JLPTDeck/Features/Settings/SettingsView.swift` — 데이터 Section (F13 export/import)
- `JLPTDeck/Features/Stats/StatsView.swift` — DEBUG retention section (F15)

### 수정 (Repository / Schema)
- `JLPTDeck/Data/Repository/LocalRepository.swift` — protocol 확장: `setHidden`/`hiddenCardIDs` (F8), `exportSnapshot`/`importSnapshot` (F13), `recordAppOpen`/`appOpenEventDates` (F15) + `SwiftDataLocalRepository` 구현
- `JLPTDeck/App/Dependencies/LocalRepositoryClient.swift` + `+Live.swift` — Sendable 클로저, `@MainActor` 보강 (F8/F13/F15)
- `JLPTDeck/JLPTDeckApp.swift` — Schema에 `UserOverride.self`/`AppOpenEvent.self` 추가, init() best-effort `recordAppOpen` (F15)

### 신규 테스트 (총 +72)
- `JLPTDeckTests/SRS/RelearnPolicyTests.swift` (6, F3)
- `JLPTDeckTests/Features/RelearnReducerTests.swift` (3, F3)
- `JLPTDeckTests/SRS/UpsertRetryStorageTests.swift` (6, F4)
- `JLPTDeckTests/SRS/UpsertRetryDrainTests.swift` (4, F4)
- `JLPTDeckTests/Features/UpsertRetryReducerTests.swift` (4, F4)
- `JLPTDeckTests/Features/HideCardReducerTests.swift` (5, F8)
- `JLPTDeckTests/SRS/HiddenCardFilterTests.swift` (6, F8)
- `JLPTDeckTests/Data/HideCardPersistenceTests.swift` (1 active + 2 disabled, F8)
- `JLPTDeckTests/SRS/LatencyPolicyTests.swift` (11, F9)
- `JLPTDeckTests/Features/LatencyReducerTests.swift` (8, F9)
- `JLPTDeckTests/SRS/ExportPayloadTests.swift` (7, F13)
- `JLPTDeckTests/Data/ExportImportPersistenceTests.swift` (1 active + 1 disabled, F13)
- `JLPTDeckTests/SRS/RetentionStatsTests.swift` (9, F15)
- `JLPTDeckTests/Data/AppOpenEventPersistenceTests.swift` (1 active + 2 disabled, F15)

## 3. 변경 전/후 동작

### F3 — 같은 세션 재시도 SRS 분리 (rev2)
- **전**: 같은 세션 내 오답→재시도 정답이 SM-2에 즉시 `.good`으로 반영되어 첫 시도 신뢰도와 학습기록이 섞임.
- **후**: 첫 오답에만 `.again` SRS 기록, 재시도는 `relearnedCardIDs`에 등록되어 SM-2 호출 차단. `relearnedCount`로 회복 카운트 분리. 새 세션 로드(`taskWithPreloaded`/`loadResult.success`)에서 reset.

### F4 — upsert 실패 silent 제거 (rev3)
- **전**: `try? await repo.upsertSRS(...)` — 실패 시 사용자 통보 없이 학습 기록 손실 가능.
- **후**: 실패 시 `failedUpsertCount` 증가 + `UpsertRetryStorage`에 enqueue + 다음 세션 시작 시 drain. `loadError`는 fatal 로드 실패 전용으로 한정 (학습 흐름 비차단).
- **세션 종료 화면**: `failedUpsertNotice` 행 ("저장 재시도 예정 N건").

### F8 — 카드 숨기기 (rev2)
- **전**: 데이터 결함 신고/숨김 채널 없음. 7일 hotfix SLA 의존.
- **후**: 카드 메뉴 → "이 카드 숨기기" → `UserOverride` `@Model`에 SwiftData 영속 → 다음 세션 큐에서 `HiddenCardFilter`로 제외. 저장 실패 시 `hideFailedCount` 행 표시.
- **scope 좁힘**: `note`/`report` UI는 v1.x로 defer (모델 필드는 향후 확장용 유지).

### F9 — 응답 시간 측정 인프라 (rev2)
- **전**: 응답 시간 측정 인프라 없음. v1.x A/B (L18) 시작 시 0부터 시작해야 함.
- **후**: 모든 `answerTapped`에서 `ResponseLatencyRecord(cardID, latencyMs, isCorrect, isFirstAttempt, isSlow)` append. SM-2 입력은 `isCorrect`로만 (latency 영향 없음). 첫 정답이 5000ms 이상이면 `slowFirstAttemptIDs.insert` → SessionComplete에 "5초 이상 첫 정답 N개" 표시.
- **scenePhase 처리**: 백그라운드 진입 시 `currentQuestionPresentedAt = nil` → 다음 답은 `latencyMs = nil` (분석 시 제외).
- **`.hard` enum 정의**: 미사용 (L18 활성화 대기).

### F13 — SRS state JSON export/import (rev3, PASS_WITH_BLOCKERS)
- **전**: 베타 사용자 데이터 회수 채널 없음. 외부 SDK 거부 정책에서 측정-회수 단절.
- **후 (코드)**: Settings → "백업 내보내기/가져오기" → `JSONFileDocument` + `.fileExporter`/`.fileImporter`. `ExportPayload` versioned schema (`SRSState` 5필드 + `UserOverride.isHidden` + `note`). schema mismatch 시 alert.
- **사람 결정 영역 (PASS_WITH_BLOCKERS)**: 메인테이너 수신 채널, `<maintainer-email-here>` 토큰 치환, manual UI runbook 실행. PLAN.md G3 게이트 + `CP2_DEADLOCK.md` 추적.

### F15 — 로컬 익명 이벤트 카운터 (rev1)
- **전**: D1/D7 측정 채널 없음. 외부 SDK 거부 정책에서 측정 자체 부재.
- **후**: app `init()` 끝에서 best-effort `recordAppOpen(Date.now)` → `AppOpenEvent` `@Model`에 SwiftData 영속. `RetentionStats` pure helper가 calendar day dedup → D1/D7 boolean (또는 nil = 아직 모름) 계산. StatsView DEBUG 영역에서 표시 (`stats.debugRetention`).
- **외부 송신 0**: grep 검증 통과 (`CP2_EVIDENCE/network_grep_F15.txt`).

## 4. 테스트 (추가 / 회귀)

### 회귀
- 기존 36 (Onboarding 제거 후 — `98f9947` 이후) 모두 green 유지. CLAUDE.md "48/48" 표기는 stale (F19에서 갱신 권장).

### 추가 (요약)
- Domain pure: F3 6 + F4 (drain 4 + storage 6) + F8 (filter 6) + F9 (policy 11) + F13 (codec 7) + F15 (stats 9) = **49**
- TCA reducer integration: F3 3 + F4 4 + F8 5 + F9 8 = **20**
- SwiftData persistence (active만): F8 1 + F13 1 + F15 1 = **3** (각 +disabled = 5)

### Disabled (host-deinit malloc crash)
- `defer-jlptdeck-simulator-crash` 사용자 메모 준수 (re-attempt 금지).
- F8: `disabled_test_setHidden_persistsAcrossLaunch` + 1
- F13: `disabled_test_exportImport_roundTrip_persistence` (1)
- F15: `disabled_test_recordAppOpen_roundTrip` + `disabled_test_recordedEvents_drivesRetentionSnapshot`
- L9 (post-v1.0 SwiftData test resurrection) 의존.

## 5. 알려진 한계 (각 F별 1개 이상)

1. **F3**: Reducer integration test가 `LockIsolated` 호출 카운트 직접 검증 대신 "throw하는 dependency가 호출되면 `failedUpsertCount` 증가"로 간접 증명. Reducer 동작 변경 시 가드 약해질 수 있음. L9 의존.
2. **F4**: 영구 실패 카드 (예: 네트워크 영구 단절) 매 세션 무한 retry. attemptCount eviction 미구현, v1.x.
3. **F8**: `setHidden → todayReviewCards 필터` 자동 통합 테스트 없음. host crash로 비활성. `HiddenCardFilter` Domain pure + 코드 review + 수동 QA로 보완.
4. **F9**: `responseLatencies` 영속화 없음 (세션 종료 시 사라짐). v1.x에서 F13 export 또는 F15 store에 통합 결정 필요.
5. **F13**: Repository round-trip 자동 통합 테스트 부재 (host crash) + 메인테이너 수신 채널 미확정 + manual UI runbook 미실행. PASS_WITH_BLOCKERS 분류, G3 게이트 추적.
6. **F15**: Recording은 app `init()` 당 1회 (calendar day 단위면 충분, sub-day 분석은 한계). DEBUG only 표시 — release 빌드는 데이터 누적만, UI 노출 없음.

## 6. 롤백 방법 (요약)

### 부분 롤백 — Feature flag OFF (재빌드 1회, ~1시간)
| F | flag | 효과 |
|---|---|---|
| F3 | `FeatureFlags.relearnSeparated = false` | 모든 답 즉시 SM-2 반영 (legacy) |
| F4 | `FeatureFlags.upsertRetry = false` | retry queue skip, `failedUpsertCount` 안 증가 |
| F8 | `FeatureFlags.cardOverride = false` | 메뉴 액션 무시 + 필터 skip (DB row 보존) |
| F9 | `FeatureFlags.responseLatencyTracking = false` | record append skip, SessionComplete 행 자동 hide |
| F13 | `FeatureFlags.dataExport = false` | Settings 데이터 Section 자동 hide |
| F15 | `FeatureFlags.eventCounter = false` | recordAppOpen skip + debug section hide (DB row 보존) |

### 완전 롤백
- 6개 신규 Domain/Data/Dependencies 파일 + 14개 테스트 파일 삭제
- Reducer/View/Repository/Client/JLPTDeckApp/Schema git revert
- SwiftData entity 제거 (`UserOverride`, `AppOpenEvent`) — 자동 마이그레이션으로 row 폐기, 다른 데이터 무영향

### F별 롤백 데드라인 (PLAN.md §4)
- F4: D-5 (빠질 시 출시 자체 연기 — 학습 기록 손실 직결)
- F3: D-5
- F8: D-7
- F9: D-3
- F13/F15: D-5

## 7. CP2 미해결 / 후속 액션

### 사람 결정 (F13 PASS_WITH_BLOCKERS 잠금)
- H1: 베타 회수 수신 채널 (이메일/GitHub Issues/Form) — TestFlight 제출 전
- H2: `<maintainer-email-here>` 토큰 치환 — H1 결정 후 즉시
- H3: Manual UI runbook 10단계 실행 + Execution Log 작성 — TestFlight 제출 전
- 추적: `PLAN.md` G3 + `CP2_EVIDENCE/manual_qa_F13.txt` Execution Log

### CP3 의존성
- F4 `correctCount` 분리 (rev3에서 별개 카운터로 정리됨) → G-SessionComplete (F7+F10)
- F8 hide 메뉴 + F9 slow 표시 → G-CardView
- F13 export 버튼 → G-Settings/About

### CLAUDE.md 갱신 필요 (F19 권장)
- 테스트 카운트 "48/48" stale → 108/108 + disabled 5
- F3~F15 추가 도메인/액션 요약

---

CP2 코드 작업 완료. CP3 진행 가능 (F2/G-그룹/F14 — D-3 게이트).
