# CP2_DIFF_F9 (rev2) — 응답 시간 측정 인프라

## 변경 vs rev1
rev1 FAIL의 4개 지적 처리:

1. **CRITICAL — `responseLatencyMs` 진짜 기록**: `ResponseLatencyRecord` 구조체 (`cardID`, `latencyMs`, `isCorrect`, `isFirstAttempt`, `isSlow`) + `state.responseLatencies: [ResponseLatencyRecord]` 배열. v1.x A/B 분석을 위한 분포 데이터 보존.
2. **CRITICAL — 모든 답에서 기록**: 정답/오답, 첫 시도/재시도 무관하게 매 `answerTapped`마다 record append. 분기는 measurement 후로 이동.
3. **백그라운드 처리**: `ViewAction.scenePhaseBackgrounded` + `ReviewSessionView`의 `.onChange(of: scenePhase)` → `currentQuestionPresentedAt = nil`. 백그라운드 후 첫 답은 `latencyMs = nil`로 기록 (분석 시 제외 가능).
4. **UI 문구/정책 정합성**: `LatencyPolicy.isSlow`를 `>` → `>=`로 수정 ("5초 이상" UI 문구와 일치). 테스트 boundary case도 갱신.

## 변경 파일 (rev2)
**수정**:
- `JLPTDeck/Domain/SRS/LatencyPolicy.swift` — `ResponseLatencyRecord` 구조체 추가, `isSlow` boundary `>=`
- `JLPTDeck/Features/Review/ReviewSessionFeature.swift` — `responseLatencies` State, `scenePhaseBackgrounded` action, answerTapped 측정 분기 재구조 (모든 답 기록)
- `JLPTDeck/Features/Review/ReviewSessionView.swift` — `@Environment(\.scenePhase)` + `.onChange` wiring
- `JLPTDeckTests/SRS/LatencyPolicyTests.swift` — boundary 테스트 갱신
- `JLPTDeckTests/Features/LatencyReducerTests.swift` — 신규 3 테스트 추가 (모든 답 기록 / 재시도 isFirstAttempt=false / scenePhaseBackgrounded)

## 핵심 로직 (rev2)

**ResponseLatencyRecord** (Domain pure):
```swift
public struct ResponseLatencyRecord: Equatable, Sendable {
    public let cardID: UUID
    public let latencyMs: Int?           // nil if presentedAt was nil
    public let isCorrect: Bool
    public let isFirstAttempt: Bool
    public let isSlow: Bool
}
```

**Reducer answerTapped — 측정이 분기보다 먼저**:
```swift
let isRetry = !RelearnPolicy.shouldUpdateSRS(...)
if FeatureFlags.responseLatencyTracking {
    let latency = LatencyPolicy.latencyMs(presentedAt: ..., now: date.now)
    let slow = LatencyPolicy.isSlow(latencyMs: latency)
    state.responseLatencies.append(ResponseLatencyRecord(
        cardID: card.id, latencyMs: latency,
        isCorrect: isCorrect, isFirstAttempt: !isRetry, isSlow: slow
    ))
    if !isRetry && isCorrect && slow {
        state.slowFirstAttemptIDs.insert(card.id)   // existing display set
    }
}
// (이후 retry / SM-2 분기. 측정과 무관)
```

**scenePhase wiring**:
```swift
// ReviewSessionView
@Environment(\.scenePhase) private var scenePhase
...
.onChange(of: scenePhase) { _, phase in
    if phase != .active { store.send(.view(.scenePhaseBackgrounded)) }
}
```

## 테스트 결과
- 신규 11 (`LatencyPolicyTests`): nil/negative/zero/sub-second/round / boundary `>=` / threshold 값 / flag default / `.hard` enum 존재 (rev2 boundary 갱신)
- 신규 8 (`LatencyReducerTests`, +3 from rev1): fast correct/slow correct/slow wrong/SM-2 input 무영향/nil presentedAt + **모든 답 record append (rev2) / 재시도 isFirstAttempt=false (rev2) / scenePhaseBackgrounded → 다음 답 latencyMs=nil (rev2)**
- **90/90 green** (CP2_EVIDENCE/test_F9_rev2.txt) — F8 rev2 71 + 11 + 8
- 빌드: BUILD SUCCEEDED (CP2_EVIDENCE/build_F9_rev2.txt)
- 외부 송신 grep: 0건 (CP2_EVIDENCE/network_grep_F9_rev2.txt)

## 알려진 한계
1. **`responseLatencies` 영속화 없음** — 세션 종료 시 사라짐. v1.x에서 F13 JSON export로 함께 export하거나, F15 (이벤트 카운터)와 같은 영속 store에 통합 필요. PLAN L18 A/B 시작 전 결정 필요.
2. **scenePhase wiring은 `ReviewSessionView`만** — 부모 RootView가 다른 destination에 있을 때는 무관. 회복: `ReviewSessionView`가 활성일 때만 작동, 충분.
3. **5000ms 임계는 임의값** — JLPT 단어 인식 표준 분포 데이터 없음. v1.0 베타 측정 후 보정 (`responseLatencies`가 분포 데이터 제공).
4. **카드 메뉴 등 다른 UI 요소 다크 모드 spot check 미수행** — F18(UI-B) 영역.

## 롤백
- **재빌드**: `FeatureFlags.responseLatencyTracking = false` → `currentQuestionPresentedAt`/`responseLatencies`/`slowFirstAttemptIDs` 모두 미세팅 → SessionComplete 행 자동 hide.
- **부분**: 신규 State 필드 유지해도 무해.
- **완전**: `LatencyPolicy.swift` + 테스트 2개 삭제 + ReviewSessionFeature/SessionCompleteView/ReviewSessionView git revert + RootFeatureTests의 date 의존성 라인 제거.
- **데드라인** (PLAN.md §4): D-3.

F9 ready for review (rev2)
