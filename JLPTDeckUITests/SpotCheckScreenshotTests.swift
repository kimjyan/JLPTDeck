//
//  SpotCheckScreenshotTests.swift
//  JLPTDeckUITests
//
//  F18 (CP3.5) — capture light + dark mode screenshots of every major
//  screen so the spot-check pass against `docs/finishing-debt.md` has
//  evidence to compare against. Each captured screen is attached to the
//  xcresult bundle (lifetime = .keepAlways) so reviewers can inspect
//  later without re-running.
//
//  Strategy:
//  - Two test methods: `test_lightMode_captureAll` and
//    `test_darkMode_captureAll`. Each launches the app once and walks
//    through the 4 tabs + the in-review states (quiz card +
//    SessionComplete).
//  - Color scheme is forced via `-uitest_force_light` /
//    `-uitest_force_dark` launch args (handled by `JLPTDeckApp`'s
//    `preferredColorScheme(forcedColorScheme)` modifier).
//  - In-memory store via `-uitest_reset_state` so the simulator state
//    doesn't bleed across runs (F14 pattern).
//

import XCTest

final class SpotCheckScreenshotTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true   // capture as many screens as possible
    }

    @MainActor
    func test_lightMode_captureAll() throws {
        try captureAllScreens(modeLabel: "light", forceArg: "-uitest_force_light")
    }

    @MainActor
    func test_darkMode_captureAll() throws {
        try captureAllScreens(modeLabel: "dark", forceArg: "-uitest_force_dark")
    }

    @MainActor
    private func captureAllScreens(modeLabel: String, forceArg: String) throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-jlpt.dailyLimit", "1",
            "-jlpt.level", "n4",
            "-uitest_reset_state",
            forceArg,
        ]
        app.launch()

        // 1. Home tab — initial render after import.
        let startButton = app.buttons["시작하기"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 30),
                      "[\(modeLabel)] Home start button must appear")
        attach(name: "01-home-\(modeLabel)", app: app)

        // 2. Stats tab — scopeBanner + summary + level progress.
        app.tabBars.buttons["통계"].tap()
        // Wait for the scope banner identifier to appear.
        let scopeNotice = app.otherElements["stats.scopeNotice"]
        _ = scopeNotice.waitForExistence(timeout: 5)
        attach(name: "02-stats-\(modeLabel)", app: app)

        // 3. Mistakes tab — empty state (in-memory DB has no lapses yet).
        app.tabBars.buttons["틀린 단어"].tap()
        let mistakesEntry = app.buttons["틀린 단어 보기"]
        _ = mistakesEntry.waitForExistence(timeout: 5)
        attach(name: "03-mistakes-tab-\(modeLabel)", app: app)
        if mistakesEntry.exists {
            mistakesEntry.tap()
            sleep(1)
            attach(name: "03b-mistakes-empty-\(modeLabel)", app: app)
            // dismiss
            let closeBtn = app.navigationBars.buttons["닫기"]
            if closeBtn.exists { closeBtn.tap() }
        }

        // 4. Settings tab — data section + attribution + scope footer.
        app.tabBars.buttons["설정"].tap()
        let settingsExport = app.buttons["settings.export"]
        _ = settingsExport.waitForExistence(timeout: 5)
        attach(name: "04-settings-\(modeLabel)", app: app)

        // 5. Back to Home → start a session.
        app.tabBars.buttons["홈"].tap()
        XCTAssertTrue(startButton.waitForExistence(timeout: 5),
                      "[\(modeLabel)] Home re-appears")
        // CP3.5 screenshot harness — capture even when start is disabled
        // (zero-card edge state) so reviewers can see WHY a smoke run
        // would skip. The smoke gate (F14) treats this as a failure;
        // the screenshot pass treats it as evidence to inspect.
        if !startButton.isEnabled {
            attach(name: "05-quiz-zero-state-\(modeLabel)", app: app)
            return
        }
        startButton.tap()

        // 6. Quiz card — pre-reveal state.
        let firstChoice = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH '선택지 1:'")
        ).firstMatch
        XCTAssertTrue(firstChoice.waitForExistence(timeout: 10),
                      "[\(modeLabel)] First choice must render")
        attach(name: "05-quiz-prereveal-\(modeLabel)", app: app)

        // 7. Quiz card — post-reveal (tap any choice).
        firstChoice.tap()
        // Reveal animation ~250ms; autoAdvance fires at ~1.2s. Snapshot
        // at 0.4s to land squarely inside the reveal window for ALL
        // cards (the meta row only appears when pos/TTS/traps are
        // present — using sleep keeps the capture deterministic for
        // empty-meta cards like 踏む).
        usleep(400_000)
        attach(name: "06-quiz-revealed-\(modeLabel)", app: app)

        // 8. Walk to SessionComplete by tapping through up to 12 attempts.
        let completeTitle = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '완료!'")
        ).firstMatch
        let prefixes = ["선택지 1:", "선택지 2:", "선택지 3:", "선택지 4:"]
        for attempt in 0..<12 {
            if completeTitle.waitForExistence(timeout: 2) { break }
            let btn = app.buttons.matching(
                NSPredicate(format: "label BEGINSWITH %@", prefixes[attempt % 4])
            ).firstMatch
            if btn.exists, btn.isHittable { btn.tap() }
        }
        if completeTitle.exists {
            attach(name: "07-session-complete-\(modeLabel)", app: app)
        } else {
            attach(name: "07-session-complete-NOT-REACHED-\(modeLabel)", app: app)
        }
    }

    @MainActor
    private func attach(name: String, app: XCUIApplication) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
