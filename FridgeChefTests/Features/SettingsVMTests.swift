import XCTest
@testable import FridgeChef

@MainActor
final class SettingsVMTests: XCTestCase {

    private var defaults: UserDefaults!
    private var theme: ThemeManager!
    private var store: StubRecipeStore!
    private var vm: SettingsVM!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "SettingsVMTests")!
        defaults.removePersistentDomain(forName: "SettingsVMTests")
        theme = ThemeManager(defaults: defaults)
        store = StubRecipeStore()
        vm = SettingsVM(theme: theme, store: store, keyProvider: { "sk-present" })
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "SettingsVMTests")
        super.tearDown()
    }

    func test_setTheme_persists() {
        vm.setTheme(.dark)
        XCTAssertEqual(theme.current, .dark)
        vm.setTheme(.light)
        XCTAssertEqual(theme.current, .light)
    }

    func test_apiKeyStatus_presentWhenProviderReturnsString() {
        XCTAssertEqual(vm.apiKeyStatus, .present)
    }

    func test_apiKeyStatus_missingWhenProviderThrows() {
        vm = SettingsVM(theme: theme, store: store, keyProvider: { throw OpenAIError.missingAPIKey })
        XCTAssertEqual(vm.apiKeyStatus, .missing)
    }

    func test_clearAll_emptiesStore() async {
        store.batches = [
            RecipeBatch(id: UUID(), createdAt: Date(), inputIngredients: [], inputImageThumbnailJPEG: nil, recipes: [], source: .ai)
        ]
        await vm.clearAll()
        XCTAssertEqual(store.batches, [])
    }
}
