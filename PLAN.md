# JLPTDeck — v1.0 PLAN

> 2026-05-06. FINAL.md → 실행 계획. 데드라인 정렬이 아닌 의존성·위험도·UI 통합 기반.
> D-N = v1.0 출시일까지 남은 일수.

## 0. UI 작업 처리 원칙

| 분류 | 정의 | 처리 방식 |
|---|---|---|
| **UI-A** | F1~F17 안에 포함된 기능 부착 UI | F별로 흩어 만들지 않고 **화면별로 묶어 1번에 작업** |
| **UI-B** | 시각 완성도 (별도 F18) | 모든 UI-A 완료 후 일관성 점검 + Theme 정합성 + 여백/타이포 |

### UI-A 화면별 통합 그룹

| 그룹 | 포함 F | 작업 시점 |
|---|---|---|
| **G-CardView** | F12 (품사 표시) + F16 (TTS 버튼) + F17 (발음 함정 아이콘) + F8 일부 (신고/숨기기 메뉴) | 한 번에 카드 하단 영역 재설계 |
| **G-SessionComplete** | F7 (다음 약속 + streak 사전 동기) + F10 (첫 시도 정답률 분리 표시) | 한 번에 완료 화면 재구성 |
| **G-Settings/About** | F5 (포지셔닝 카피) + F6 (attribution) + F11 (결핍 명시) + F13 일부 (export 버튼) | 한 번에 정보 영역 재구성 |

### 신규 F항목

- **F18 (UI-B)**: 시각 완성도 통합 점검. D-2. 예상 8시간. UI-A 완료 후.
- **F19 (출시 직전 디테일)**: 앱 아이콘 / App Store 스크린샷 / 메타데이터 / 1.0.0 태그. D-1. 예상 4시간.

### D-14 정체 메모 (필수 사전 작업)

**작업명**: "마무리가 아쉽다" 정체 메모 작성  
**시점**: D-14 (CP1 직후, 본격 작업 시작 전)  
**산출물**: `docs/finishing-debt.md`  
**내용**:
- 현재 코드/UI에서 "이거 결국 안 끝낼 것 같다"고 본인이 느끼는 항목 사전 명시
- 베타 사용자가 처음 5분 안에 "허술해 보인다"고 느낄 후보 화면
- 버튼 정렬·여백·다크모드 spot check 필요한 화면 목록
→ F18 (UI-B) 작업의 입력 자료가 됨. 정체 항목을 미리 적어두면 D-2에 발견하지 않는다.

---

## 1. 작업 순서 (의존성 + 위험도 기반)

규칙:
- **HIGH 위험도는 D-7까지 모두 완료** (안정화 + 회귀 테스트 시간 확보)
- **MED는 D-5까지**
- **LOW (UI/카피)는 D-3 ~ D-1**
- F18 (UI-B) D-2, F19 (출시 디테일) D-1 고정

| 순 | 작업 | 데드라인 | 선행 | 위험도 | 시간 | 병렬? |
|---|---|---|---|---|---|---|
| 1 | **F1 메일 발송** (Tanos J. Waller 라이선스 문의) | D-14 | 없음 | LOW | 1h (메일) + 답변 대기 | ✓ (대기 중 모두 병렬) |
| 2 | **E2 PoC** (한자음 매핑 데이터 출처 조사) | D-14 | 없음 | LOW | 2h | ✓ |
| 3 | **E3 결정** (주당 가용 시간 산정 + 출시 일정 확정) | D-14 | E2 PoC | LOW | 1h (본인 결정) | ✗ (이후 모든 일정의 베이스) |
| 4 | **D-14 정체 메모 작성** (`docs/finishing-debt.md`) | D-14 | 없음 | LOW | 1h | ✓ |
| 5 | **CP1 (D-14)** | — | 1, 2, 3, 4 | — | — | — |
| 6 | **F2 사람 검수 시작** (외부 작업, 본인 시간) | D-10 | F1 답변 무관 | MED | 6h | ✓ (검수 중 코드 작업 병렬) |
| 7 | **F9 응답 시간 측정 인프라** (`responseLatencyMs` + `.hard` enum 정의 + 의심 표시) | D-7 | 없음 | HIGH | 3h | ✓ |
| 8 | **F8 카드 신고/숨기기** (`userOverride` SwiftData 모델 + 카드 메뉴) | D-7 | 없음 | HIGH | 4h | ✓ |
| 9 | **F4 upsert 실패 silent 제거** (retry queue + 세션 종료 통보) | D-7 | 없음 | HIGH | 3h | ✗ (F3 직전 핵심 로직 안정화) |
| 10 | **F3 세션 재시도 SRS 분리** (learning step 큐 도입) | D-7 | F4 | HIGH | 4h | ✗ |
| 11 | **F15 로컬 익명 이벤트 카운터** (`AppOpenEvent` SwiftData) | D-5 | 없음 | MED | 2h | ✓ |
| 12 | **F13 SRS state JSON export** (Settings + UIDocumentPicker) | D-5 | F8 (userOverride 포함 export) | MED | 3h | ✓ |
| 13 | **CP2 (D-7)** — HIGH 4건 + MED 일부 검증 | — | 7~10 | — | — | — |
| 14 | **G-SessionComplete** (F7 + F10 통합 작업) | D-3 | F4 (correctCount 분리) | LOW | 2h+2h = 4h | ✓ |
| 15 | **G-CardView** (F12 + F16 + F17 + F8 메뉴 통합) | D-3 | F8, F9 | LOW | 2h+3h+1h = 6h | ✓ |
| 16 | **G-Settings/About** (F5 + F6 + F11 + F13 export 버튼) | D-3 | F2 결과 (검수 후 데이터셋 버전), F13 | LOW | 30m + 2h + 30m + 30m = ~3.5h | ✓ |
| 17 | **F14 smoke UI 테스트 1개** | D-3 | 14, 15, 16 (UI-A 모두 안정화 후) | LOW | 3h | ✗ |
| 18 | **CP3 (D-3)** — 데이터/카피 검증 | — | 14~17 | — | — | — |
| 19 | **F18 (UI-B)** — 시각 완성도 통합 점검 | D-2 | UI-A 모두 완료 + 정체 메모 참조 | LOW | 8h | ✗ |
| 20 | **CP3.5 (D-2)** — 시각 디자인 검증 | — | 19 | — | — | — |
| 21 | **F19 출시 직전 디테일** (아이콘/스크린샷/메타/태그) | D-1 | 모든 코드 동결 | LOW | 4h | ✗ |
| 22 | **CP4 (D-1)** — 출시 직전 최종 게이트 | — | 모두 | — | — | — |

**총 작업 시간**: F1~F19 합산 ~62시간 (FINAL.md ~50h + UI-A 통합 비용 + UI-B 8h + F19 4h). E3 결정 결과에 따라 분할 출시 또는 일정 압축.

---

## 2. 체크포인트 (Codex 검증 시점)

### CP1 (D-14) — 외부 의존성/결정 확정

**입력 자료**: 
- F1 발송 메일 사본
- E2 PoC 결과 메모 (한자음 데이터 출처 평가)
- E3 결정 메모 (주당 시간 + 출시 일정)
- `docs/finishing-debt.md` (정체 메모 초안)

**Codex 핵심 질문 3개**:
1. E2 한자음 매핑이 v1.0에 들어가지 않을 경우, "첫 60초 식별 가능한 차별점"으로 무엇이 남나? (남는 것 없으면 v1.0 출시 의미를 재정의해야 함)
2. E3 주당 시간 × D-14에서 D-day까지 실가용 시간이 62h를 충당하는가? 부족 시 어느 F부터 잘라야 하나?
3. F1 답변이 D-day 전까지 도착하지 않을 시 fallback (Tanos 데이터 제거 + 자체 분류) 비용을 ~14h로 가정하는데, 이 가정이 합리적인가?

**검증 통과 기준**: 3개 질문 모두 결정/답변 가능. 결정 못하면 D-day 연기.

---

### CP2 (D-7) — HIGH 위험도 작업 완료

**입력 자료**:
- F3, F4, F8, F9 PR diff
- 기존 회귀 테스트 결과 (48/48 green 유지 여부)
- F3 learning step 큐 단위 테스트 결과
- F4 retry queue 동작 통합 테스트

**Codex 핵심 질문 3개**:
1. F3 도입 후 같은 세션 재시도에서 SRS state가 변경되지 않는가? 첫 시도와 재시도 정답률이 정확히 분리되어 있는가?
2. F4 upsert 실패 시 사용자가 어떤 화면에서 실패 사실을 인지하는가? 실패한 카드 ID가 다음 세션에서 retry되는가?
3. F8 `userOverride` 추가가 SwiftData 마이그레이션을 깨지 않는가? 기존 SRS state와 함께 export/import 가능한가?

**검증 통과 기준**: 회귀 테스트 48개 green + 핵심 시나리오 3개 통과. 실패 시 D-7 시점에 롤백 결정 (4번 섹션).

---

### CP3 (D-3) — 데이터/카피 완료

**입력 자료**:
- F2 검수 결과 (오류율 보고서)
- G-SessionComplete, G-CardView, G-Settings/About 화면 캡처
- F11/F5 카피 변경 diff
- F14 smoke 테스트 결과

**Codex 핵심 질문 3개**:
1. F2 검수 결과 오류율이 5% 임계 이하인가? 초과 시 어느 레벨을 재생성할 것인가? (재생성은 D-3에 늦음 — 출시 연기 검토)
2. 앱 어디에도 "한국인 학습자 특화", "JLPT 종합 대비", "액티브 리콜", "한국어 native" 카피가 남아있지 않은가? (grep 검증)
3. F14 smoke 테스트가 첫 실행 → import → 홈 → 1문제 → 완료 흐름을 끝까지 통과하는가?

**검증 통과 기준**: F2 오류율 통과 + 금지어 grep 0건 + smoke green.

---

### CP3.5 (D-2) — 시각 디자인 검증 (신설)

**입력 자료**:
- F18 (UI-B) 작업 후 모든 화면 캡처 (라이트/다크 모드)
- D-14 정체 메모 (`docs/finishing-debt.md`)와 비교
- Theme 토큰 사용 일관성 grep 결과

**Codex 핵심 질문 3개**:
1. 정체 메모에 적은 "허술해 보일 후보 화면"이 모두 처리되었는가? 미처리 항목은 D-day 후 v1.0.1 hotfix로 미룰 만한가?
2. UI-A 통합 그룹(CardView/SessionComplete/Settings)에서 시각 일관성이 깨진 곳은 없나? (여백/타이포/색상 토큰 누락)
3. 다크 모드에서 정답/오답 색상 대비, 카드 가독성, attribution 영역 가독성이 충분한가?

**검증 통과 기준**: 정체 메모 항목 80% 이상 처리 + 라이트/다크 모드 spot check 통과.

---

### CP4 (D-1) — 출시 직전 최종

**입력 자료**:
- F19 산출물 (아이콘 / 스크린샷 / 메타데이터 / 1.0.0 태그)
- 6번 섹션 최종 게이트 체크리스트 결과

**Codex 핵심 질문 3개**:
1. 6번 게이트 체크리스트 7개 항목 모두 ✓인가? 하나라도 ✗이면 출시 연기.
2. App Store 메타데이터의 앱 설명/키워드/스크린샷 캡션에 금지어(F5)가 없는가?
3. 베타 회수 SOP 문서(`docs/beta-data-sop.md`)가 작성되어 있고, 베타 사용자에게 보낼 안내문이 준비되어 있는가?

**검증 통과 기준**: 게이트 7개 통과 + 금지어 0건 + SOP 존재.

---

## 3. Definition of Done (각 F항목)

| F | 끝났다고 부를 수 있는 객관적 기준 |
|---|---|
| **F1** | LICENSE 파일 리포 루트 존재 + 앱 내 attribution UI 표시 + Tanos 답변 받은 경우 사본 보관 / 답변 무 시 fallback 결정 문서화 |
| **F2** | 검수 보고서 (`docs/translation-audit-v1.md`) 작성 + 레벨별 오류율 < 5% + 초과 레벨은 재생성 후 재검수 |
| **F3** | learning step 큐 단위 테스트 통과 + 같은 세션 재시도 시 SRS state 변경 없음을 통합 테스트로 확인 + 기존 SRS 회귀 테스트 48개 모두 green |
| **F4** | upsert 실패 강제 주입 테스트에서 retry queue 동작 + 세션 종료 화면에 실패 카드 N건 표시 + 다음 세션 시작 시 retry 큐 처리 통합 테스트 통과 |
| **F5** | `grep -ri "한국인 학습자 특화\|JLPT 종합 대비\|액티브 리콜\|한국어 native" .` 결과 0건 (코드/STATUS/CLAUDE.md/마케팅 카피 전체) |
| **F6** | Settings 화면에 EDRDG/JMdict/Tanos 라이선스 링크 3개 + 데이터셋 버전 + 생성일 + JLPT 비공식 명시 1줄 모두 visible |
| **F7** | SessionComplete에 "내일 N개 복습" + streak 사전 동기 메시지 표시 + 빈 상태/0개/끊긴 상태 모두 처리 + ReviewSessionFeatureTests에서 표시 데이터 검증 |
| **F8** | 카드 화면 메뉴에서 신고/숨기기 동작 + `userOverride` SwiftData 모델 마이그레이션 통과 + 숨김 카드가 다음 세션 큐에서 제외되는 통합 테스트 통과 |
| **F9** | `responseLatencyMs` 모든 카드 응답에 기록 + `.hard` enum 정의 (사용 안 함) + 임계 초과 첫 정답이 시각적으로 표시 + SM-2 입력에는 영향 없음을 회귀 테스트로 확인 |
| **F10** | `correctCount` 첫 시도만, `relearnedCount` 재시도 회복만 분리 카운트 + SessionComplete에 "첫 시도 N% / 회복 M개" 표시 + ReviewSessionFeatureTests 시나리오 통과 |
| **F11** | About + StatsView 헤더에 결핍 명시 1줄 visible (라이트/다크 모드 모두 가독성 통과) |
| **F12** | 정답 공개 후 카드 하단에 JMdict `pos` 1단어 표시 + 데이터에 pos 필드 없는 카드 graceful fallback (빈 영역 또는 표시 안 함) |
| **F13** | Settings에 export 버튼 → UIDocumentPicker 호출 → JSON 파일 저장 + import 역방향도 동작 + export/import round-trip 테스트 통과 (SRS state + userOverride 포함) |
| **F14** | XCUITest 1개: 앱 시작 → 자동 import → 홈 → "시작하기" → 1문제 응답 → 완료 화면 도달. CI에서 일관 통과 (3회 연속 green) |
| **F15** | `AppOpenEvent` SwiftData 모델 + 앱 launch 시 기록 + StatsView 디버그 영역 (개발자 빌드만)에서 D1/D7 미리보기 + 외부 송신 0건 grep 검증 |
| **F16** | 정답 공개 후 스피커 아이콘 visible + 탭 시 표제어 재생 + autoplay 없음 + 무음 모드에서 무음 + AVSpeechSynthesizer 실패 시 graceful (아이콘 비활성화) |
| **F17** | reading 정규식 검출 함수 단위 테스트 (장음/촉음/ん 케이스 6개) 통과 + 정답 공개 후 카드에 아이콘 표시 + 툴팁 한국어 |
| **F18** | 정체 메모(`docs/finishing-debt.md`) 항목 ≥80% 처리 + Theme 토큰 grep 통과 (하드코딩 색상 0건) + 라이트/다크 모드 모든 화면 스크린샷 보관 |
| **F19** | 1024×1024 앱 아이콘 + 스크린샷 5장 (4지선다/완료/통계/오답/설정) + App Store 메타데이터 (제목/부제/설명/키워드 — 금지어 0건) + git tag `v1.0.0` |

---

## 4. 롤백 시나리오 (HIGH 위험도만)

### F3 — 같은 세션 재시도 SRS 분리

| 상황 | 대응 |
|---|---|
| **작업 중 막힘** | learning step 큐 도입을 별도 enum 케이스로 시도 → 실패 시 ReviewSessionFeature.queue 분리(`mainQueue` / `relearnQueue`)로 단순화 |
| **출시 직전 회귀** | feature flag `Feature.relearnSeparated` (기본 OFF) 도입 → SM-2 즉시 저장으로 폴백 가능 |
| **v1.0에서 빼는 결정 데드라인** | **D-5** (smoke 테스트 D-3 전). 빠질 경우 STATUS에 "같은 세션 재시도가 SRS에 즉시 반영됨, v1.0.1에서 수정" 명시 + 베타 안내문 추가 |

### F4 — upsert 실패 silent 제거

| 상황 | 대응 |
|---|---|
| **작업 중 막힘** | retry queue 영속화가 어려우면 in-memory queue + 세션 종료 시 alert 표시로 단순화 |
| **출시 직전 회귀** | feature flag `Feature.upsertRetry` (기본 OFF) → 기존 silent fail로 복귀 (단, 사용자 통보는 유지) |
| **v1.0에서 빼는 결정 데드라인** | **D-5**. 빠질 수 없는 항목 (학습 기록 손실 직결). 빼야 할 상황이면 **출시 자체 연기**. |

### F8 — 카드 신고/숨기기

| 상황 | 대응 |
|---|---|
| **작업 중 막힘** | `userOverride` 모델 마이그레이션 어려우면 UserDefaults에 hidden card ID Set 임시 저장 (export 호환성 일부 손실) |
| **출시 직전 회귀** | 메뉴 자체 숨김 (UI 비활성화) + 데이터 모델은 유지 → v1.0.1에서 UI 활성화 |
| **v1.0에서 빼는 결정 데드라인** | **D-7**. 빠질 경우 7일 hotfix SLA에 의존하게 됨 (운영 부담 증가). E3 운영 시간 결정과 연계. |

### F9 — 응답 시간 측정 인프라

| 상황 | 대응 |
|---|---|
| **작업 중 막힘** | "느림/의심" 시각 표시 빼고 측정만 (`responseLatencyMs` 기록만). UI 작업 0 |
| **출시 직전 회귀** | 측정 자체는 비파괴적이라 회귀 가능성 낮음. 회귀 시 `responseLatencyMs` 기록 비활성화 (nil 저장) |
| **v1.0에서 빼는 결정 데드라인** | **D-3**. 측정 인프라가 빠지면 v1.x A/B (L18) 시작이 늦춰짐 (1.x 일정 영향). 그러나 v1.0 자체는 영향 없음. |

---

## 5. 병렬 작업 트랙 (외부 대기 시간 활용)

혼자 작업 가정. 외부 대기는 약 3개 구간:

### 트랙 A: F1 라이선스 답변 대기 (D-14 ~ D-7, 최대 7일)

병행 가능:
- F9 응답 시간 측정 (D-7 마감, HIGH)
- F8 카드 신고/숨기기 (D-7 마감, HIGH)
- F4 upsert 실패 (D-7 마감, HIGH)
- F3 세션 재시도 분리 (D-7 마감, HIGH, F4 후)
- F15 이벤트 카운터 (D-5 마감, MED)
- F13 JSON export (D-5 마감, MED)

→ HIGH 4건 + MED 2건 모두 답변 대기 중에 처리 가능. F1 답변이 D-7 이후 도착해도 F6 attribution 작업(D-3)에 반영 가능.

### 트랙 B: F2 사람 검수 시간 (D-10 ~ D-5, 검수 6h 분산)

검수 자체는 본인 시간이지만 짧은 단위로 끊어 진행. 검수 사이 짬에:
- G-CardView UI 작업 (D-3 마감, LOW)
- G-Settings/About UI 작업 (D-3 마감, LOW)
- G-SessionComplete UI 작업 (D-3 마감, LOW)
- F14 smoke 테스트 작성 (D-3 마감, LOW)

→ 검수 중 머리가 식어 있을 때 카피/UI 작업 적합. HIGH 작업과 병행 금지 (집중도 분리).

### 트랙 C: E2 PoC 결과 대기 (D-14 ~ D-7, 데이터 출처 평가 시간)

E2 결정 자체는 본인이 하지만 PoC (위키사전 dump 다운로드 + 샘플 변환)는 시간이 걸림.

병행 가능:
- D-14 정체 메모 (`docs/finishing-debt.md`) 작성
- HIGH 작업 시작 (F9, F8 등)

→ E2 go 결정 시 한자음 매핑 데이터 생성 작업이 추가됨 (~10h 추정). 이 경우 v1.0 일정 7일 연장 또는 G-CardView 통합에 한자음 추가만 (data-only 작업).

---

## 6. v1.0 출시 직전 최종 게이트 (CP4 입력)

출시 버튼 누르기 전 반드시 ✓:

- [ ] **G1**: F1~F19 DoD 모두 통과 (3번 섹션 기준 19개 항목)
- [ ] **G2**: E2 결정 완료 (한자음 매핑 go/no-go) + E3 결정 완료 (운영 시간 예산)
- [ ] **G3**: 베타 회수 SOP 문서 존재 (`docs/beta-data-sop.md`) — 베타 사용자에게 보낼 "Settings → 이벤트 로그 공유 → 본인에게 전송" 안내문 포함. **현재 상태: TEMPLATE 작성 완료. 수신 채널 (이메일/GitHub Issues/Form) 미확정 → `<maintainer-email-here>` 토큰 치환 필요. 사람 결정 항목.**
- [ ] **G4**: smoke 테스트 통과 (F14 XCUITest 3회 연속 green)
- [ ] **G5**: 카피 금지어 grep 0건 — `grep -ri "한국인 학습자 특화\|JLPT 종합 대비\|액티브 리콜\|한국어 native" . --exclude-dir=.git --exclude-dir=DerivedData --exclude-dir=CP2_EVIDENCE --exclude-dir=CP3_EVIDENCE --exclude-dir=CP3_5_EVIDENCE --exclude=ATTACK_v\*.md --exclude=RESPONSE_v\*.md --exclude=FINAL.md --exclude=PLAN.md --exclude=CP\*_DIFF\*.md --exclude=CP\*_REVIEW_\*.md --exclude=CP\*_DEADLOCK.md`. **Scope**: 사용자/심사자에게 노출되는 텍스트 (앱 코드, CLAUDE.md, README, App Store 메타데이터, 베타 안내문)에서만 0건. 의사결정 기록 (ATTACK/RESPONSE/FINAL/PLAN/CP*_DIFF/REVIEW)은 금지어를 "사용 금지" 목록으로 인용 보존 — 메타-참조이지 사용자 노출이 아니므로 grep scope에서 제외.
- [ ] **G6**: 라이트/다크 모드 모든 화면 스크린샷 보관 (F18 산출물) + 정체 메모 항목 ≥80% 처리
- [ ] **G7**: LICENSE 파일 + 앱 내 attribution + 데이터셋 버전 표시 모두 visible (F1 + F6)

**하나라도 ✗이면 출시 연기**. 비상 단축 조건:
- G7 미통과 → 출시 절대 금지 (라이선스 위반 위험)
- G3, G5 미통과 → 출시 절대 금지 (베타 데이터 무회수 + 잘못된 마케팅)
- G1 부분 미통과 (LOW 위험도 F만) → CP4 검토 후 v1.0.1로 미루기 가능
- G6 미통과 (정체 항목 < 80%) → 출시 후 v1.0.1 hotfix 계획 명시 후 진행 가능

---

## 부록: 일정 요약

```
D-14 ┐ CP1 (외부 의존성/결정 확정) — F1 메일, E2/E3 결정, 정체 메모
     │ 트랙 A 시작 (라이선스 답변 대기 중 HIGH 작업)
     │ 트랙 C 시작 (E2 PoC 평가)
D-10 ┤ F2 사람 검수 시작 (트랙 B)
D-7  ┐ CP2 (HIGH 4건 완료) — F3, F4, F8, F9
     │ 롤백 데드라인 (HIGH F들)
D-5  ┤ F15, F13 (MED) 완료
D-3  ┐ CP3 (데이터/카피 완료) — F2, G-그룹 3개, F14
D-2  ┐ CP3.5 (시각 디자인) — F18 (UI-B) 완료
D-1  ┐ CP4 (출시 직전 최종 게이트) — F19 + G1~G7 체크
D-0    🚀 v1.0 출시 (TestFlight 베타)
```

PLAN.md ready.
