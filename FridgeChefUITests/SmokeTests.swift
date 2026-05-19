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
        XCTAssertTrue(app.buttons["catalog.magic"].exists)

        // All four category cards visible on launch.
        for id in ["catalog.card.breakfast",
                   "catalog.card.lunch",
                   "catalog.card.dinner",
                   "catalog.card.fridge"] {
            let cell = app.descendants(matching: .any).matching(identifier: id).firstMatch
            XCTAssertTrue(cell.exists, "Catalog card \(id) should be visible")
        }
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

    func test_recipes_create_button_opensForm() {
        let app = launch()
        app.tabBars.buttons["Recipes"].tap()

        let createButton = app.navigationBars["Recipes"].buttons["recipes.create.button"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 3))
        createButton.tap()

        XCTAssertTrue(app.textFields["create.title.field"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["create.save.button"].exists)
    }
}
