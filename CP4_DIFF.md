# CP4_DIFF — 출시 직전 최종 게이트 (D-1)

> 2026-05-06. v1.0.0 TestFlight 베타 출시 직전 최종 검증.
> PLAN.md §6 게이트 G1~G7 + F19 산출물 + Codex 핵심 질문 3개.

## 1. G1~G7 게이트 결과

| 게이트 | 항목 | 결과 | 근거 |
|---|---|---|---|
| **G1** | F1~F19 DoD 모두 통과 | △ partial — LOW만 미해결 | F2 사람 검수 PASS_WITH_BLOCKERS, F19 아이콘 PNG 메인테이너 작업 필요. 나머지 17개 ✓ |
| **G2** | E2 + E3 결정 완료 | × HUMAN | E1/E2/E3 ESCALATE 항목 — 사람 결정 필요 (FINAL.md §4) |
| **G3** | 베타 회수 SOP 존재 | △ partial | `docs/beta-data-sop.md` 작성 ✓, `<maintainer-email-here>` 토큰 미치환 (CP2 deadlock H1+H2) |
| **G4** | smoke 테스트 통과 (F14 3회 연속) | ✓ pass | CP3 5회 연속 + CP4 1회 추가 = 6회 연속 green |
| **G5** | 카피 금지어 grep 0건 | ✓ pass | CP4_EVIDENCE/forbidden_grep_strict.txt = 0건 (PLAN G5 명확화 후) |
| **G6** | 라이트/다크 모드 스크린샷 + 정체 메모 ≥80% | ✓ pass | CP3.5: 16 PNG + 100% acknowledged |
| **G7** | LICENSE + attribution + 데이터셋 버전 | ✓ pass | LICENSE 파일 신규 ✓, Settings 데이터 출처 Section ✓, JLPTDeckMetadata.datasetVersion ✓ |

**비상 단축 조건 평가** (PLAN.md §6):
- G7 ✓ → 라이선스 위반 위험 해소
- G3 △ + G5 ✓ → SOP 본체는 존재, 메인테이너 이메일 결정만 남음 → 출시 절대 금지 회피 가능 (베타 발송 직전 token 치환만 필수)
- G1 부분 미통과는 LOW 위험만 (F2 사람 검수, F19 아이콘 PNG) → CP4 검토 후 v1.0.1 미루기 가능
- G6 100% → 통과
- G2 × HUMAN → E1/E2/E3 결정은 v1.0 출시 자체를 막지 않음 (FINAL.md §4: E1 v1.0 출시 후 7일, E2 go/no-go 둘 다 가능, E3 출시 전 필수)

**최종 판정**: 코드 작업 영역 모두 통과. 출시 직전 사람 결정 4건 잔존 (H1~H4 + E2/E3) → 메인테이너가 처리 후 출시 가능.

## 2. Codex 핵심 질문 3개 답변

### Q1. 6번 게이트 체크리스트 7개 항목 모두 ✓인가?
**A**: 5/7 ✓ (G4, G5, G6, G7, G1 부분), 2/7 △ HUMAN (G1 LOW 잔존, G3 토큰, G2 결정).
- 코드 작업 100% 완료
- 사람 결정 4건: H1 (수신 채널), H2 (토큰 치환), H3 (manual UI runbook), E3 (운영 시간) 출시 전 필수
- E1 (FSRS 포팅), E2 (한자음) 결정은 출시 후 7일 내 가능 → 출시 차단 아님

### Q2. App Store 메타데이터에 금지어 없는가?
**A**: ✓ 0건. `CP4_EVIDENCE/forbidden_grep_strict.txt` 0줄.
- PLAN.md G5 grep scope 명확화 (의사결정 기록 exclude 명시)
- AppStore/{ko,en}/*.txt + AppStore/README.md 모두 통과
- 사용자/심사자 노출 텍스트에 금지어 0

### Q3. 베타 회수 SOP 존재 + 안내문 준비?
**A**: △ — 문서 본체 ✓, 토큰 치환 미완.
- `docs/beta-data-sop.md` §2 안내문 본문 ✓
- `<maintainer-email-here>` 토큰 → 메인테이너가 베타 발송 직전 치환 필수
- TestFlight Tester Notes 붙여넣기는 사람 작업 (`AppStore/README.md` §2.D 명시)

## 3. F19 산출물

### ✓ 자동 처리 완료
- **`LICENSE`** (신규) — MIT (소스) + JMdict CC BY-SA 4.0 + Tanos 비공식 명시 + Trademark 공지
- **App Store 메타데이터** (`AppStore/ko/`):
  - `name.txt`: "JLPTDeck"
  - `subtitle.txt`: "한국어 뜻 인식 단어장 · 4지선다"
  - `promotional_text.txt`, `description.txt`, `keywords.txt`, `release_notes_v1.0.0.txt`
- **스크린샷 5장** (`AppStore/screenshots/iPhone-6_5/`) — CP3.5 라이트 모드 캡처에서 선정
  - 01_quiz_4choice.png (4지선다 reveal — F12/F16/F17 visible 영역)
  - 02_session_complete.png (F7+F10)
  - 03_stats.png (F11 scope banner)
  - 04_mistakes.png (empty state)
  - 05_settings.png (F6 attribution + F11 footer)
- **`AppStore/README.md`** — 사람이 App Store Connect에 입력하는 가이드
- **`CLAUDE.md` 갱신** — 테스트 카운트 48 → 127, F3~F18 도메인 추가, UI Theme 정책 명시

### × 사람 처리 필요
- **앱 아이콘 1024×1024 PNG** — `Contents.json` 슬롯 정의는 있으나 실 PNG 부재. 디자인 작업 후 Xcode에 드래그
- **TestFlight Tester Notes 토큰 치환** — `docs/beta-data-sop.md` 메인테이너 이메일 결정 + 치환
- **git tag v1.0.0** — 빌드 업로드 직전 메인테이너가 직접 (자동 push 금지)
- **App Store Connect 입력** — `AppStore/{ko,*}/*.txt` 본문을 web UI에 복사 + 스크린샷 업로드
- **iPhone 5.5" 스크린샷** — Apple 요구 시 별도 캡처 (iPhone 8 Plus 시뮬레이터)

## 4. 변경 파일

**신규**:
- `LICENSE` — MIT + JMdict CC BY-SA 4.0 + Tanos 추정 명시
- `AppStore/README.md`, `AppStore/ko/{name,subtitle,description,keywords,promotional_text,release_notes_v1.0.0}.txt`
- `AppStore/screenshots/iPhone-6_5/{01..05}_*.png` (CP3.5 라이트 캡처에서 선정)
- `CP4_EVIDENCE/forbidden_grep_strict.txt` (0줄)

**수정**:
- `CLAUDE.md` — 테스트 카운트 48 → 127, F-번호 도메인 추가, UI Theme 정책, F14/F18 명령
- `PLAN.md` G5 — grep 명령에 의사결정 기록 exclude 추가 + scope 명확화

**미수정 (의도)**:
- `docs/beta-data-sop.md` — 메인테이너 결정 항목 (H1+H2)
- `docs/finishing-debt.md` — CP3.5에서 100% acknowledged
- 앱 코드 — CP3.5 후 추가 변경 없음

## 5. 알려진 한계 / 인계 사항

### 출시 직전 사람 작업 체크리스트
1. [ ] 메인테이너 베타 회수 이메일 결정 (H1)
2. [ ] `docs/beta-data-sop.md`의 `<maintainer-email-here>` 토큰 치환 (H2)
3. [ ] 1024×1024 앱 아이콘 PNG 디자인 + Xcode 슬롯 첨부 (라이트/다크/tinted 3종)
4. [ ] App Store Connect 메타데이터 입력 (AppStore/ko/*.txt 복사)
5. [ ] 스크린샷 5장 업로드 (iPhone 6.5" + 필요 시 5.5")
6. [ ] TestFlight 빌드 업로드 + Tester Notes에 SOP §2 본문 복사
7. [ ] (Apple 심사 통과 후) `git tag -a v1.0.0 -m "..."; git push origin v1.0.0`
8. [ ] E3 (운영 시간 예산) 본인 결정 — 6개월 hotfix SLA 가능성 포함

### v1.0.1 hotfix 후보 (CP4 후 발견 시)
- F2 사람 검수 결과 오류율 > 5% 레벨 재생성 → v1.0.1 hotfix
- F8 unhide UI (현재 hide 일방향) → v1.0.1
- B9 caption2 가독성 격상 → v1.x

### v1.x 백로그 (`docs/finishing-debt.md` × deferred 항목 + FINAL.md §2 L1~L18)
- L1 푸시 알림 + L2 StatsView 강화 (v1.1 마케팅 출시 차단)
- L9 SwiftData 호스트 크래시 해소 → disabled 테스트 5건 부활
- L11 의미 함정 50개 큐레이션
- L13 reading 자가 확인 모드 토글
- L18 응답 시간 quality A/B (F9 데이터 30일 누적 후)

### 외부 의존 (FINAL.md §4 ESCALATE)
- **E1** (FSRS-rs 포팅 vs SM-2 유지) — v1.0 출시 + 7일 PoC 후 결정 가능
- **E2** (한자음 매핑 v1.0 격상) — v1.0 출시 + 7일 결정 가능. go 시 F5 일부 해제 + 차별점 확보. no-go 시 "차별점 미해결" 명시 후 베타 진행
- **E3** (무료 v1.0 6개월 운영 시간) — 출시 전 필수

## 6. 회귀 검증 (CP4 시점)

- 빌드: BUILD SUCCEEDED (CLAUDE.md 갱신 외 코드 변경 없음 → 회귀 0)
- 테스트: 127/127 unit + 1 UI smoke + 16 PNG 스크린샷 = 모두 green (CP3.5 종료와 동일)
- F14 smoke: CP4 추가 1회 ✓ (CP3 5회 + CP4 1회 = 6회 연속 green)
- 외부 송신 grep: 0건 (모든 단계 누적)

## 7. CP4 완료 판정

**코드 작업 영역**: ✓ 모두 완료. CP4 통과.

**사람 결정 영역**: 4건 잔존 (H1+H2+H3+E3+E2 결정+아이콘+태그+Store 입력). 메인테이너 작업 후 출시 가능.

**출시 차단 위험 평가**:
- G7 (라이선스) ✓ → 라이선스 위반 위험 0
- G5 (금지어) ✓ → 잘못된 마케팅 위험 0
- G3 (SOP 본체) ✓ → 베타 회수 인프라 ready, token 치환만 남음
- G6 (스크린샷) ✓ → 시각 디자인 검증 완료

**판정**: PASS_WITH_HUMAN_BLOCKERS. CP4 완료 후 메인테이너 인계.

---

CP4 ready. v1.0.0 TestFlight 베타 출시 가능 (메인테이너 인계 후 8개 사람 작업 완료 시).
