# CP2_REVIEW_F8 — 카드 숨기기 + UserOverride

## Verdict

[PASS_WITH_WARNING]

## 근거

PLAN.md DoD:
- 카드 화면 메뉴에서 신고/숨기기 동작: scope가 "숨기기만"으로 정직하게 축소됐다. 원래 문구와는 다르지만 diff가 note/report를 v1.x로 명시했으므로 CP2에서는 hide만 판정한다.
- `userOverride` SwiftData 모델 마이그레이션 통과: 부분 충족. `UserOverride.self`가 schema에 추가됐고 `HideCardPersistenceTests.test_migrationSmoke_v1Schema_acceptsAllModels`가 active로 통과했다. 기존 2-entity store를 새 schema로 여는 진짜 migration test는 아니다.
- 숨김 카드가 다음 세션 큐에서 제외되는 통합 테스트: 자동 통합 테스트는 미충족. 다만 disabled test가 정확히 그 경로를 적고 있고, host-deinit crash 제약을 정직하게 기술했다. 코드상 `setHidden → hiddenCardIDs → todayReviewCards → HiddenCardFilter.apply` 경로는 존재한다.

FINAL.md 의도:
- 원래 "신고/숨기기"였으나 rev2에서 "숨기기"로 범위를 좁혔다.
- 이 범위 변경은 반드시 FINAL/PLAN 또는 CP2 status에 반영해야 한다. 반영하지 않으면 문서와 구현이 다시 어긋난다.

증거 확인:
- `CP2_EVIDENCE/build_F8_rev2.txt`: BUILD SUCCEEDED.
- `CP2_EVIDENCE/test_F8_rev2.txt`: TEST SUCCEEDED, 71 tests.
- `CP2_EVIDENCE/network_grep_F8_rev2.txt`: 출력 없음. 외부 송신 문제 없음.
- `CP2_EVIDENCE/migration_F8.txt`: schema diff, active smoke, disabled integration, real-device migration plan을 기술했다.

## F8 고유 질문 답변

- hide vs note 명확?  
  rev2 기준 명확하다. v1.0은 hide only. `note`는 모델에 있지만 UI 없음, 신고/note는 v1.x다. 단, `UserOverride.swift` 주석의 "hide / report" 표현은 지금 scope와 어긋나므로 고쳐라.

- SwiftData 마이그레이션 누락?  
  완전한 migration 증거는 아니다. active smoke는 "새 schema CRUD 가능" 증거이고, "기존 store → 새 schema" 증거는 manual plan으로 남았다. CP2에서는 warning으로 통과시키지만 TestFlight 전 수동 migration smoke는 필수다.

## Warning

1. 문서 scope를 반드시 정리하라.

PLAN/FINAL/feature flag 주석에 "신고/숨기기", "hide / report"가 남아 있으면 제품 범위가 다시 부풀려진다. CP2 수렴 전에 F8을 "카드 숨기기"로 통일해라.

2. 실제 persistence 통합 테스트는 L9로 넘겨라.

`disabled_test_setHidden_excludesCardFromTodayReview`와 `disabled_test_unhide_returnsCardToTodayReview`가 바로 F8의 핵심 경로다. 지금은 host-deinit crash 때문에 비활성인 것을 인정한다. L9에서 이 두 테스트를 부활시키지 않으면 F8은 장기적으로 계속 약하다.

3. hide persistence 실패 통보는 완료 화면에만 있다.

사용자는 숨긴 즉시 성공했다고 느낀다. 저장 실패가 세션 완료 때만 보이면 원인 연결이 약하다. v1.0 PASS를 막지는 않지만, v1.x에서 즉시 비차단 toast나 메뉴 상태 복구가 필요하다.

4. unhide UI 없음.

의도된 한계로 받아들인다. 대신 Settings/About 쪽에 "숨김 카드 복구는 v1.0 미지원"을 남겨라. 사용자가 실수로 숨기면 현재는 되돌릴 방법이 없다.

5. build duplicate warning은 계속 남아 있다.

F8 실패 사유는 아니지만 새 파일을 추가할수록 warning이 늘고 있다. 증거 신뢰도를 깎는다. 별도 정리 작업에서 Xcode project 중복 build file을 제거해라.
