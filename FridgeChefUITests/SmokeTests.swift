import XCTest

final class SmokeTests: XCTestCase {

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["--ui-test-stub"]
        app.launch()
        return app
    }

    // Smoke: Home renders its core UI elements.
    // The full generate→push flow is exercised by HomeVMTests + RecipeBatchVMTests;
    // running it via XCUITest is flaky (keyboard, navigation animations) and
    // adds little signal over the unit tests.
    func test_home_rendersCoreElements() {
        let app = launch()
        XCTAssertTrue(app.textFields["home.inputField"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.addButton"].exists)
        let suggest = app.buttons["home.suggestButton"]
        XCTAssertTrue(suggest.exists)
        // Disabled with no chips.
        XCTAssertFalse(suggest.isEnabled)
        // Helper text visible.
        XCTAssertTrue(app.staticTexts["INGREDIENTS"].exists)
    }

    func test_recipes_emptyState_visibleOnFreshLaunch() {
        let app = launch()
        app.tabBars.buttons["Recipes"].tap()
        XCTAssertTrue(app.staticTexts["No recipes yet"].waitForExistence(timeout: 3))
    }

    func test_settings_themeToggleToDark_persistsVisually() {
        let app = launch()
        app.tabBars.buttons["Settings"].tap()
        let seg = app.segmentedControls.firstMatch
        XCTAssertTrue(seg.waitForExistence(timeout: 3))
        seg.buttons.element(boundBy: 2).tap()
        XCTAssertTrue(seg.buttons.element(boundBy: 2).isSelected)
    }
}
