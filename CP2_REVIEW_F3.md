# CP2_REVIEW_F3 — 같은 세션 재시도 SRS 분리

## Verdict

[PASS_WITH_WARNING]

## 근거

PLAN.md DoD:
- learning step 큐 단위 테스트 통과: 충족. `RelearnPolicyTests` 6개 통과.
- 같은 세션 재시도 시 SRS state 변경 없음을 통합 테스트로 확인: 충족. `RelearnReducerTests.test_retryOfRelearnedCard_skipsSRSAndIncrementsRecoveryCount`가 `srsByCardID` 5개 필드 고정과 `loadError == nil` 간접 증명으로 `upsertSRS` 미호출을 검증한다.
- 기존 SRS 회귀 테스트 green: 충족으로 본다. PLAN의 48개 수치는 stale이고, diff가 이를 정직하게 설명했다. rev2 증거는 45/45 green.

FINAL.md 의도:
- "learning step 큐 도입, .again 즉시 SRS 저장 안 함"과 일치한다.
- 첫 오답은 SRS에 `.again`으로 기록되고, 같은 세션 재시도는 SRS를 건드리지 않는다.

증거 확인:
- `CP2_EVIDENCE/build_F3_rev2.txt`: BUILD SUCCEEDED.
- `CP2_EVIDENCE/test_F3_rev2.txt`: TEST SUCCEEDED, 45 tests.
- `CP2_EVIDENCE/network_grep_F3_rev2.txt`: 출력 없음. F3 범위에서 외부 송신 문제 없음.

## F3 고유 질문 답변

- 같은 세션 `.again` 시 ease/interval 불변?  
  첫 오답에서는 `.again`이 정상 저장된다. 이후 같은 세션 재시도에서는 `RelearnPolicy`가 SRS update path를 건너뛰므로 ease/interval/reps/lapses/dueDate가 유지된다. reducer 통합 테스트가 이 상태를 검증한다.

- 무한 루프?  
  자동 무한 루프는 아니다. 사용자가 재시도에서 계속 틀리면 계속 재큐되는 UX는 남아 있지만, 기존 즉시 재노출 정책의 연장이다. F3는 그 반복 재시도가 SRS를 더 오염시키지 않게 만든다.

- feature flag 토글?  
  런타임 토글은 아니다. rev2에서 "재빌드 필요한 compile-time flag"로 표현을 낮췄다. 롤백 게이트로는 최소 충분하다.

## Warning

`ReviewSessionFeature.swift`는 `.taskWithPreloaded`와 `.loadResult(.success)` 양쪽에서 F3 state를 reset한다. 테스트는 `taskWithPreloaded` reset만 검증한다. 일반 로드 경로의 `.loadResult(.success)` reset도 코드상 들어가 있으므로 PASS는 주지만, 다음 reducer 테스트 정리 때 해당 경로를 추가로 고정해라.

또 하나, build evidence에 duplicate build file warning이 계속 나온다. F3 자체 실패는 아니지만 Xcode project hygiene 문제라 다른 CP에서 정리하지 않으면 이후 증거 신뢰도를 계속 갉아먹는다.
