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

    func testCaptureScreens() {
        let app = XCUIApplication()
        app.launch()

        _ = app.staticTexts["今日"].waitForExistence(timeout: 15)
        Thread.sleep(forTimeInterval: 1.5) // let the first frame paint
        capture(app, "01-today")

        tap(app.staticTexts["经文"])
        _ = app.staticTexts["众妙之门"].waitForExistence(timeout: 5)
        capture(app, "02-contents")

        tap(app.staticTexts["众妙之门"])
        _ = app.staticTexts["第一章"].waitForExistence(timeout: 5)
        capture(app, "03-reader-vernacular")

        let paragraph = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "可以言说的")
        ).firstMatch
        // M7: long-press saves a 划线 into 笔记, and bookmark the chapter.
        if paragraph.waitForExistence(timeout: 6) { paragraph.press(forDuration: 0.9) }
        Thread.sleep(forTimeInterval: 0.6)
        tap(app.buttons["reader-bookmark"])

        tap(paragraph)
        capture(app, "04-reader-reveal")

        tap(app.buttons["逐句"])
        capture(app, "05-reader-sentence")

        tap(app.buttons["原文注释"])
        capture(app, "06-reader-annotated")

        // M9: start 聆听 — the audio player bar slides up.
        tap(app.buttons["reader-listen"])
        _ = app.buttons["listen-toggle"].waitForExistence(timeout: 3)
        capture(app, "06b-reader-listen")
        tap(app.buttons["listen-stop"])

        tap(app.buttons["reader-back"])

        // A gated chapter shows the paywall (free preview is 1–3).
        tap(app.staticTexts["上善若水"])
        _ = app.staticTexts["解锁全本"].waitForExistence(timeout: 5)
        capture(app, "07-paywall")
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
