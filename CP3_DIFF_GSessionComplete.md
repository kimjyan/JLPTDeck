# CP3_DIFF_GSessionComplete — F7 (다음 약속 + streak 사전 동기) + F10 (첫 시도/회복 분리)

## 변경 vs CP2 종료 시점
CP2 끝 SessionComplete는 `correctCount`/`wrongCount` 칩 + retry/hide/slow 알림만. F7/F10은 미부착.

## 변경 파일
**수정**:
- `JLPTDeck/Domain/FeatureFlags.swift` — `sessionCompleteCoaching: Bool = true` 추가
- `JLPTDeck/Features/Review/ReviewSessionFeature.swift` — State 4필드 추가, `sessionPreviewLoaded` action, `.task` 진입 시 `sessionLevel`/`sessionLimit` 캡처, `autoAdvanceFired`→`isComplete` 분기에서 preview effect 발사, `loadResult.success`에서 빈 큐 즉시 완료 시에도 발사, `taskWithPreloaded`/`loadResult.success` 둘 다 reset에 신규 필드 포함
- `JLPTDeck/Features/Review/SessionCompleteView.swift` — 파라미터 재구성: `correctCount`/`wrongCount` → `firstAttemptCorrect`/`firstAttemptWrong`/`relearnedCount`, 신규 `nextDayDueCount`/`streakAfterToday`. F10 첫 시도 정답률 + 회복 K개 행, F7 next-session preview 블록 (내일 N개 + streak 사전 동기 코칭)
- `JLPTDeck/Features/Review/ReviewSessionView.swift` — wiring 갱신 (신규 파라미터 전달)

**신규**:
- `JLPTDeckTests/Features/SessionPreviewReducerTests.swift` — 7 reducer 테스트
- `scripts/add_g_session_complete_files.rb` — pbxproj 등록

## 핵심 로직

**State 추가** (ReviewSessionFeature):
```swift
var sessionLevel: JLPTLevel? = nil   // .task에서 캡처, focused-review는 nil
var sessionLimit: Int = 20
var nextDayDueCount: Int? = nil      // 세션 완료 시 채워짐
var streakAfterToday: Int? = nil
```

**Effect — peek-only 계산**:
```swift
private func sessionPreviewEffect(level: JLPTLevel, limit: Int) -> Effect<Action> {
    let nowSnapshot = date.now
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: nowSnapshot) ?? nowSnapshot
    return .run { [repo, userSettings] send in
        // 1) 내일 due card 수: repo.todayReviewCards(level, tomorrow) → CardScheduler.pickToday
        // 2) streak peek: loadStreak + loadLastStudyDate → after-today 값 산출 (mutation X)
        await send(.internal(.sessionPreviewLoaded(nextDayDue: ..., streakAfterToday: ...)))
    }
}
```

**Streak 사전 동기 로직** (SessionCompleteView):
- `streak == 1`: "오늘 학습으로 1일 시작! 내일도 학습하면 2일 연속"
- `streak > 1`: "N일 연속 학습 ✓ — 내일도 학습 시 N+1일, 거르면 끊김"

**F10 분리 표시**:
- `firstAttemptCorrect/firstAttemptWrong` (= reducer의 correctCount/wrongCount, F3 이후 첫 시도 전용)
- 정답률 = `firstAttemptCorrect / (firstAttemptCorrect+firstAttemptWrong) * 100`, 0 division 방지
- `relearnedCount > 0` 일 때만 "회복 K개" 표시

## 테스트 (추가/회귀)

**신규 7 (SessionPreviewReducerTests)**:
1. `test_sessionPreviewLoaded_setsState` — direct action handling
2. `test_completionFromAutoAdvance_firesPreview` — 답변→complete→preview effect 발사 검증 (yesterday 학습 → today streak +1 = 4)
3. `test_completionFromAutoAdvance_skipsPreviewForFocusedReview` — sessionLevel nil → repo 호출 안 함 (XCTFail trap)
4. `test_streakPeek_sameDayReopen_keepsCurrent` — 같은 날 재오픈 시 streak 5 그대로
5. `test_streakPeek_brokenOrFresh_resetsToOne` — 7일 갭 → 오늘 1일로 리셋
6. `test_taskCapturesSessionLevelAndLimit` — `.task(.n2, 35)` → state 캡처 검증
7. `test_taskWithPreloaded_resetsPreviewFields` — cross-session leak 가드

**회귀**: 기존 108 + 신규 7 = **115/115 green** (CP3_EVIDENCE/test_GSessionComplete.txt)

**빌드**: BUILD SUCCEEDED (CP3_EVIDENCE/build_GSessionComplete.txt)

**외부 송신 grep**: 0건 (CP3_EVIDENCE/network_grep_GSessionComplete.txt)

## 알려진 한계
1. **`nextDayDueCount` 정확도 — upsert race**: preview effect는 `autoAdvanceFired`→`isComplete` 시점에 발사. 세션 마지막 카드의 SRS upsert는 effect-side 비동기로 진행 중일 수 있음. 따라서 "내일 N개" 카운트는 마지막 답이 아직 disk에 반영되지 않은 상태일 수 있다 (±1~3개 오차). 카운트는 동기 부여 표시이지 정확한 메트릭이 아니므로 수용.
2. **Focused-review에서 preview 미표시**: `taskWithPreloaded` 경로(MistakesFeature → focused review)는 `sessionLevel`이 nil이라 preview block 자동 hide. 의도된 동작 — focused review는 lapsed 카드만 다루므로 "내일 복습 예정"이라는 메시지가 부정확함.
3. **Streak peek과 실제 update 분리**: streak 실제 갱신은 `RootFeature` delegate (`requestClose`) 처리에서 `userSettings.updateStreak()` 호출. SessionComplete display는 peek-only. 사용자가 SessionComplete를 보고 닫지 않으면 streak update 안 됨 (앱 강종 시). 알려진 격차.
4. **0개 카드 세션 edge case**: `loadResult(.success)`에서 빈 큐 즉시 complete → preview effect도 발사. 하지만 home 화면이 0개일 때 시작 버튼 비활성화하므로 실 사용 시 도달 어려움.
5. **F18 (UI-B) 영역 미실시**: 신규 preview block의 라이트/다크 모드 spot check, 한글 줄바꿈, 좁은 화면(SE 1세대) 잘림 가능성. F18 작업 시 검증.

## 롤백
- **재빌드 1회**: `FeatureFlags.sessionCompleteCoaching = false` → preview effect 발사 안 함, state는 nil 유지, view는 nil 가드로 자동 hide. 첫 시도/회복 표시(F10)도 위 flag 가드 안에 들어가지 않으므로 별도. F10 만 롤백하려면 view에서 `firstAttemptTotal > 0` 블록을 이전 `correctCount + wrongCount > 0` 칩으로 git revert 필요.
- **부분**: View 행만 숨기고 reducer 로직 유지 — `nextSessionPreview`의 `if nextDayDueCount != nil || streakAfterToday != nil` 가드 변경.
- **완전**: 신규 파일 삭제 + reducer/view git revert + pbxproj 항목 제거.
- **데드라인** (PLAN.md §1): D-3. 빠질 경우 SessionComplete가 CP2 종료 시점 디자인으로 회귀.

G-SessionComplete ready for review
