# JLPTDeck — App Store Submission Bundle

> v1.0.0 TestFlight 베타 / App Store Connect 제출용 메타데이터 + 스크린샷.
> 본 디렉토리는 **사람이 App Store Connect에 직접 입력**하는 자료의 source-of-truth.
> 자동 제출 (fastlane 등) 미사용 — 메인테이너 1명 운영 가정.

## 1. 디렉토리 구조

```
AppStore/
├── README.md                          (this file)
├── ko/                                한국어 메타데이터 (primary locale)
│   ├── name.txt                       앱 이름 (≤ 30자)
│   ├── subtitle.txt                   부제 (≤ 30자)
│   ├── promotional_text.txt           프로모션 텍스트 (≤ 170자)
│   ├── description.txt                설명 (≤ 4,000자)
│   ├── keywords.txt                   검색어 (≤ 100자, 콤마 구분)
│   └── release_notes_v1.0.0.txt       릴리즈 노트 (≤ 4,000자)
├── en/                                (TODO v1.x — 영어 locale 출시 시)
└── screenshots/
    └── iPhone-6_5/                    iPhone 17 (1290×2796) 스크린샷 5장
        ├── 01_quiz_4choice.png        Quiz card (reveal 후, F12/F16 visible)
        ├── 02_session_complete.png    SessionComplete (F7+F10)
        ├── 03_stats.png               Stats (F11 scope banner)
        ├── 04_mistakes.png            Mistakes empty state
        └── 05_settings.png            Settings (F6 attribution)
```

## 2. 사람이 직접 처리해야 하는 항목

### A. App Store Connect 입력 (메타데이터)
- 앱 이름 = `ko/name.txt`
- 부제 = `ko/subtitle.txt`
- 프로모션 텍스트 = `ko/promotional_text.txt`
- 설명 = `ko/description.txt`
- 검색어 = `ko/keywords.txt`
- 릴리즈 노트 = `ko/release_notes_v1.0.0.txt`
- 카테고리: 교육 (Primary), 참고자료 (Secondary)
- 연령등급: 4+ (외부 링크 있음 / 폭력 없음)
- 가격: 무료 (FINAL.md §3 v1.0 무료 확정)

### B. 스크린샷 업로드
- iPhone 6.5" (1290×2796) — `screenshots/iPhone-6_5/` 5장
- TODO: iPhone 5.5" (1242×2208) — Apple 요구 시 별도 캡처 필요 (iPhone 8 Plus 시뮬레이터)
- TODO: iPad — v1.0 미지원 (iPhone-only 가정)

### C. 앱 아이콘 1024×1024 (디자인 자산)
**현재 상태**: `JLPTDeck/Assets.xcassets/AppIcon.appiconset/Contents.json`에
1024×1024 슬롯 정의는 있으나 실제 PNG 미첨부.

**필요 작업** (본 리포 외부에서):
1. 1024×1024 PNG 아이콘 디자인 (warm paper / clay accent — Theme 색상 일관)
2. 라이트 / 다크 / tinted 변형 3종
3. Xcode → Assets.xcassets → AppIcon → 슬롯 3곳에 PNG 드래그
4. 빌드 후 시뮬레이터 홈 화면 / TestFlight 빌드 thumbnail 확인

### D. TestFlight Tester Notes (베타용)
`docs/beta-data-sop.md` §2 "베타 사용자에게 보낼 안내문" 본문 그대로 복사 →
TestFlight Tester Notes에 붙여넣기.

**선결 조건**: `docs/beta-data-sop.md`의 `<maintainer-email-here>` 토큰을 실제
이메일로 치환 (PLAN.md G3, CP2 deadlock 인간 결정 H1+H2).

### E. git tag v1.0.0
TestFlight 빌드 업로드 + App Store Connect 메타데이터 입력 + 7개 게이트
모두 ✓ 확인 후:

```
git tag -a v1.0.0 -m "v1.0.0 — TestFlight beta release"
git push origin v1.0.0
```

태그는 자동 생성하지 않음 — 빌드 업로드 직전 메인테이너가 직접.

## 3. 검증 (CP4 G5 grep)

App Store 메타데이터에 F5 금지어 0건은 `PLAN.md` G5 게이트 명령으로 확인.
검증 결과 evidence: `CP4_EVIDENCE/forbidden_grep_strict.txt` (0건). 본 README의
원시 패턴 인용을 피하기 위해 패턴 자체는 PLAN.md에만 기록.

## 4. 알려진 한계

- 영어 locale 미작성 (v1.x)
- iPad 스크린샷 미작성 (v1.x — iPad 지원 결정 후)
- 앱 아이콘 PNG 미첨부 — 메인테이너 디자인 작업 후 추가
- App Preview 비디오 (15~30초) 미제작 — 5장 정적 스크린샷만
- 키워드 100자 제한 사용량 검증 미실시 (cur: 73자) — 충분 여유
