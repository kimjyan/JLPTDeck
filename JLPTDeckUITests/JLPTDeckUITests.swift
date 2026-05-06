//
//  JLPTDeckUITests.swift
//  JLPTDeckUITests
//
//  F14 (G-CardView smoke): single XCUITest that drives the happy-path
//  user flow end-to-end so we have a CI canary that catches view-graph
//  regressions (renamed identifiers, missing rows, broken navigation).
//
//  Strategy:
//  - launchArguments override `jlpt.dailyLimit = 1` so the session
//    completes after 1 first-attempt-correct answer (or 2 answers if
//    the first is wrong → relearn re-queue → 1 more try).
//  - The test taps the answer marked "정답" (the accessibility label
//    appended after `isRevealed`)... but reveal happens AFTER selection.
//    So we tap the first choice, then on the next render the labels
//    flip to "정답"/"오답" — we use that to read whether to expect
//    SessionComplete (correct) or another card render (wrong).
//  - Wait predicates for asynchronous UI (auto-import, auto-advance).
//

import XCTest

final class JLPTDeckUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// F14 happy path: launch → import (skipped if cards exist) → home →
    /// 시작 → answer 1 question → SessionComplete reached.
    @MainActor
    func test_smoke_homeToSessionComplete() throws {
        let app = XCUIApplication()
        // Override dailyLimit so the session can complete after 1 correct
        // answer. iOS NSUserDefaults bridges `-<key> <value>` launch args
        // automatically, so the app's existing reads of
        // `UserDefaults.standard.integer(forKey: "jlpt.dailyLimit")`
        // pick this up without code changes.
        app.launchArguments = [
            "-jlpt.dailyLimit", "1",
            "-jlpt.level", "n4",
            // Use an in-memory SwiftData store so each test run starts
            // from a clean slate (no SRS state accumulation that could
            // exhaust the limit*3 fetch cap of `todayReviewCards`).
            "-uitest_reset_state",
        ]
        app.launch()

        // 1. Home loads. Either we're already populated (DB seeded from
        //    a prior run) or the auto-import is in progress — we wait
        //    up to 30s for the start button to become hittable.
        let startButton = app.buttons["시작하기"]
        XCTAssertTrue(
            startButton.waitForExistence(timeout: 30),
            "Home start button must appear within 30s (covers cold-import)."
        )

        // F14 DoD: "첫 실행 → 자동 import → 홈 → 시작 → 1문제 → 완료"
        // must actually run end-to-end. With `-uitest_reset_state` the
        // in-memory DB starts empty and HomeView triggers auto-import,
        // which yields 666+ N4 cards → CardScheduler picks 1 → button
        // enabled. If the button is disabled here, the import or
        // scheduler regressed — that's a release-blocking failure, not
        // a "skip-the-test" condition. (Per CP3_REVIEW_F14 FAIL 1.)
        XCTAssertTrue(
            startButton.isEnabled,
            "Start button must be enabled with -uitest_reset_state + dailyLimit=1. " +
            "Disabled here means auto-import or scheduler is broken — release blocker."
        )

        startButton.tap()

        // 2. Quiz card render — choices appear. We rotate across all
        //    four choice positions over successive cards so we hit the
        //    correct answer within bounded taps. (Each card's correct
        //    position is randomised; cycling positions converges faster
        //    than always tapping #1.)
        let completeTitle = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '완료!'")
        ).firstMatch
        let choicePrefixes = ["선택지 1:", "선택지 2:", "선택지 3:", "선택지 4:"]

        // Wait for the very first card render before the loop starts.
        let firstChoice = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "선택지 1:")
        ).firstMatch
        XCTAssertTrue(
            firstChoice.waitForExistence(timeout: 10),
            "Quiz first choice must appear within 10s."
        )

        // Up to 12 taps. With 25% correct probability per random tap,
        // P(no correct after 12) ≈ 3.2%. Three runs back-to-back ≈ 99.7%
        // per session. Worst-case wall-clock: 12 × (1.2s autoAdvance +
        // ~0.5s wait) ≈ 21s. Well within the test budget.
        var completed = false
        for attempt in 0..<12 {
            let prefix = choicePrefixes[attempt % 4]
            let btn = app.buttons.matching(
                NSPredicate(format: "label BEGINSWITH %@", prefix)
            ).firstMatch

            // If SessionComplete has rendered (correct on prior attempt
            // → autoAdvance → isComplete), bail out before we tap any
            // residual button.
            if completeTitle.exists {
                completed = true
                break
            }

            if btn.exists, btn.isHittable {
                btn.tap()
            }

            // Wait briefly for either: SessionComplete, or the next
            // card's choice render. We poll completeTitle so a correct
            // answer exits the loop in <2s.
            if completeTitle.waitForExistence(timeout: 2) {
                completed = true
                break
            }
        }

        XCTAssertTrue(
            completed,
            "SessionCompleteView must render with '완료!' title within 12 random taps (P(flake) ≈ 3%)."
        )

        // 4. SessionComplete must contain the F10 first-attempt summary
        //    or at least the "홈으로" button so we know we hit the right
        //    screen (not a stale view).
        let homeBackButton = app.buttons["홈으로"]
        XCTAssertTrue(
            homeBackButton.waitForExistence(timeout: 5),
            "SessionComplete must expose the 홈으로 button to dismiss."
        )
        homeBackButton.tap()

        // 5. Back on home. Smoke passes if the start button is hittable
        //    again (the navigation cycled cleanly).
        XCTAssertTrue(
            startButton.waitForExistence(timeout: 5),
            "Home must reappear after dismissing SessionComplete."
        )
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
