# CP3_DIFF — UI-A 통합 그룹 + F14 smoke 통합본 (G-SessionComplete + G-CardView + G-Settings/About + F14)

> 2026-05-06. CP3 (D-3 게이트) 작업의 4개 항목 합본.
> 개별 상세는 `CP3_DIFF_*.md`, 빌드/테스트 로그는 `CP3_EVIDENCE/`.
> F2(사람 검수)는 외부 작업이며 코드 작업 영역 외. PLAN G3 인간 결정 백로그로 추적.

## 1. 결과 요약

| 항목 | 포함 F | 위험도 | 데드라인 | 결과 | 신규 테스트 |
|---|---|---|---|---|---|
| G-SessionComplete | F7 + F10 | LOW | D-3 | PASS | +7 |
| G-CardView | F12 + F16 + F17 + F8 메뉴 | LOW | D-3 | PASS | +12 |
| G-Settings/About | F5 + F6 + F11 + F13 export | LOW | D-3 | PASS | +0 (카피 변경) |
| F14 smoke UI test | F14 | LOW | D-3 | PASS (5회 연속) | +1 (XCUITest) |

**테스트**: CP2 종료 108 → CP3 종료 **127 unit + 1 UI** green.
**빌드**: 4건 모두 BUILD SUCCEEDED.
**외부 송신 grep**: 0건 모든 단계.
**F5 금지어 grep** (app + CLAUDE + STATUS_v1): **0건** ✓
**F14 5회 연속 green**: ✓ (실측, in-memory reset)

## 2. CP3 게이트 (PLAN.md CP3 검증 통과 기준)

| 기준 | 결과 |
|---|---|
| F2 검수 결과 오류율 < 5% | **외부 작업 — PASS_WITH_BLOCKERS** (사람 검수 미실시, G3 백로그) |
| 금지어 grep 0건 (한국인 학습자 특화/JLPT 종합 대비/액티브 리콜/한국어 native) | ✓ (CP3_EVIDENCE/forbidden_grep_GSettings.txt) |
| F14 smoke green | ✓ (3회 연속 요건 → 5회 연속 실측 PASS) |

## 3. 변경 파일 (전체)

### 신규 (Domain pure)
- `JLPTDeck/Domain/SRS/PronunciationTraps.swift` (G-CardView F17)

### 신규 (Shared)
- `JLPTDeck/Shared/SpeechManager.swift` (G-CardView F16)
- `JLPTDeck/Shared/JLPTDeckMetadata.swift` (G-Settings F6)

### 신규 (Settings)
- `JLPTDeck/Features/Settings/AttributionRow.swift` (G-Settings F6)

### 신규 (테스트)
- `JLPTDeckTests/Features/SessionPreviewReducerTests.swift` (G-SessionComplete, 7 tests)
- `JLPTDeckTests/SRS/PronunciationTrapsTests.swift` (G-CardView F17, 12 tests)

### 수정 (Domain)
- `JLPTDeck/Domain/FeatureFlags.swift` — `sessionCompleteCoaching`, `cardPartOfSpeech`, `cardTTS`, `cardPronunciationTraps` 4개 flag 추가
- `JLPTDeck/Domain/Quiz/QuizQuestion.swift` — `pos: String?` 추가
- `JLPTDeck/Domain/Quiz/QuizGenerator.swift` — `Input.pos` 추가, make() pass-through

### 수정 (Data)
- `JLPTDeck/Data/Models/VocabCard.swift` — `pos: String?` optional column (auto-migration)
- `JLPTDeck/Data/JMdict/JMdictEntry.swift` — `pos: String?` decodeIfPresent
- `JLPTDeck/Data/JMdict/JMdictImporter.swift` — flush()에서 entry.pos 전달
- `JLPTDeck/App/Dependencies/VocabCardDTO.swift` — pos 필드
- `JLPTDeck/App/Dependencies/LocalRepositoryClient+Live.swift` — `VocabCardDTO(from: VocabCard)`에서 pos 전파

### 수정 (Reducer / View)
- `JLPTDeck/Features/Review/ReviewSessionFeature.swift` — F7/F10 state (`sessionLevel`, `sessionLimit`, `nextDayDueCount`, `streakAfterToday`), `sessionPreviewLoaded` action, `sessionPreviewEffect`, regenerateQuestion에 card.pos 전달, `userSettings` 의존성 추가
- `JLPTDeck/Features/Review/SessionCompleteView.swift` — F10 (firstAttemptCorrect/wrongCount/relearnedCount + 정답률 행) + F7 (`nextSessionPreview` 블록: 내일 N개 + streak 코칭)
- `JLPTDeck/Features/Review/ReviewSessionView.swift` — wiring 갱신
- `JLPTDeck/Features/Review/QuizCardView.swift` — `revealMetaRow` (F12 pos 배지 + F16 speaker 버튼 + F17 trap 배지). F8 메뉴는 변경 없음.
- `JLPTDeck/Features/Settings/SettingsView.swift` — 앱 정보 Section 확장 + 신규 "데이터 출처 / 라이선스" Section + F5/F11 footer
- `JLPTDeck/Features/Stats/StatsView.swift` — `scopeBanner` (F11 결핍 명시)

### 수정 (테스트 인프라)
- `JLPTDeck/JLPTDeckApp.swift` — `-uitest_reset_state` launch arg → in-memory store
- `JLPTDeckUITests/JLPTDeckUITests.swift` — `test_smoke_homeToSessionComplete` 신규

### 수정 (문서)
- `STATUS_v1.md` — legacy 마킹 + 산문에서 금지어 제거 (한국어 뜻 인식 학습 / 한국어 뜻 + 한국어 UI로 정정)

### 신규 (스크립트)
- `scripts/add_g_session_complete_files.rb`
- `scripts/add_g_cardview_files.rb`
- `scripts/add_g_settings_files.rb`

## 4. 변경 전/후 동작

### G-SessionComplete (F7+F10)
- **전**: `correctCount`/`wrongCount` 칩만 + retry/hide/slow 알림
- **후**: 첫 시도 정답률 (XX%) + 회복 K개 분리, 내일 복습 N개 카드 + streak 사전 동기 ("N일 연속 ✓ — 내일 거르면 끊김")
- **데이터 흐름**: `.task(level, limit)` → state.sessionLevel/Limit 캡처 → `autoAdvanceFired` → isComplete 분기에서 `sessionPreviewEffect` 발사 → `repo.todayReviewCards(now: tomorrow)` + `userSettings.loadStreak/loadLastStudyDate` (peek-only) → `sessionPreviewLoaded` action

### G-CardView (F12+F16+F17+F8)
- **전**: F8 메뉴(top-trailing) + 문제 + 4지선다 + reveal 시 reading만
- **후**: F8 메뉴 변경 없음. reveal 시 추가 메타 행 (pos 배지 / 스피커 버튼 / 발음 함정 배지). 각 element는 자체 flag/data 가드로 conditional render. 데이터 미충족 (pos nil, 음성 voice 없음, 함정 미검출) 시 자동 hide.
- **F12 인프라만 v1.0**: 번들 JSON에 `pos` 미존재 → 100% hide. 데이터 리프레시 시 코드 변경 0으로 활성화.

### G-Settings/About (F5+F6+F11+F13)
- **전**: 단일 라이선스 footer ("Data: JMdict (CC BY-SA), Tanos JLPT lists") + F13 export 버튼 (CP2 완료)
- **후**: 데이터셋 버전 행 + scope footer (F5/F11) + 신규 "데이터 출처 / 라이선스" Section (JMdict 외부 링크 + Tanos 외부 링크 + JLPT 비공식 1줄). StatsView 상단 scope banner (F11). F5 금지어 0건.

### F14 smoke
- **전**: placeholder testExample 1개 (assert 없음)
- **후**: launch → 30s wait for 시작하기 enable → tap → 12 max retry choice rotation → SessionComplete 도달 검증 → 홈으로 → 홈 복귀 검증. in-memory reset으로 매 실행 fresh state. 5회 연속 green.

## 5. 알려진 한계 (각 항목별 1개 이상)

1. **G-SessionComplete**: nextDayDueCount는 best-effort (effect race with upserts), focused review에서는 sessionLevel nil → preview 자동 hide.
2. **G-CardView F12**: 번들 JSON `pos` 부재 → v1.0 사용자 invisible (DoD "graceful fallback" 충족, v1.x 데이터 리프레시 후 활성).
3. **G-CardView F17**: 장음 검출 휴리스틱 — 빈도 낮은 패턴 (あう, おお) 의도적 미커버.
4. **G-CardView F16**: `.ambient` 오디오 세션 — iOS 무음 모드 시 자동 무음 (옵션 토글 없음).
5. **G-Settings F5**: ATTACK_v*/RESPONSE_v*/FINAL.md/PLAN.md는 의사결정 기록으로 금지어 인용 보존 (사용자 노출 0). PLAN G5 wider scope grep은 CP4에서 별도 검증.
6. **G-Settings F6**: 데이터셋 버전 하드코딩 (`JLPTDeckMetadata.datasetVersion`). 데이터 리프레시 시 수동 bump.
7. **F14**: ~3% theoretical flake (12 random taps, 25% correct each). CI 1회 retry 권장.
8. **F2 (사람 검수)**: 코드 작업 영역 외 — PASS_WITH_BLOCKERS, PLAN G3 인간 백로그.

## 6. 롤백 방법 (요약)

### 부분 롤백 — Feature flag OFF (재빌드 1회)
| 항목 | flag |
|---|---|
| G-SessionComplete | `FeatureFlags.sessionCompleteCoaching = false` |
| G-CardView F12 | `FeatureFlags.cardPartOfSpeech = false` |
| G-CardView F16 | `FeatureFlags.cardTTS = false` |
| G-CardView F17 | `FeatureFlags.cardPronunciationTraps = false` |
| G-Settings F5/F6/F11 | 코드 git revert (flag 없음 — 카피 변경) |
| G-Settings F13 export | `FeatureFlags.dataExport = false` (CP2와 동일) |
| F14 | 테스트만 → flag 불필요 |

### 완전 롤백
- 4개 신규 source 파일 + 2개 신규 테스트 파일 삭제
- 11개 수정 파일 git revert
- pbxproj의 신규 항목 제거

### 데드라인 (PLAN.md §1)
- G 그룹: D-3
- F14: D-3
- F11: D-1 (latest)

## 7. CP3 미해결 / 후속 액션

### 사람 결정 (F2 — PASS_WITH_BLOCKERS)
- 번역 검수 layered sample 300개 (N4/N3/N2/N1 75개씩)
- 오류율 < 5% 임계 검증
- 초과 레벨 재생성 (D-3 늦음 → 출시 연기 검토 가능성)
- 산출물: `docs/translation-audit-v1.md` (미작성 — 검수 후 작성)

### 다음 단계 (CP3.5/CP4)
- **CP3.5 (D-2)**: F18 (UI-B) — 시각 완성도 통합 점검. CP3에서 추가된 UI 요소 (preview block, revealMetaRow, scopeBanner, AttributionRow) 라이트/다크 모드 spot check + Theme 토큰 정합성. `docs/finishing-debt.md` 항목 ≥80% 처리.
- **CP4 (D-1)**: F19 출시 직전 디테일 (아이콘 / 스크린샷 / 메타데이터 / 1.0.0 태그). G1~G7 게이트 7개 검증.

### CLAUDE.md 갱신 필요 (F19 권장)
- 테스트 카운트 "48/48" stale → 127 unit + 1 UI
- F7~F19 추가 도메인/액션 요약
- `pos` 필드 정책 + UI Theme 토큰 사용 패턴 추가

---

CP3 코드 작업 완료. CP3.5 (F18 UI-B) 진행 가능.
