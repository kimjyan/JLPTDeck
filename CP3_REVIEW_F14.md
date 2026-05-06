# CP3_REVIEW_F14 — FAIL

[판정] FAIL

## 검증 대상
- `CP3_DIFF_F14.md`
- `PLAN.md` F14 DoD: XCUITest 1개가 앱 시작 → 자동 import → 홈 → "시작하기" → 1문제 응답 → 완료 화면 도달. CI에서 3회 연속 green
- `FINAL.md` 의도: TestFlight 전 최소 UI smoke로 첫 실행 학습 흐름이 깨졌는지 잡는다

## FAIL 1

[심각도] P0  
[지목] `JLPTDeckUITests/JLPTDeckUITests.swift` `test_smoke_homeToSessionComplete()`  
[문제] smoke가 핵심 실패를 skip으로 처리한다. `startButton.isEnabled == false`이면 `XCTSkip("today count is 0...")`로 빠지므로, 자동 import 실패 / 오늘 카드 0장 / 스케줄러 후보 0장 같은 F14 핵심 경로가 깨져도 CI는 실패하지 않을 수 있다.  
[증거] F14 DoD는 “첫 실행 → 자동 import → 홈 → 시작 → 1문제 → 완료”를 검증하라는 것이다. `CP3_EVIDENCE/test_F14_failing.txt`, `test_F14_run1.txt`, `test_F14_5runs.txt`에는 실제로 이 skip 경로가 기록되어 있다. 이건 smoke gate가 아니라 조건부 미실행이다.  
[질문] `startButton`이 disabled일 때 왜 실패가 아니라 skip이어야 하는가?

## FAIL 2

[심각도] P1  
[지목] `CP3_EVIDENCE/test_F14_5runs_inmem.txt`  
[문제] DIFF의 “5/5 PASS” 증거가 파일 내용과 맞지 않는다. 해당 파일에서 Run 2~5는 pass가 보이지만 Run 1은 appintents warning만 있고 `Test Case ... passed` 또는 `TEST SUCCEEDED`가 없다.  
[증거] `PLAN.md` G4는 smoke 3회 연속 green을 요구한다. Run 2~5 네 번 연속 pass라서 3회 조건 자체는 충족할 수 있지만, “5/5 PASS”라고 쓰면 증거 기술이 부정확하다.  
[질문] Run 1의 실제 `TEST SUCCEEDED` 로그는 어디에 있는가, 아니면 4/4 pass로 정정할 것인가?

## PASS 지점
- `CP3_EVIDENCE/test_F14.txt`의 최종 단독 run은 `test_smoke_homeToSessionComplete`가 실제로 홈 → 시작 → 선택지 탭 → 완료 → 홈 복귀까지 통과했다.
- `CP3_EVIDENCE/build_F14.txt`는 build succeeded다.
- `CP3_EVIDENCE/network_grep_F14.txt`는 외부 송신 0건이다.
- `JLPTDeck/JLPTDeckApp.swift`의 `-uitest_reset_state`는 launch argument가 있을 때만 in-memory store를 쓰므로 production persistence에는 직접 영향이 없다.

## 경고
- 테스트가 12회 random tap에 의존한다. DIFF가 적은 대로 장기 CI에서는 확률적 flake가 남는다. deterministic 정답 선택이나 seeded quiz가 없으면 smoke가 출시 게이트로는 약하다.
- `testLaunchPerformance()`가 아직 남아 있다. F14 DoD 밖이라 실패 사유로 보지는 않지만, UI test suite의 잡음이다.
- 기존 duplicate build file warning은 계속 남아 있다. F14 신규 결함으로 판정하지 않는다.

## 수정 요구
- `startButton.isEnabled == false`를 `XCTFail`로 바꿔라. F14의 목적은 “오늘 카드가 0이면 건너뛰기”가 아니라 “첫 실행 학습 경로가 실제로 가능한지” 확인하는 것이다.
- `test_F14_5runs_inmem.txt`의 Run 1 누락을 보완하거나, DIFF의 “5/5 PASS”를 실제 증거와 맞게 정정하라.
- 가능하면 random tap 대신 정답 accessibility marker를 안정적으로 읽거나 deterministic seed를 주입해 flake를 제거하라.
