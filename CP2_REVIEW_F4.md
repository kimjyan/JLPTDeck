# CP2_REVIEW_F4 — upsert 실패 silent 제거 + retry queue + 비차단 통보

## Verdict

[PASS_WITH_WARNING]

## 근거

PLAN.md DoD:
- upsert 실패 강제 주입 테스트에서 retry queue 동작: 충족. `test_upsertFailure_enqueuesAndIncrementsCounter`가 실패 주입, queue enqueue, `failedUpsertCount` 증가, `loadError == nil`을 검증한다.
- 세션 종료 화면에 실패 카드 N건 표시: 충족으로 본다. `SessionCompleteView.failedUpsertCount`와 `session.failedUpsertNotice`가 구현됐고 `ReviewSessionView` wiring도 있다.
- 다음 세션 시작 시 retry 큐 처리 통합 테스트 통과: 충족. 성공 drain은 reducer 테스트, 실패/혼합 drain은 `UpsertRetryDrainTests`에서 검증한다.

FINAL.md 의도:
- "retry queue + 세션 종료 시 사용자 통보. 학습 기록 손실 방지"와 일치한다.
- rev3에서 `loadError` 오염을 제거했으므로 저장 실패가 quiz flow를 errorState로 밀어내지 않는다.

증거 확인:
- `CP2_EVIDENCE/build_F4_rev3.txt`: BUILD SUCCEEDED.
- `CP2_EVIDENCE/test_F4_rev3.txt`: TEST SUCCEEDED, 59 tests.
- `CP2_EVIDENCE/network_grep_F4_rev3.txt`: 출력 없음. 외부 송신 문제 없음.

## F4 고유 질문 답변

- retry queue 디스크 저장?  
  예. `UpsertRetryClient.liveValue`가 `UserDefaults.standard` + versioned key `jlpt.upsertRetryQueue.v1`에 저장한다.

- 강제 종료 시 보존?  
  v1.0 기준 통과. `enqueue`가 즉시 `UserDefaults.set`을 수행한다. crash 직전 flush까지 증명한 것은 아니지만, 베타 안전망으로는 충분하다.

- 사용자 통보가 학습 흐름 안 끊나?  
  rev3 기준 예. `.upsertFailed`는 `failedUpsertCount`만 올리고 `loadError`를 건드리지 않는다. `test_upsertFailure_doesNotBlockSessionCompletion`이 저장 실패 후에도 `isComplete == true`, `loadError == nil` 도달을 검증한다.

## Warning

1. 실제 View 렌더링 테스트는 없다.

`SessionCompleteView` 표시 행은 코드상 들어갔고 reducer 상태도 전달된다. 다만 `accessibilityIdentifier("session.failedUpsertNotice")`가 실제 화면에서 보이는 UI 테스트는 없다. F18 또는 smoke UI 테스트에서 한 번 확인해라.

2. `.loadResult(.success)` reset path 직접 테스트가 없다.

F3 때와 같은 경고다. 코드에는 `failedUpsertCount = 0`이 들어가 있지만 직접 reducer 테스트는 `taskWithPreloaded` 중심이다. 다음 reducer 테스트 정리 때 일반 load success path도 고정해라.

3. stale 주석이 남아 있다.

`RelearnReducerTests.swift` 상단과 일부 주석은 아직 "`upsertFailed`가 loadError를 세팅한다"는 옛 설명을 포함한다. 테스트 단언은 고쳐졌지만 문서성 주석이 거짓이면 다음 사람이 잘못된 가정을 한다. 코드 스타일 문제가 아니라 테스트 의도 설명의 정확성 문제다.

4. attemptCount eviction은 없다.

영구 실패 카드는 매 세션 retry된다. diff가 정직하게 한계로 적었고 v1.0 PASS를 막지는 않는다. v1.x에서 `attemptCount > N` 또는 시간 기반 eviction을 넣어라.
