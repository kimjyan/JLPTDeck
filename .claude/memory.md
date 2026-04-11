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
- Run: `xcodebuild test -scheme JLPTDeck -destination 'platform=iOS Simulator,name=iPhone 15'`
