import XCTest

final class DaodejingReaderUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testRootViewAppearsOnLaunch() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(
            app.staticTexts["道可道，非常道"].waitForExistence(timeout: 10),
            "Placeholder root view should be visible after launch"
        )
    }
}
