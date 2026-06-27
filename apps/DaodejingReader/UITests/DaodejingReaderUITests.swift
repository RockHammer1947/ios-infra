import XCTest

@MainActor
final class DaodejingReaderUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// One launch covers the whole smoke flow. The simulator can drop a
    /// background assertion on a cold app launch, so we keep this bundle to a
    /// single launch (fewer launches → fewer races) and lean on generous
    /// settle timeouts; genuine flakes are retried at the `scan` layer.
    func testLaunchTabsAndOpenChapter() {
        let app = XCUIApplication()
        app.launch()

        // Tabs are visible on launch.
        XCTAssertTrue(
            app.staticTexts["今日"].waitForExistence(timeout: 20),
            "今日 tab should be visible after launch"
        )
        XCTAssertTrue(app.staticTexts["经文"].waitForExistence(timeout: 5), "经文 tab should be visible")

        // Into 经文, open chapter 1 (众妙之门) and land on the reader.
        app.staticTexts["经文"].tap()
        let chapter = app.staticTexts["众妙之门"]
        XCTAssertTrue(chapter.waitForExistence(timeout: 10), "Chapter 1 should appear in the contents list")
        chapter.tap()

        XCTAssertTrue(
            app.staticTexts["第一章"].waitForExistence(timeout: 10),
            "Reader should show the opened chapter header"
        )
    }
}
