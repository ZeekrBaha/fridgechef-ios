import XCTest
import Combine
@testable import FridgeChef

@MainActor
final class RecipesVMTests: XCTestCase {

    private var store: StubRecipeStore!
    private var vm: RecipesVM!

    override func setUp() {
        super.setUp()
        store = StubRecipeStore()
        vm = RecipesVM(store: store, calendar: .current, now: { Date(timeIntervalSince1970: 1747584840) })
    }

    func test_load_emptyStore_emitsEmptyGroups() async {
        await vm.load()
        XCTAssertEqual(vm.groups, [])
        XCTAssertEqual(vm.visibleGroups, [])
    }

    func test_load_groupsBatchesByRelativeDate() async {
        let now = Date(timeIntervalSince1970: 1747584840)
        let today = now.addingTimeInterval(-3600)
        let yesterday = now.addingTimeInterval(-90_000)
        let lastWeek = now.addingTimeInterval(-3 * 86_400)
        store.batches = [
            makeBatch(date: today),
            makeBatch(date: yesterday),
            makeBatch(date: lastWeek),
        ]
        await vm.load()
        let titles = vm.groups.map(\.title)
        XCTAssertEqual(titles.first, "TODAY")
        XCTAssertTrue(titles.contains("YESTERDAY"))
        XCTAssertTrue(titles.contains("THIS WEEK"))
    }

    func test_reload_onNotification() async {
        store.batches = [makeBatch(date: Date(timeIntervalSince1970: 1747584000))]
        await vm.load()
        XCTAssertEqual(vm.groups.flatMap(\.items).count, 1)

        store.batches = []
        NotificationCenter.default.post(name: .recipesDidChange, object: nil)
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(vm.groups, [])
    }

    func test_filterFavorites_dropsBatchesWithoutFavorites_andTrimsRecipes() async {
        let r1 = makeRecipe(fav: false, title: "A")
        let r2 = makeRecipe(fav: true,  title: "B")
        let r3 = makeRecipe(fav: false, title: "C")
        let withFav = RecipeBatch(id: UUID(), createdAt: Date(timeIntervalSince1970: 1747584000),
                                  inputIngredients: [], inputImageThumbnailJPEG: nil,
                                  recipes: [r1, r2], source: .ai)
        let withoutFav = RecipeBatch(id: UUID(), createdAt: Date(timeIntervalSince1970: 1747570000),
                                     inputIngredients: [], inputImageThumbnailJPEG: nil,
                                     recipes: [r3], source: .ai)
        store.batches = [withFav, withoutFav]
        await vm.load()

        vm.filter = .favorites
        try? await Task.sleep(nanoseconds: 100_000_000)

        let allRecipes = vm.visibleGroups.flatMap { $0.items.flatMap(\.recipes) }
        XCTAssertEqual(allRecipes.count, 1)
        XCTAssertEqual(allRecipes.first?.title, "B")
    }

    func test_filterAll_visibleEqualsGroups() async {
        store.batches = [
            RecipeBatch(id: UUID(), createdAt: Date(timeIntervalSince1970: 1747584000),
                        inputIngredients: [], inputImageThumbnailJPEG: nil,
                        recipes: [makeRecipe(fav: false, title: "A"),
                                  makeRecipe(fav: true,  title: "B")],
                        source: .ai)
        ]
        await vm.load()
        vm.filter = .all
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(vm.visibleGroups, vm.groups)
    }

    func test_deleteBatch_callsStore_andReloads() async {
        let b = makeBatch(date: Date(timeIntervalSince1970: 1747584000))
        store.batches = [b]
        await vm.load()

        await vm.deleteBatch(id: b.id)

        XCTAssertEqual(store.deleteBatchCalls, [b.id])
    }

    // MARK: - helpers
    private func makeRecipe(fav: Bool, title: String) -> Recipe {
        Recipe(id: UUID(), title: title, description: "",
               ingredients: ["a"], steps: ["s"], estimatedTime: "5 min",
               isFavorite: fav, updatedAt: nil)
    }
    private func makeBatch(date: Date) -> RecipeBatch {
        RecipeBatch(id: UUID(), createdAt: date,
                    inputIngredients: ["x"],
                    inputImageThumbnailJPEG: nil,
                    recipes: [],
                    source: .ai)
    }
}
