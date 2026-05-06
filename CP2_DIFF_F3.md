# CP2_DIFF_F3 (rev2) — 같은 세션 재시도 SRS 분리

## 변경 vs rev1
rev1 FAIL의 3개 지적 모두 처리:
1. **CRITICAL — cross-session 상태 누수 수정**: `.taskWithPreloaded` + `.loadResult(.success)`에서 `relearnedCardIDs`/`relearnedCount`/`correctCount`/`wrongCount` 모두 reset.
2. **CRITICAL — reducer integration test 추가**: `RelearnReducerTests` 3개. LockIsolated 우회 (throwing `upsertSRS` + `loadError == nil` 검증).
3. **MINOR — feature flag 표현 정정**: 아래 "롤백" 섹션에서 "재빌드 필요한 compile-time flag"로 명시.

## 변경 파일
**신규** (rev1+rev2 합산):
- `JLPTDeck/Domain/FeatureFlags.swift` — `relearnSeparated: Bool = true` (compile-time)
- `JLPTDeck/Domain/SRS/RelearnPolicy.swift` — 순수 `shouldUpdateSRS(...)`
- `JLPTDeckTests/SRS/RelearnPolicyTests.swift` — 6 단위 테스트
- `JLPTDeckTests/Features/RelearnReducerTests.swift` — 3 reducer integration 테스트 (rev2 신규)
- `scripts/add_f3_files.rb`

**수정**: `JLPTDeck/Features/Review/ReviewSessionFeature.swift` (rev2: 5곳 — State 2필드 추가, answerTapped 분기, autoAdvanceFired 마킹, taskWithPreloaded reset, loadResult reset)

## 핵심 로직 (rev2 추가분)

**세션 로드 시 reset** (cross-session 누수 방지):
```swift
case let .view(.taskWithPreloaded(...)):
    ...
    state.correctCount = 0
    state.wrongCount = 0
    state.relearnedCardIDs = []
    state.relearnedCount = 0
    ...
case let .internal(.loadResult(.success(payload))):
    ...
    state.correctCount = 0
    state.wrongCount = 0
    state.relearnedCardIDs = []
    state.relearnedCount = 0
    ...
```

## 테스트 (rev2)
- 신규 reducer integration 3개 (`RelearnReducerTests`):
  - `test_firstAttemptWrong_marksCardAsRelearnedAndUpdatesSRS` — 첫 오답 시 SM-2 lapses+1, queue append, relearnedCardIDs.insert
  - `test_retryOfRelearnedCard_skipsSRSAndIncrementsRecoveryCount` — 재시도 정답 시 srsByCardID 5필드 모두 pinned, loadError nil (upsertSRS throw → upsertFailed 없으면 미호출 증명), relearnedCount=1
  - `test_taskWithPreloaded_resetsF3State` — 새 세션 로드 시 stale relearnedCardIDs/relearnedCount 모두 0
- 신규 단위 6개 (`RelearnPolicyTests`)
- 회귀: SM2 8 + Scheduler 5 + SRSState 1 + QuizGenerator + Review 4 + Root 7 + Mistakes → **45/45 green** (CP2_EVIDENCE/test_F3_rev2.txt)
- 빌드: BUILD SUCCEEDED (CP2_EVIDENCE/build_F3_rev2.txt)
- 외부 송신 grep: 0건 (CP2_EVIDENCE/network_grep_F3_rev2.txt)

## 알려진 한계
1. **Reducer integration 테스트가 LockIsolated 패턴을 회피했음** — 호출 횟수 직접 카운트 대신 "throw하는 dependency가 호출되면 loadError가 세팅된다"는 간접 증명. 만약 향후 reducer가 `.upsertFailed`의 `loadError` 세팅 동작을 변경하면 이 테스트 가드가 약해짐. 가드 강도 유지하려면 L9 (SwiftData 테스트 부활)에서 LockIsolated 패턴이 재가용해질 때 마이그레이션 필요.
2. **CLAUDE.md "48/48" 표기 stale** — `98f9947` onboarding 제거 후 실제 36. F3 +9 = 45. CLAUDE.md 갱신은 별도 작업 (F19 직전 권장).
3. **`relearnedCount`는 v1.0 SessionComplete UI에 노출 안 됨** — F10/G-SessionComplete가 표시 추가. v1.0 출시 시점에 F10 미완성이면 사용자 비가시.

## 롤백 (수정된 표현)
- **재빌드 필요한 compile-time flag**: `FeatureFlags.relearnSeparated = false` 한 줄 변경 → 모든 답이 SRS에 즉시 반영되는 legacy 동작으로 복귀. 런타임 토글이 아니라 binary 재빌드 필수. TestFlight 새 빌드 푸시까지 ~1시간.
- **부분 롤백**: 새 State 필드(`relearnedCardIDs`, `relearnedCount`)는 유지해도 무해 (use site에서 무시).
- **완전 롤백**: 두 신규 파일 삭제 + ReviewSessionFeature 5곳 git revert + 테스트 2개 파일 삭제.
- **데드라인** (PLAN.md §4): D-5. 빠질 경우 STATUS에 "같은 세션 재시도가 SRS에 즉시 반영" 명시 필수.

F3 ready for review (rev2)
