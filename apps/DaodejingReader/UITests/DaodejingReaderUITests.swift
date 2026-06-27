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
        // The tab shell renders the four primary destinations.
        XCTAssertTrue(
            app.staticTexts["今日"].waitForExistence(timeout: 10),
            "今日 tab should be visible after launch"
        )
        XCTAssertTrue(app.staticTexts["经文"].exists)
    }
}
