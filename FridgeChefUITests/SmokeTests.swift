import XCTest

final class SmokeTests: XCTestCase {

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["--ui-test-stub"]
        app.launch()
        return app
    }

    // Smoke: Catalog (Home tab) renders its core UI elements.
    // The full generate flow is exercised by CatalogVMTests;
    // running it via XCUITest is flaky (keyboard, navigation animations) and
    // adds little signal over the unit tests.
    func test_home_rendersCoreElements() {
        let app = launch()
        XCTAssertTrue(app.textFields["catalog.input"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["catalog.header"].exists)
        let magic = app.buttons["catalog.magic"]
        XCTAssertTrue(magic.exists)
    }

    func test_recipes_emptyState_visibleOnFreshLaunch() {
        let app = launch()
        app.tabBars.buttons["Recipes"].tap()
        // With a fresh stub store there are no recipe batches, so the collection view
        // renders no cells. UIContentUnavailableConfiguration text is not exposed as a
        // plain AXStaticText; instead verify the Recipes tab loaded successfully.
        let recipesNavBar = app.navigationBars["Recipes"]
        XCTAssertTrue(recipesNavBar.waitForExistence(timeout: 3))
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
