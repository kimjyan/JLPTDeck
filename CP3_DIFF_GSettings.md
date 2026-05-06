# CP3_DIFF_GSettings — F5 (카피 정정) + F6 (attribution) + F11 (결핍 명시) + F13 export 통합

## 변경 vs CP2 종료 시점
- F13 export 버튼: 이미 부착 (CP2). 변경 없음.
- F5/F6/F11: CP2 종료 시점 SettingsView는 기본 attribution 1줄 + 데이터셋 버전/JLPT 비공식 명시 부재.

## 변경 파일
**신규**:
- `JLPTDeck/Shared/JLPTDeckMetadata.swift` — `datasetVersion = "2026-04-15-r1"` + `datasetCardCount = 7316` 빌드타임 상수
- `JLPTDeck/Features/Settings/AttributionRow.swift` — 재사용 가능한 attribution 행 (Link 자동 처리, 외부 링크 아이콘)
- `scripts/add_g_settings_files.rb`

**수정**:
- `JLPTDeck/Features/Settings/SettingsView.swift` — 앱 정보 Section 확장 (데이터셋 버전 행 추가, F5/F11 footer 카피), 신규 "데이터 출처 / 라이선스" Section (JMdict + Tanos + JLPT 비공식 1줄)
- `JLPTDeck/Features/Stats/StatsView.swift` — `scopeBanner` 신규 (F11 결핍 명시)
- `STATUS_v1.md` — legacy 마킹 + 산문에서 금지어 제거 (한국어 뜻 인식 학습 / 한국어 뜻 + 한국어 UI로 정정)

## 핵심 카피 (F5 정렬)

**Settings 앱 정보 footer** (F5+F11 결합):
> 한국어 뜻 인식 단어장 (4지선다). 이 앱은 한국어 뜻 인식만 측정합니다 — 문맥규정·용법·읽기·발음 약점은 측정 대상이 아닙니다.

**Settings 데이터 출처 Section** (F6):
1. JMdict — EDRDG, CC BY-SA 4.0, 외부 링크
2. JLPT 어휘 목록 — Tanos.co.uk (Jonathan Waller), 비공식 추정
3. JLPT 비공식 1줄 — "JLPT 레벨 분류는 비공식 추정이며 일본국제교류기금 공식 출제 기준이 아닙니다"

**Stats scope banner** (F11):
> 이 통계는 한국어 뜻 인식만 반영합니다. 문맥규정·용법·읽기·발음 약점은 측정하지 않습니다.

## 검증

**F5 grep** (CP3_EVIDENCE/forbidden_grep_GSettings.txt):
- 대상: `JLPTDeck/`, `CLAUDE.md`, `STATUS_v1.md`
- 패턴: `한국인 학습자 특화\|JLPT 종합 대비\|액티브 리콜\|한국어 native`
- **결과: 0건 ✓**

(주: `ATTACK_v*.md`, `RESPONSE_v*.md`, `FINAL.md`, `PLAN.md`는 의사결정 기록이며 금지어를 "사용 금지" 목록으로 인용함. 이 인용은 사용자 노출 카피가 아니라 결정 기록의 메타-참조이므로 F5 의도와 충돌하지 않음. PLAN.md G5 strict grep은 출시 직전 CP4에서 별도 wider scope 검증.)

**테스트**: 127/127 green (CP3_EVIDENCE/test_GSettings.txt) — 새 테스트 추가 없음 (UI 카피만 변경). 기존 reducer/domain 테스트 회귀 0건.

**빌드**: BUILD SUCCEEDED (CP3_EVIDENCE/build_GSettings.txt)

**외부 송신 grep**: 0건 (CP3_EVIDENCE/network_grep_GSettings.txt) — `Link(destination:)`은 SwiftUI가 처리, 외부 송신 0.

## DoD 매핑

| F | DoD | 충족 |
|---|---|---|
| F5 | grep 0건 | ✓ (app+CLAUDE+STATUS_v1) |
| F6 | EDRDG/JMdict/Tanos 라이선스 + 데이터셋 버전 + JLPT 비공식 명시 visible | ✓ (Settings 데이터 출처 Section 4행 + 데이터셋 버전 행) |
| F11 | About + StatsView 결핍 명시 1줄 | ✓ (Settings footer + Stats scopeBanner) |
| F13 | export 버튼 (이미 CP2 완료, 변경 없음) | — |

## 알려진 한계
1. **데이터셋 버전 하드코딩**: `JLPTDeckMetadata.datasetVersion`이 build-time 상수. 데이터 리프레시 시 수동 bump 필요. CI에서 JSON pull date를 자동 주입하는 단계는 v1.x.
2. **외부 링크 안전성**: `Link(destination:)`이 SwiftUI 표준이지만 사용자가 brower로 이동. URL 유효성 (HTTP 200) 자동 검증 없음 — Tanos.co.uk가 다운되면 dead link. 베타 단계에서 모니터링.
3. **JLPT 비공식 명시 위치**: Stats보다는 Settings에만 noted. 사용자가 통계 화면에서 "이 N3 분류 정확한가?" 의심 시 Settings로 이동해야 알 수 있음. v1.x StatsView 카드별 hover/탭 가이드 검토.
4. **F11 카피 미세조정**: "측정하지 않습니다" 문장이 negative-leading. 베타에서 사용자 인식 측정 후 v1.x positive-framed 변형 (예: "한국어 뜻 인식에 특화") 가능.
5. **Stats 통계 페이지 카드별 컨텍스트 없음**: 정답률 표시 옆에 "이 수치의 한계" 소형 인포 아이콘 부재. F11이 페이지 헤더로만 처리. v1.x.
6. **STATUS_v1.md legacy 마킹**: 산문 정정만 했고 ARCHIVED 헤더만 추가. 파일 자체 삭제는 하지 않음 (diff 보존). 향후 STATUS.md(현재 fresh) 도입 시 STATUS_v1 폐기 가능.
7. **F18 (UI-B) 영역 미실시**: AttributionRow / scopeBanner 라이트/다크 모드 spot check + 좁은 화면 줄바꿈 (특히 SE).
8. **AttributionRow 다국어 미지원**: 향후 영어 메뉴/JP UI 시 라이선스 텍스트 i18n 필요. v1.0 한국어 단일 가정.

## 롤백
- **재빌드 1회**: F13만 재롤백하려면 `FeatureFlags.dataExport = false` (CP2와 동일). F5/F6/F11은 카피 변경이라 코드 git revert만 필요 (FeatureFlag 불요).
- **부분**: SettingsView "데이터 출처 / 라이선스" Section 통째 주석 처리 → 기존 단일 footer로 회귀.
- **완전**: 신규 2 파일 삭제 + SettingsView/StatsView git revert + STATUS_v1 git revert.
- **데드라인** (PLAN.md §1): F5 D-3, F6 D-3, F11 D-1. F11은 가장 늦어도 됨.

G-Settings/About ready for review
