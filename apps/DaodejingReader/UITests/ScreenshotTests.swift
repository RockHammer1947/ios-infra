import XCTest

/// Walks the app and attaches a screenshot of every key screen. The Screenshots
/// workflow extracts these from the .xcresult with xcparse.
@MainActor
final class ScreenshotTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Best-effort: keep capturing later screens even if one step misses.
        continueAfterFailure = true
    }

    // TEMP: listening 2.0 smoke — mode-aware playback, resume dialog, cache+filler.
    func testListeningExperience() {
        let app = XCUIApplication()
        // Pre-seed chapter 1 as trial-unlocked via the UserDefaults argument
        // domain, so this test exercises the listening stack, not the gate tap.
        app.launchArguments = [
            "skip-launch-animation",
            "-trial.unlockedChapters", "<array><integer>1</integer></array>",
        ]
        app.launch()

        _ = app.staticTexts["今日"].waitForExistence(timeout: 15)
        tap(app.staticTexts["经文"])
        tap(app.staticTexts["众妙之门"])
        _ = app.staticTexts["第一章"].waitForExistence(timeout: 5)
        Thread.sleep(forTimeInterval: 1)
        XCTAssertFalse(app.staticTexts["免费试读"].exists, "chapter 1 should be pre-unlocked")
        XCTAssertTrue(app.buttons["reader-listen"].waitForExistence(timeout: 5), "listen button must exist")
        capture(app, "L0-before-listen")

        // 1. 原文 playback starts (no resume point yet → no dialog).
        tap(app.buttons["reader-listen"])
        XCTAssertTrue(app.buttons["listen-toggle"].waitForExistence(timeout: 5))
        capture(app, "L1-original-playing")
        Thread.sleep(forTimeInterval: 9) // let a couple of segments play
        tap(app.buttons["listen-stop"])

        // 2. Idle: the filler should keep synthesizing chapter 1 silently.
        Thread.sleep(forTimeInterval: 25)

        // 3. Re-tap → resume dialog with 继续/从头.
        tap(app.buttons["reader-listen"])
        let resume = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "继续播放")
        ).firstMatch
        XCTAssertTrue(resume.waitForExistence(timeout: 4), "resume dialog should appear")
        capture(app, "L2-resume-dialog")
        resume.tap()
        XCTAssertTrue(app.buttons["listen-toggle"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 3)
        tap(app.buttons["listen-stop"])

        // 4. 解读 tab reads the interpretation (fresh mode, own progress).
        tap(app.buttons["解读"])
        tap(app.buttons["reader-listen"])
        XCTAssertTrue(app.buttons["listen-toggle"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "解读")
        ).firstMatch.exists)
        capture(app, "L3-interpretation-playing")
        Thread.sleep(forTimeInterval: 4)
        tap(app.buttons["listen-stop"])
    }

    func testCaptureScreens() {
        let app = XCUIApplication()
        app.launchArguments = ["skip-launch-animation"]
        // Content screens need every chapter reachable; the gate flow below
        // relaunches WITHOUT this to capture the real trial gate.
        app.launchEnvironment["DAODEJING_UNLOCK_ALL"] = "1"
        app.launch()

        _ = app.staticTexts["今日"].waitForExistence(timeout: 15)
        Thread.sleep(forTimeInterval: 1.5) // let the first frame paint
        capture(app, "01-today")

        tap(app.staticTexts["经文"])
        _ = app.staticTexts["众妙之门"].waitForExistence(timeout: 5)
        capture(app, "02-contents")

        tap(app.staticTexts["众妙之门"])
        _ = app.staticTexts["第一章"].waitForExistence(timeout: 5)
        capture(app, "03-reader-original")

        let paragraph = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "道可道")
        ).firstMatch
        // M7: long-press saves a 划线 into 笔记, and bookmark the chapter.
        if paragraph.waitForExistence(timeout: 6) { paragraph.press(forDuration: 0.9) }
        Thread.sleep(forTimeInterval: 0.6)
        tap(app.buttons["reader-bookmark"])

        // Tap the 原文 line to reveal its 白话.
        tap(paragraph)
        capture(app, "04-reader-reveal")

        // 详细解读.
        tap(app.buttons["解读"])
        capture(app, "05-reader-interpretation")

        // M9: start 聆听 — the audio player bar slides up.
        tap(app.buttons["reader-listen"])
        _ = app.buttons["listen-toggle"].waitForExistence(timeout: 3)
        capture(app, "06b-reader-listen")
        tap(app.buttons["listen-stop"])

        tap(app.buttons["reader-back"])

        tap(app.staticTexts["笔记"])
        // Populated now that we highlighted and bookmarked chapter 1 (M7).
        _ = app.staticTexts["划线"].waitForExistence(timeout: 5)
        capture(app, "08-notes")

        tap(app.staticTexts["我的"])
        capture(app, "09-profile")

        // M8: 设置 sheet.
        tap(app.buttons["open-settings"])
        _ = app.staticTexts["外观"].waitForExistence(timeout: 4)
        capture(app, "10-settings")
        tap(app.buttons["settings-done"])

        // Relaunch WITHOUT the unlock override: an un-trialed chapter shows
        // the real gate (trial offer while free reads remain, else paywall).
        let gated = XCUIApplication()
        gated.launchArguments = ["skip-launch-animation"]
        gated.launch()
        _ = gated.staticTexts["今日"].waitForExistence(timeout: 15)
        tap(gated.staticTexts["经文"])
        tap(gated.staticTexts["上善若水"])
        _ = gated.staticTexts["解锁全本"].waitForExistence(timeout: 5)
        capture(gated, "07-gate")
    }

    private func tap(_ element: XCUIElement) {
        if element.waitForExistence(timeout: 6) {
            element.tap()
            Thread.sleep(forTimeInterval: 0.6) // let the transition settle
        }
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
