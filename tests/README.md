# tests/

The canonical test targets for JLPTDeck live in the Xcode project:

- `JLPTDeckTests/` — unit tests
- `JLPTDeckUITests/` — UI tests

Run all tests:

```bash
xcodebuild test \
  -project JLPTDeck.xcodeproj \
  -scheme JLPTDeck \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

This directory exists as a harness-audit entrypoint and may host cross-target integration helpers later.
