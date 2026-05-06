# CP2_DIFF_F4 (rev3) — upsert 실패 silent 제거 + retry queue + 비차단 통보

## 변경 vs rev2
rev2 FAIL의 핵심 지적 (`loadError` 폴루션 → ReviewSessionView errorState로 학습 흐름 차단) 처리:

1. **CRITICAL — `loadError` 폴루션 제거**: `.upsertFailed` action에서 `state.loadError = "save failed: ..."` 라인 삭제. 이제 SRS 저장 실패는 `failedUpsertCount`만 증가. `loadError`는 fatal 로드 실패(`.loadResult(.failure)`) 전용으로 정정.
2. **테스트 단언 정정**: `test_upsertFailure_enqueuesAndIncrementsCounter`의 `XCTAssertNotNil(loadError)` → `XCTAssertNil(loadError, "save failures must not pollute loadError")`.
3. **F3 RelearnReducerTests 동조**: `test_retryOfRelearnedCard_skipsSRSAndIncrementsRecoveryCount`가 `loadError == nil`을 카나리아로 쓰던 것을 `failedUpsertCount == 0`으로 강화 (loadError 변경 후에도 미호출 검증 유효).
4. **신규 reducer test**: `test_upsertFailure_doesNotBlockSessionCompletion` — 강제 저장 실패 후에도 세션이 `isComplete == true` + `loadError == nil` 도달 검증. ReviewSessionView가 errorState 분기로 빠지지 않는 reducer 단의 증명.

## 변경 파일 (rev3 추가/수정)
**수정**:
- `JLPTDeck/Features/Review/ReviewSessionFeature.swift` — `.upsertFailed` action에서 `loadError` 세팅 제거 (1곳)
- `JLPTDeckTests/Features/RelearnReducerTests.swift` — 단언 강화 (1곳)
- `JLPTDeckTests/Features/UpsertRetryReducerTests.swift` — 단언 정정 + 신규 테스트 1개

**rev1+rev2+rev3 누적 신규**:
- `JLPTDeck/Domain/SRS/UpsertRetryItem.swift` (모델 + Storage + Drain)
- `JLPTDeck/App/Dependencies/UpsertRetryClient.swift`
- `JLPTDeckTests/SRS/UpsertRetryStorageTests.swift` (6)
- `JLPTDeckTests/SRS/UpsertRetryDrainTests.swift` (4)
- `JLPTDeckTests/Features/UpsertRetryReducerTests.swift` (4 — rev3 +1)

## 핵심 로직 (rev3)

**`.upsertFailed` action — non-blocking**:
```swift
case .internal(.upsertFailed):
    // SRS save failure is non-fatal AND non-blocking. We persist to retry
    // queue (effect-side) and bump the counter for SessionComplete display.
    // We do NOT set loadError — that drives errorState which blocks the UI.
    // loadError is reserved for fatal .loadResult(.failure) only.
    state.failedUpsertCount += 1
    return .none
```

**View 분기는 변경 없음** — `ReviewSessionView`의 기존 `if let err = store.loadError { errorState }` 분기는 그대로. 이제 SRS 실패는 loadError를 안 건드리므로 errorState로 빠지지 않음.

**신규 테스트 — 학습 흐름 보존 증명**:
```swift
// answerTapped(wrong) → upsertFailed (forced throw) → autoAdvance →
// re-queue → answerTapped(correct on retry) → autoAdvance → isComplete
XCTAssertTrue(store.state.isComplete)
XCTAssertNil(store.state.loadError)   // critical: View won't render errorState
XCTAssertEqual(store.state.failedUpsertCount, 1)
XCTAssertEqual(mock.snapshot.count, 1)
```

## 테스트 결과
- **59/59 green** (CP2_EVIDENCE/test_F4_rev3.txt) — rev2 58 + 신규 1
- 빌드: BUILD SUCCEEDED (CP2_EVIDENCE/build_F4_rev3.txt)
- 외부 송신 grep: 0건 (CP2_EVIDENCE/network_grep_F4_rev3.txt)

## 알려진 한계
1. **드물게 사용자가 세션 도중 save 실패를 인지할 채널은 SessionComplete 화면뿐** — 세션 진행 중에는 어떤 시각 알림도 없음. v1.x에서 toast/뱃지 추가 검토.
2. **attemptCount eviction 미구현** — 영구 실패 카드는 매 세션 무한 retry. v1.0 출시 후 측정 → v1.x.
3. **L9 (SwiftData 테스트 부활) 의존**: `.loadResult(.success)` reset path 직접 테스트 부재 (F3 rev2 review 카테고리).
4. **SessionCompleteView 표시 행 라이트/다크 모드 spot check 미수행** — F18(UI-B) 작업에서 확인 필요.

## 롤백
- **재빌드**: `FeatureFlags.upsertRetry = false` → enqueue/drain 모두 skip. `.upsertFailed`는 여전히 `failedUpsertCount`만 증가 (loadError 안 건드림 — rev3 변경은 flag와 무관). legacy "silent + visible 카운터 0" 동작 (사용자에게 보이는 변화 없음).
- **부분**: SessionCompleteView "저장 재시도 예정" 행은 `failedUpsertCount > 0` 가드라 자동 숨김.
- **완전**: 4 신규 파일 + 테스트 3개 삭제 + ReviewSessionFeature/SessionCompleteView/ReviewSessionView git revert.
- **데드라인** (PLAN.md §4): D-5. 빠질 경우 출시 자체 연기.

F4 ready for review (rev3)
