import XCTest
@testable import FridgeChef

final class ThemeManagerTests: XCTestCase {
    private var defaults: UserDefaults!
    private var manager: ThemeManager!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "ThemeManagerTests")!
        defaults.removePersistentDomain(forName: "ThemeManagerTests")
        manager = ThemeManager(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: #file)
        super.tearDown()
    }

    func test_default_is_system() {
        XCTAssertEqual(manager.current, .system)
    }

    func test_set_light_persists() {
        manager.current = .light
        let reloaded = ThemeManager(defaults: defaults)
        XCTAssertEqual(reloaded.current, .light)
    }

    func test_set_dark_persists() {
        manager.current = .dark
        let reloaded = ThemeManager(defaults: defaults)
        XCTAssertEqual(reloaded.current, .dark)
    }

    func test_style_maps_to_uiUserInterfaceStyle() {
        XCTAssertEqual(ThemeManager.Style.system.asInterfaceStyle, .unspecified)
        XCTAssertEqual(ThemeManager.Style.light.asInterfaceStyle, .light)
        XCTAssertEqual(ThemeManager.Style.dark.asInterfaceStyle, .dark)
    }
}
