# CP2_DIFF_F8 (rev2) — 카드 숨기기 + UserOverride

## 변경 vs rev1
rev1 FAIL의 4개 지적 처리:

1. **scope 정직 좁힘**: F8 = "카드 **숨기기**"로 한정. note 입력 / "신고하기" UI는 v1.x로 명시적 defer. 모델의 `note` 필드는 향후 확장용 (현재 미사용 인정).
2. **persistence 통합 테스트 시도**: `HideCardPersistenceTests` 추가. **2개는 documented host-deinit malloc crash 트리거 → `disabled_` 비활성** (CLAUDE.md / `defer-jlptdeck-simulator-crash` 메모 존중). 1개 (migration smoke) 통과.
3. **migration evidence**: `CP2_EVIDENCE/migration_F8.txt` 작성 — schema diff + 자동/수동 증거 + real-device 가정 명시.
4. **`setHidden` 실패 비-silent**: `try?` → `do/catch` + `.internal(.hidePersistenceFailed)` action → `state.hideFailedCount += 1` → SessionCompleteView "숨김 저장 실패 N건 — 다음에 다시 보일 수 있음" 행. F4 패턴과 동형.

## 변경 파일 (rev2 추가)
**신규**:
- `JLPTDeckTests/Data/HideCardPersistenceTests.swift` — 1 active (migration smoke) + 2 `disabled_` (host crash)
- `CP2_EVIDENCE/migration_F8.txt`

**수정** (rev2):
- `JLPTDeck/Features/Review/ReviewSessionFeature.swift` — `hideFailedCount` State + `.hidePersistenceFailed` action + `do/catch` (silent 제거)
- `JLPTDeck/Features/Review/SessionCompleteView.swift` — `hideFailedCount` 파라미터 + 표시 행 (`session.hideFailedNotice`)
- `JLPTDeck/Features/Review/ReviewSessionView.swift` — store wiring
- `JLPTDeckTests/Features/HideCardReducerTests.swift` — `test_setHiddenPersistenceFailure_incrementsCounter` 추가

## 핵심 로직 (rev2 추가)

**비-silent persistence 실패**:
```swift
return .merge(
    .cancel(id: ReviewSessionCancelID.autoAdvance),
    .run { [repo] send in
        do { try await repo.setHidden(cardID, true) }
        catch { await send(.internal(.hidePersistenceFailed)) }
    }
)

case .internal(.hidePersistenceFailed):
    state.hideFailedCount += 1
    return .none
```

**SessionComplete 표시 행** (학습 흐름 비차단):
```swift
if hideFailedCount > 0 {
    HStack { Image("exclamationmark.triangle.fill"); Text("숨김 저장 실패 N건 — 다음에 다시 보일 수 있음") }
        .accessibilityIdentifier("session.hideFailedNotice")
}
```

## 테스트 결과
- 신규 5 (`HideCardReducerTests`): queue 제거+advance / last card → complete / relearn 큐도 제거 / SRS 불변 / **persistence 실패 카운터 (rev2)**
- 신규 6 (`HiddenCardFilterTests`)
- 신규 1 active (`HideCardPersistenceTests.test_migrationSmoke_v1Schema_acceptsAllModels`)
- 신규 2 disabled (host-crash 회피)
- 회귀: **71/71 green** (CP2_EVIDENCE/test_F8_rev2.txt) — F4 rev3 59 + 5 + 6 + 1
- 빌드: BUILD SUCCEEDED (CP2_EVIDENCE/build_F8_rev2.txt)
- Migration evidence: CP2_EVIDENCE/migration_F8.txt
- 외부 송신 grep: 0건 (CP2_EVIDENCE/network_grep_F8_rev2.txt)

## 알려진 한계
1. **`setHidden → todayReviewCards 필터` 자동 통합 테스트 없음** — host 크래시로 비활성. 사용자 메모 `defer-jlptdeck-simulator-crash`가 명시적으로 "do NOT re-attempt fixes" 요구. 대안: `HiddenCardFilter` Domain pure 테스트 + `SwiftDataLocalRepository.todayReviewCards` 코드에 명시적 필터 호출 (코드 review 검증) + 수동 QA. **L9 (SwiftData 테스트 부활)에서 재시도 가능.**
2. **`note` 필드 v1.0 미사용** — UserOverride 모델에 정의됐으나 UI 없음. F8 scope를 "숨기기만"으로 좁힘. 신고/note는 v1.x.
3. **unhide UI 없음** — `setHidden(_, false)`는 모델/repository에 있지만 v1.0 UI는 hide 일방향. v1.x Settings에 "숨김 카드 보기" 추가.
4. **카드 메뉴 UI 다크 모드 spot check 미수행** — F18(UI-B). `docs/finishing-debt.md` 추가 항목.
5. **Migration 실패 시 fatal**: JLPTDeckApp init이 `fatalError`로 떨어짐. 그라ceful fallback (re-import 플로우)은 v1.x.

## 롤백
- **재빌드**: `FeatureFlags.cardOverride = false` → 메뉴 액션 무시 + `todayReviewCards` 필터 skip. 기존 `UserOverride` rows는 보존.
- **부분**: `QuizCardView.onHideCard` nil → 메뉴 즉시 숨김.
- **완전**: 4 신규 파일 + 테스트 3개 삭제 + JLPTDeckApp/LocalRepository/Client/View git revert. SwiftData는 entity 제거 후 재빌드 (UserOverride row 자동 폐기, 다른 데이터 무영향).
- **데드라인** (PLAN.md §4): D-7. 빠질 경우 7일 hotfix SLA 부담 (E3 운영 시간 결정 연계).

F8 ready for review (rev2)
