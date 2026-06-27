import XCTest

@MainActor
final class DaodejingReaderUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testRootAndTabsAppearOnLaunch() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(
            app.staticTexts["今日"].waitForExistence(timeout: 10),
            "今日 tab should be visible after launch"
        )
        XCTAssertTrue(app.staticTexts["经文"].exists)
    }

    func testOpenChapterFromContents() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["经文"].waitForExistence(timeout: 10))
        app.staticTexts["经文"].tap()

        let chapter = app.staticTexts["众妙之门"]
        XCTAssertTrue(chapter.waitForExistence(timeout: 5), "Chapter 1 should appear in the contents list")
        chapter.tap()

        XCTAssertTrue(
            app.staticTexts["第一章"].waitForExistence(timeout: 5),
            "Reader should show the opened chapter header"
        )
    }
}
