# Project Memory — JLPTDeck

## Stack
- iOS 17+, SwiftUI, SwiftData
- SRS: SM-2 algorithm (pluggable for future FSRS swap)
- Data: bundled JMdict (~21,200 words, N4–N1)

## Architecture Rules
- Domain layer must remain pure Swift (no SwiftUI/SwiftData imports) to allow Android/KMP porting later.
- `SRSEngine` is an isolated module — never couple it to persistence or UI.

## Worker Split
- Task 1: SM-2 engine + `SRSState` SwiftData model
- Task 2: JMdict parsing + word bundle + Repository
- Task 3: `FlashcardView` + `OnboardingView` + `ReviewSessionView`

## Testing
- Unit tests live in `JLPTDeckTests/` (Xcode target), mirrored from `tests/` stub.
- Run: `xcodebuild test -scheme JLPTDeck -destination 'platform=iOS Simulator,name=iPhone 17' -skipMacroValidation -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1`
- `-skipMacroValidation` 필수 (TCA 매크로 fingerprint 승인 CLI 우회)

## Architecture Migration (In Progress)
- **2026-04-14** 기점으로 UI 레이어를 **TCA** 로 전환하기로 결정.
- 신규 피처는 TCA 필수. 기존 `@Observable` 두 개(`OnboardingViewModel`, `ReviewSessionViewModel`)는 해당 피처 손볼 때 Reducer 로 변환.
- 상세 컨벤션: `.claude/skills/tca-architecture.md` (반드시 먼저 읽을 것).
- Domain/Data 레이어는 무변경, UI 만 점진 교체. 각 단계마다 기존 25/25 유닛 테스트 회귀 확인.
