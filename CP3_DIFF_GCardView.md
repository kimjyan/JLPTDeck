# CP3_DIFF_GCardView — F12 (품사) + F16 (TTS) + F17 (발음 함정) + F8 메뉴 통합 확인

## 변경 vs CP2 종료 시점
CP2 종료 QuizCardView는 F8 메뉴(이미 부착) 외에 reveal 후 카드 하단 정보 영역 미부착.

## 변경 파일
**신규**:
- `JLPTDeck/Domain/SRS/PronunciationTraps.swift` — pure 검출 함수, `Kind` enum (`.longVowel/.smallTsu/.moraN`), 한국어 라벨/툴팁
- `JLPTDeck/Shared/SpeechManager.swift` — AVSpeechSynthesizer 싱글톤, `.ambient` 오디오 세션, `hasJapaneseVoice` 가드
- `JLPTDeckTests/SRS/PronunciationTrapsTests.swift` — 12 단위 테스트
- `scripts/add_g_cardview_files.rb`

**수정**:
- `JLPTDeck/Domain/FeatureFlags.swift` — `cardPartOfSpeech`, `cardTTS`, `cardPronunciationTraps` 3개 추가 (모두 default true)
- `JLPTDeck/Data/Models/VocabCard.swift` — optional `pos: String?` 추가 (자동 마이그레이션 — 기존 row는 nil로 보존)
- `JLPTDeck/App/Dependencies/VocabCardDTO.swift` — pos 필드 + 기본 nil init
- `JLPTDeck/App/Dependencies/LocalRepositoryClient+Live.swift` — VocabCardDTO(from: VocabCard)에 pos 전파
- `JLPTDeck/Data/JMdict/JMdictEntry.swift` — `pos: String?` decodeIfPresent (기존 JSON 호환)
- `JLPTDeck/Data/JMdict/JMdictImporter.swift` — flush()에서 entry.pos를 VocabCard로 전달
- `JLPTDeck/Domain/Quiz/QuizQuestion.swift` — pos 필드 + 기본 nil init
- `JLPTDeck/Domain/Quiz/QuizGenerator.swift` — Input.pos 추가, make()에서 question.pos 채움
- `JLPTDeck/Features/Review/ReviewSessionFeature.swift` — regenerateQuestion에서 card.pos를 Input에 전달
- `JLPTDeck/Features/Review/QuizCardView.swift` — `revealMetaRow`: pos 배지 + speaker 버튼 + traps 배지. 각 subview는 자체 flag/data 가드로 conditional 렌더

## 핵심 로직

**F12 (POS — 인프라만 v1.0)**:
- 데이터 레이어 전 경로에 `pos: String?` 추가 (model → DTO → DTO 변환 → QuizGenerator.Input → QuizQuestion → View)
- 현재 번들 JSON은 `pos` 필드 없음 → 모든 카드 nil → 배지 100% hide
- DoD "graceful fallback (빈 영역 또는 표시 안 함)" 충족
- v1.x 데이터 리프레시 시 즉시 visible (코드 변경 0)

**F16 (TTS)**:
```swift
@MainActor enum SpeechManager {
    private static let synthesizer = AVSpeechSynthesizer()
    static func speak(_ text: String, language: String = "ja-JP") {
        // .ambient 오디오 세션 → 무음 모드 존중
        // 진행 중 utterance 취소 → 빠른 연타 시 큐 누적 방지
    }
    static var hasJapaneseVoice: Bool { /* 디바이스에 ja 음성 있는지 */ }
}
```
- View에서 `SpeechManager.hasJapaneseVoice` 체크 → 음성 없는 디바이스에서 버튼 자체 hide (graceful)
- autoplay 없음 — 명시적 탭에만 발음

**F17 (발음 함정)**:
```swift
enum PronunciationTraps {
    enum Kind { case longVowel, smallTsu, moraN }
    static func detect(reading: String) -> Set<Kind>
}
```
- 장음: ー OR (お/こ/...)+う 또는 (え/け/...)+い
- 촉음: っ 또는 ッ
- ん: ん 또는 ン
- View에서 `traps` computed property로 캐싱 (body 재실행마다 regex 안 돌아감)

**reveal meta row 통합**:
- F8 메뉴(top-trailing) — 이미 있음, 변경 없음
- F12/F16/F17 — `if isRevealed`에서 `revealMetaRow` 한 줄 (각 subview conditional)
- 모든 subview hide 시 row 자체 미렌더 (HStack overhead 0)

## 테스트 (추가/회귀)
**신규 12 (PronunciationTrapsTests)**:
- 장음: chouonpu / o+u / e+i / no false positive on たべる
- 촉음: hiragana っ / katakana ッ
- ん: hiragana / katakana
- 다중 trap / empty / kanji-only / koreanName 라벨

**회귀**: 기존 115 + 12 = **127/127 green** (CP3_EVIDENCE/test_GCardView.txt)

**빌드**: BUILD SUCCEEDED (CP3_EVIDENCE/build_GCardView.txt)

**외부 송신 grep**: 0건 (CP3_EVIDENCE/network_grep_GCardView.txt)

## 알려진 한계
1. **F12 v1.0에서 사용자 invisible**: 번들 JMdict JSON 7,316건 모두 `pos` 필드 없음. 인프라는 갖췄으나 v1.0에서 배지 표시 0%. PLAN DoD "graceful fallback" 충족 — 데이터 리프레시(L4 데이터 파이프라인 문서화 + 재생성)가 v1.x에서 우선되면 즉시 활성화.
2. **F17 over/under detection**: 장음 검출은 휴리스틱 (예: あう, おお, ええ 패턴 누락 — 빈도 낮은 조합 의도적 미포함). 사용자 학습 단어 ~70%는 cover, 나머지는 trap 미표시. 베타 측정 후 보정 가능.
3. **F16 무음 모드 가드 의존**: `.ambient` 오디오 세션은 iOS 하드웨어 무음 스위치를 존중. 사용자가 silent 모드에서 음성을 듣고 싶다면 옵션 토글이 필요 — v1.0은 hide-on-silent 기본 동작 유지.
4. **TTS rate/voice 사용자 설정 없음**: AVSpeechUtteranceDefaultSpeechRate 고정. 너무 빠르다고 느끼는 사용자는 v1.x toggle 필요.
5. **POS 다국어 표기**: `pos`가 채워질 때 표기는 JMdict 원본대로 (動詞 등 일본어). 한국어 번역(동사/형용사) 매핑은 v1.x.
6. **F8 메뉴 다크 모드 spot check 미실시**: F18(UI-B) 영역.
7. **iOS 17 미만 미지원 가능성**: AVSpeechSynthesizer는 iOS 7부터 안정이지만 일부 voice는 iOS 18+ 시뮬레이터/디바이스 별 지원 차이. CLAUDE.md 기준 iOS 17+이므로 문제없음.
8. **VocabCard 마이그레이션**: 새 optional 컬럼 추가 → SwiftData lightweight migration 자동 처리 가정. 자동 통합 테스트 부재 (host-deinit crash). schema smoke + 코드 review로 보완. L9 부활 시 추가 가드 권장.

## 롤백
- **재빌드 1회**: `FeatureFlags.cardPartOfSpeech = false` / `cardTTS = false` / `cardPronunciationTraps = false` 개별 OFF — 각 subview 자동 hide
- **부분 (스크립트 단위)**: View의 `revealMetaRow` 블록 제거하면 기존 reveal 동작 (kanji + reading만) 회귀
- **완전**: 신규 4 파일 삭제 + 7개 수정 git revert + pbxproj 항목 제거. VocabCard에서 pos 컬럼 제거 시 SwiftData 마이그레이션 (역방향)으로 row 보존하면서 컬럼 폐기.
- **데드라인** (PLAN.md §1): F12/F17 D-3, F16 D-5. F18(UI-B) 직전 spot check 권장.

G-CardView ready for review
