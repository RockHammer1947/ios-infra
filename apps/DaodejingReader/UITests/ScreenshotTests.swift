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
        tap(paragraph)
        capture(app, "04-reader-reveal")

        tap(app.buttons["逐句"])
        capture(app, "05-reader-sentence")

        tap(app.buttons["原文注释"])
        capture(app, "06-reader-annotated")

        tap(app.buttons["reader-back"])

        // A gated chapter shows the paywall (free preview is 1–3).
        tap(app.staticTexts["上善若水"])
        _ = app.staticTexts["解锁全本"].waitForExistence(timeout: 5)
        capture(app, "07-paywall")
        tap(app.buttons["reader-back"])

        tap(app.staticTexts["笔记"])
        _ = app.staticTexts["还没有笔记"].waitForExistence(timeout: 5)
        capture(app, "08-notes")

        tap(app.staticTexts["我的"])
        capture(app, "09-profile")
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
