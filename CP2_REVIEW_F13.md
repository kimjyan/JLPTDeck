# CP2_REVIEW_F13 — FAIL

[판정] FAIL

## 검증 대상
- `CP2_DIFF_F13.md` rev3
- `PLAN.md` F13 DoD: Settings export 버튼 → UIDocumentPicker 호출 → JSON 파일 저장 + import 역방향도 동작 + export/import round-trip 테스트 통과 (SRS state + userOverride 포함)
- `FINAL.md` 의도: 베타 데이터 보존 안전망이며, F13 export 인프라를 베타 데이터 회수 채널로 겸용

## FAIL 1

[심각도] P0  
[지목] `CP2_EVIDENCE/manual_qa_F13.txt`  
[문제] F13의 핵심 DoD인 export/import round-trip 통과가 아직 없다. rev3는 이 사실을 정직하게 표시했지만, `EXECUTION STATUS: NOT YET EXECUTED`, `Repository round-trip: BLOCKED`, `Manual UI round-trip: SCHEDULED`라고 적힌 상태는 PASS가 아니다.  
[증거] `PLAN.md` F13은 “export/import round-trip 테스트 통과”를 요구한다. 현재 자동 증거는 codec round-trip과 schema smoke뿐이고, 실제 `SwiftData exportSnapshot → JSON → importSnapshot → SwiftData fetch` 비교 결과는 비어 있다.  
[질문] TestFlight 제출 전 실제 실행 로그가 채워질 때까지 F13을 CP2 완료로 볼 수 없다는 점을 `PLAN.md`/게이트 상태에 어떻게 반영할 것인가?

## FAIL 2

[심각도] P0  
[지목] `docs/beta-data-sop.md` / `PLAN.md` G3  
[문제] 베타 회수 채널은 아직 확정되지 않았다. rev3가 `STATUS: TEMPLATE — 수신 채널 미확정`과 `PLAN.md G3 출시 게이트는 INCOMPLETE`를 명시했으므로, F13의 “베타 회수 채널 겸용” 주장은 현재 미완료다.  
[증거] `docs/beta-data-sop.md`에는 `<maintainer-email-here>`가 남아 있고, 사용자에게 보낼 안내문은 그대로 발송할 수 없다. `FINAL.md` C의 “사용자가 파일 전송”에는 실제 수신처가 필요하다.  
[질문] 이 결정을 사람 영역으로 넘긴다면, CP2 종료 조건에서 G3 미완료를 어떻게 차단 게이트로 유지할 것인가?

## WITHDRAW

[심각도] P1  
[지목] `JLPTDeck/App/Dependencies/LocalRepositoryClient+Live.swift`  
[문제] rev1의 F13 actor-isolation 지적은 철회한다.  
[증거] rev2 이후 `LocalRepositoryClient+Live.swift`의 F13 export/import 경고는 사라졌다. 남은 build warning은 F13 신규 결함으로 보지 않는다.  
[질문] 없음.

## 인정하는 부분
- rev3는 runbook을 실행 증거로 위장하지 않았다. 이 정직성은 맞다.
- `ExportPayload` schema, codec, Settings export/import UI, schema mismatch alert, `FeatureFlags.dataExport`는 구현되어 있다.
- `docs/beta-data-sop.md`는 템플릿으로는 유효하다.
- `CP2_EVIDENCE/test_F13_rev2.txt`는 98/98 green, `build_F13_rev2.txt`는 build succeeded, `network_grep_F13_rev2.txt`는 외부 송신 0건이다.

## F13 고유 질문 답변

[round-trip 가능?]  
구현상 가능할 수 있으나, 증거 기준으로는 아직 미검증이다. runbook이 아니라 실행 로그가 필요하다.

[베타 회수 채널로 적합?]  
템플릿 단계다. 실제 수신 채널이 정해지기 전에는 베타 회수 채널로 적합하다고 판정할 수 없다.

## 결론
이건 더 이상 코드 수정만의 문제가 아니다. 그러나 현재 감시 규칙은 “DoD 충족 여부”를 판정하라고 되어 있고, F13 DoD는 충족되지 않았다.  

수정 요구는 새 기능 추가가 아니다. `CP2_EVIDENCE/manual_qa_F13.txt`의 Execution Log를 실제로 채우고, `docs/beta-data-sop.md`의 수신 채널을 확정하라. 그 전까지 F13은 FAIL이다.
