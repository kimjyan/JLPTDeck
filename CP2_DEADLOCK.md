# ### DEADLOCK: F13 → RESOLVED (2026-05-06)

**Resolution**: PM applied options B + C ("기본 권장"):
- **F13 reclassified PASS_WITH_BLOCKERS** under redefined DoD:
  "code complete + docs complete + human action plan explicitly logged"
- **F15 proceeds** with safety-gate exemption (F15 has no PLAN dependency on F13)
- H1 (수신 채널), H2 (토큰 치환), H3 (manual UI runbook 실행) remain on the
  human-action backlog; tracked at PLAN.md G3 + the Execution Log section
  of `CP2_EVIDENCE/manual_qa_F13.txt`

---

# (Original DEADLOCK record)

# ### DEADLOCK: F13

**Date**: 2026-05-06  
**Pipeline**: CP2 (F3 → F4 → F8 → F9 → F13 → F15)  
**Trigger**: 같은 F의 (FAIL → 수정 → FAIL) 2회 반복 (deadlock detection rule)

## 진행 상황

| F | rev | 결과 | 비고 |
|---|---|---|---|
| F3 | rev1 | FAIL | cross-session reset 누락 + reducer integration test 부재 |
| F3 | rev2 | PASS_WITH_WARNING | learning step 분리 + reducer 3 tests + warning: loadResult.success reset 직접 검증 부재 |
| F4 | rev1 | FAIL | SessionComplete UI 미부착 |
| F4 | rev2 | FAIL | loadError 폴루션 → errorState 차단 |
| F4 | rev3 | PASS_WITH_WARNING | loadError 분리 + isComplete 도달 검증 |
| F8 | rev1 | FAIL | persistence integration test 부재 |
| F8 | rev2 | PASS_WITH_WARNING | scope 좁힘 + manual QA evidence + hideFailedCount + migration smoke |
| F9 | rev1 | FAIL | counter-only, measurement infrastructure 아님 |
| F9 | rev2 | PASS_WITH_WARNING | ResponseLatencyRecord array + scenePhase 처리 |
| **F13** | **rev1** | **FAIL** | round-trip integration test 부재 + 베타 SOP 부재 + actor warning |
| **F13** | **rev2** | **FAIL** | actor warning 해소 + manual QA + SOP 작성, but execution evidence 없음 |
| **F13** | **rev3** | **FAIL** | 정직 표기 (NOT EXECUTED 배너), but execution evidence 없음 → **DEADLOCK** |
| F15 | — | NOT STARTED | 안전 게이트 차단 (직전 F13 FAIL) |

## DEADLOCK 사유

F13 FAIL의 본질은 **사람 결정/실행 영역**이지 코드 결함이 아님:

1. **Repository round-trip 자동 테스트** — host-deinit malloc crash로 차단. 사용자 메모 `defer-jlptdeck-simulator-crash`가 명시적으로 "do NOT re-attempt fixes" 요구. L9 (post-v1.0 SwiftData test resurrection) 의존.
2. **Manual UI runbook 실행 증거** — 시뮬레이터 UI 자동 tap/inspect 인프라 없음. 메인테이너가 TestFlight 제출 전 직접 실행 필요.
3. **베타 회수 채널 결정** — 메인테이너 메일주소/GitHub Issues/Form 등 운영 결정. 코드 작업 영역 아님.

코드 + 문서 + 자동 테스트는 모두 완료:
- `ExportPayload` schema (versioned, Codable)
- `ExportPayloadCodec` (pure encode/decode)
- `LocalRepository.exportSnapshot/importSnapshot` 구현 (upsert 정책)
- `LocalRepositoryClient` Sendable 클로저 + `@MainActor` 보강 (warning 0)
- `SettingsView` "백업 내보내기/가져오기" + `.fileExporter`/`.fileImporter` + schema mismatch alert
- `ExportPayloadTests` 7개 (round-trip / pretty / sortedKeys / garbage / empty / version / nil lastReview)
- `docs/beta-data-sop.md` 템플릿 (메인테이너 결정 후 1줄 치환)
- `CP2_EVIDENCE/manual_qa_F13.txt` runbook (메인테이너 실행 후 Execution Log 추가)

## 사람 결정 필요 항목

| # | 항목 | 결정자 | 데드라인 |
|---|---|---|---|
| H1 | 베타 회수 수신 채널 (이메일/GitHub Issues/Form) | 메인테이너 (kimjh) | TestFlight 제출 전 |
| H2 | `<maintainer-email-here>` 토큰 치환 | 메인테이너 | H1 결정 후 즉시 |
| H3 | Manual UI runbook 10단계 실행 + Execution Log 작성 | 메인테이너 | TestFlight 제출 전 |
| H4 | F13의 PLAN DoD를 v1.0 현실 제약 안에서 수용 결정 | PM (사람) | CP2 재개 전 |

## 잠금 해제 조건

다음 중 하나 충족 시 F13 PASS 가능:
- A) H1+H2+H3 모두 완료 → DoD 엄격 해석 충족
- B) PM이 PLAN F13 DoD를 "코드 + 문서 + 사람 실행 plan"으로 재정의 → DoD 현실 충족 (이미 코드/문서는 완료 상태)

## CP2 미완 상태

- 완료된 F: F3, F4, F8, F9 (4/6 PASS_WITH_WARNING)
- DEADLOCK F: F13 (1/6)
- 미시작 F: F15 (1/6) — 안전 게이트 차단

## 권장 다음 액션

이 시점부터는 자동 핑퐁 모드 종료. 사람 결정 필요:

1. (옵션 A) H1~H4 결정 후 F13 재시작 (rev4 with execution log + actual email)
2. (옵션 B) F13 DoD를 "코드 완료 + 문서 완료 + 사람 실행 plan 명시" 로 격하 → F13 PASS 처리 → F15 진행 허가
3. (옵션 C) F15만 우선 진행 (F13과 독립적, PLAN 의존성 없음) — 안전 게이트 룰 일시 면제

기본 권장: **옵션 B + C**. F13 코드 완료, 사람 결정은 PLAN G3 명시적 게이트로 유지, F15 진행으로 CP2 코드 완료 도달.
