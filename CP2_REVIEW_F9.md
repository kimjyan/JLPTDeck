# CP2_REVIEW_F9 — PASS_WITH_WARNING

[판정] PASS_WITH_WARNING

## 검증 대상
- `CP2_DIFF_F9.md` rev2
- `PLAN.md` F9 DoD: `responseLatencyMs` 모든 카드 응답에 기록 + `.hard` enum 정의 + 임계 초과 첫 정답 시각 표시 + SM-2 입력 무영향 회귀 테스트
- `FINAL.md` 의도: v1.0에서는 측정/표시만, v1.x L18에서 30일 데이터 기반 `.hard` 활성화

## 근거
- `JLPTDeck/Domain/SRS/LatencyPolicy.swift`에 `ResponseLatencyRecord(cardID, latencyMs, isCorrect, isFirstAttempt, isSlow)`가 추가됐다. rev1의 “느린 첫 정답 ID만 저장하고 실제 responseLatencyMs 분포가 없다”는 결함은 해소됐다.
- `JLPTDeck/Features/Review/ReviewSessionFeature.swift`에서 `answerTapped` 진입 직후, 정답/오답 및 첫 시도/재시도 분기 전에 `state.responseLatencies.append(...)`를 수행한다. 모든 답변 기록이라는 DoD와 맞다.
- 같은 reducer에서 SM-2 입력은 여전히 `isCorrect ? .good : .again`이며 latency 값을 읽지 않는다. `CP2_EVIDENCE/test_F9_rev2.txt`의 `LatencyReducerTests`가 “SM-2 input 무영향”과 record append를 검증한다.
- `JLPTDeck/Features/Review/SessionCompleteView.swift`의 `session.slowFirstAttemptNotice`는 임계 초과 첫 정답 수를 표시한다. `LatencyPolicy.isSlow`도 `>= 5000ms`로 UI 문구 “5초 이상”과 맞춰졌다.
- `JLPTDeck/Features/Review/ReviewSessionView.swift`가 `scenePhase`를 reducer로 전달하고, `.scenePhaseBackgrounded`가 `currentQuestionPresentedAt = nil`로 만든다. 백그라운드 체류 시간이 응답 시간으로 섞이는 rev1 리스크는 줄었다.
- 증거 파일 기준 `CP2_EVIDENCE/test_F9_rev2.txt`는 90/90 green, `CP2_EVIDENCE/build_F9_rev2.txt`는 build succeeded, `CP2_EVIDENCE/network_grep_F9_rev2.txt`는 외부 송신 0건이다.

## F9 고유 질문 답변

[측정 시점 정확?]
카드 질문 생성 시점에 `currentQuestionPresentedAt`을 찍고, `answerTapped`에서 `date.now`와 차이를 계산한다. 측정 위치가 SRS 분기보다 앞이라 첫 시도와 retry 모두 기록된다.

[백그라운드 전환 시 처리?]
비활성/백그라운드 전환 시 timestamp를 폐기하고, 복귀 후 해당 질문의 답은 `latencyMs = nil`로 기록한다. 누적 시간 오염을 막는 선택으로는 타당하다.

[임계값 미정 명시?]
5000ms가 임의값이라는 한계를 DIFF에 명시했다. `PLAN.md` L18의 P75 기반 튜닝 전까지 v1.0에서는 표시용 heuristic으로만 쓰는 조건이면 통과다.

## 남은 경고
- `responseLatencies`는 현재 session state에만 있다. F13 JSON export나 F15 local event store가 이 값을 흡수하지 않으면 `FINAL.md` L18의 “30일 누적 후 .hard 활성화”는 실행 불가능하다. F13/F15 검증 때 이 연결을 다시 본다.
- 백그라운드 복귀 후 첫 답의 `latencyMs = nil` record는 분석에서 반드시 제외해야 한다. nil을 0ms나 fast로 집계하면 slow 비율이 왜곡된다.
- `session.slowFirstAttemptNotice`는 reducer/policy 증거는 있으나 실제 View 렌더링 스냅샷이나 접근성 테스트 증거는 없다. CP2에서는 치명 결함으로 보지 않지만 UI-B에서 재확인 대상이다.

## 질문
F13 또는 F15 중 어느 쪽이 `ResponseLatencyRecord` 배열을 영속/반출 책임으로 가져가는가?
