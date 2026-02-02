import XCTest

final class OpenPlaneUITests: XCTestCase {
  func testLaunchesToSettingsWhenNotConfigured() {
    let app = XCUIApplication()
    app.launchEnvironment["OPENPLANE_UI_TESTS"] = "1"
    app.launch()

    XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
  }

  func testConfiguredLoadsProjectsAndOpensWorkItemDetail() {
    let app = XCUIApplication()
    app.launchEnvironment["OPENPLANE_UI_TESTS"] = "1"
    app.launchEnvironment["OPENPLANE_UI_SEED_PROFILE"] = "1"
    app.launchEnvironment["OPENPLANE_UI_STUBS"] = "1"
    app.launch()

    XCTAssertTrue(app.navigationBars["Projects"].waitForExistence(timeout: 5))

    XCTAssertTrue(app.staticTexts["Project One"].waitForExistence(timeout: 5))
    app.staticTexts["Project One"].tap()

    XCTAssertTrue(app.navigationBars["Project One"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["PROJ1-1"].waitForExistence(timeout: 5))

    app.staticTexts["Fix bug"].tap()
    XCTAssertTrue(app.navigationBars["Work item"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.textFields["Title"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.textFields["Title"].value as? String, "Fix bug")
  }
}
