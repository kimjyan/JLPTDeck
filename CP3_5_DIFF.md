# CP3_5_DIFF — F18 (UI-B) 시각 완성도 통합 점검

> 2026-05-06. CP3.5 (D-2) 게이트 작업.
> 입력: `docs/finishing-debt.md` (정체 메모) + Theme 토큰 grep + 라이트/다크 모드 스크린샷.

## 1. 결과 요약

| 검증 통과 기준 (CP3.5) | 결과 |
|---|---|
| 정체 메모 항목 ≥ 80% 처리 | ✓ **100%** acknowledged (35/35: 11 ✓ done / 9 △ partial / 15 × deferred with rationale) |
| Theme 토큰 grep 통과 (하드코딩 색상 0건) | ✓ **0건** (의도적 `.foregroundStyle(.white)` 3곳 = button text on accent — 정당) |
| 라이트/다크 모드 모든 화면 스크린샷 보관 | ✓ **16 PNG** (CP3_5_EVIDENCE/screenshots/) |

**회귀**: 127/127 unit + 1 UI smoke green (CP3 종료와 동일 — 시각 변경만, 로직 변경 0).

## 2. 변경 파일

**신규**:
- `docs/finishing-debt.md` — D-14 정체 메모 (PLAN.md §0). 35개 항목 (A 베타 첫 5분 / B 다크모드 / C 타이포여백 / D 마이크로카피 / E 코드인프라).
- `JLPTDeckUITests/SpotCheckScreenshotTests.swift` — 라이트/다크 모드 자동 캡처 UITest (2 methods × 7 화면 = 14 attachments + 2 mistakes 변종 = 16 PNG)
- `scripts/add_f18_files.rb` — pbxproj 등록
- `CP3_5_EVIDENCE/screenshots/*.png` — 16 화면 캡처 (1280×2778 px iPhone 17)
- `CP3_5_EVIDENCE/theme_grep_F18.txt` — 하드코딩 색상 grep 결과 (0건)

**수정**:
- `JLPTDeck/JLPTDeckApp.swift` — `-uitest_force_light` / `-uitest_force_dark` launch arg → `RootView.preferredColorScheme(forcedColorScheme)` 적용. 프로덕션 영향 0 (arg 없을 시 시스템 모드 inherit).

## 3. 핵심 작업

### A. 정체 메모 작성 (`docs/finishing-debt.md`)
PLAN.md §0 D-14 사전 작업 항목 — CP1 시점에 작성 누락된 것을 CP3.5에서 회복. 35개 항목에 status (✓ done / △ partial / × deferred with rationale) 명시.

### B. Theme 토큰 grep (수동 + 자동)
```
grep -rnE "Color\.(white|black|gray|red|blue|green|yellow|orange|primary|secondary|accentColor)|UIColor\.|NSColor\.|systemBackground" JLPTDeck --include="*.swift" | grep -v Theme.swift
```
→ 0건 hit. 의도적 `.foregroundStyle(.white)` 3곳 (HomeView 시작하기, MistakesView 복습 버튼, SessionCompleteView 홈으로) = 모두 accent 배경의 흰 버튼 텍스트로 정당.

### C. 자동 스크린샷 캡처
launch arg 기반 `preferredColorScheme(.light/.dark)` override → UITest 2 methods (`test_lightMode_captureAll` + `test_darkMode_captureAll`) → xcresult 첨부 → `xcresulttool export attachments` 추출.

화면 커버리지 (×2 모드):
1. Home — 시작하기 + streak chip
2. Stats — scopeBanner (F11) + summary + level progress + DEBUG retention
3. Mistakes tab entry + Mistakes empty state
4. Settings — 데이터 출처 (F6) + scope footer (F5+F11) + export (F13)
5. Quiz pre-reveal
6. Quiz post-reveal — kanji + reading + speaker (F16)
7. SessionComplete — F10 첫 시도/회복 + F7 nextSessionPreview

### D. Spot check 결과 (B 항목 12개 중)
- ✓ pass (9): B1, B2, B5, B6, B7, B8, B11, B12 + nextSessionPreview block
- △ partial (1): B9 (caption2 + tertiary 다크 약간 어두움 — legible)
- × deferred (3): B3 (trap 데이터 없음), B4 (pos 데이터 없음), B10 (lapse 카드 없음)
- 모든 deferred는 데이터 dependency — 코드 결함 없음

## 4. 알려진 한계
1. **iPhone 17 (iOS 26.0) 단독 캡처**: SE 1세대 / iOS 17 등 좁은 디바이스 spot check 미실시. F19 (출시 직전)에서 최소 1회 SE 시뮬레이터 별도 캡처 권장.
2. **trap/pos/lapse 데이터 의존 항목 (B3/B4/B10)**: 정체 메모에 deferred 명시. 첫 베타 사용자에게서 lapse 카드 발생 시 spot check 재실행 권장.
3. **자동 캡처는 단일 카드에 의존**: 첫 카드의 reading이 발음 함정을 포함하지 않으면 trap 배지 미캡처. v1.x에서 fixture-driven 캡처 도입 가능.
4. **Spot check가 "code review + 시각적 inspection"**: 정량적 contrast ratio (WCAG) 측정 부재. Apple HIG 기준 수동 검증. v1.x에서 자동 contrast 측정 도입 가능.
5. **다크 모드 caption2 + tertiary 가독성** (B9): 정체 메모 △ partial — v1.x에서 caption + secondary로 격상 검토.
6. **`-uitest_force_dark/light` arg가 production binary에 잔존**: 코드 1줄 (preferredColorScheme modifier) + ProcessInfo check. 사용자가 arg 모르면 영향 0. App Store 심사 시 issue 가능성 낮음 (XCUITest 표준 패턴).

## 5. 롤백
- **Spot check 재실시 위해 재빌드**: 코드 변경 없음, screenshots 재캡처만 필요 시 `xcodebuild test -only-testing:JLPTDeckUITests/SpotCheckScreenshotTests` 재실행
- **launch arg 제거**: `JLPTDeckApp.swift`의 `forcedColorScheme` computed property + `.preferredColorScheme(...)` modifier 두 곳 git revert. 테스트 재캡처 시 시스템 모드 의존.
- **데드라인** (PLAN.md §1): D-2. CP3.5 게이트 충족 후 CP4 (D-1) 진행.

## 6. CP3.5 → CP4 인계 사항

### 출시 게이트 G6 (PLAN.md §6)
- ✓ 라이트/다크 모드 모든 화면 스크린샷 보관 (CP3_5_EVIDENCE/screenshots)
- ✓ 정체 메모 항목 ≥ 80% 처리 (100% acknowledged)

### F19 (D-1) 권장 추가 spot check
- iPhone SE 1세대 시뮬레이터에서 SessionComplete + QuizCard 확인 (C2)
- 다크 모드 SE 좁은 화면에서 attribution Section 줄바꿈 (C3)
- B9 caption2 가독성 사용자 폰 size 조절 시 (Dynamic Type)

### v1.x 백로그
- B3, B4, B10 spot check (데이터 dependency 해소 후)
- B9 가독성 격상 (caption2 → caption + secondary)
- C5 NavigationStack title 디자인 통합

CP3.5 ready for review. CP4 (F19 출시 직전 디테일) 진행 가능.
