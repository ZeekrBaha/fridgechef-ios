import XCTest
@testable import FridgeChef

@MainActor
final class RecipeBatchVMTests: XCTestCase {

    private func makeRecipes(_ n: Int) -> [Recipe] {
        (0..<n).map { i in
            Recipe(id: UUID(), title: "T\(i)", description: "d",
                   ingredients: [], steps: [], estimatedTime: "5 min",
                   isFavorite: false, updatedAt: nil)
        }
    }

    func test_init_populatesBatchAndRecipes() {
        let recipes = makeRecipes(3)
        let batch = RecipeBatch(id: UUID(), createdAt: Date(),
                                inputIngredients: ["tomato"],
                                inputImageThumbnailJPEG: nil,
                                recipes: recipes, source: .ai)
        let store = StubRecipeStore()
        let vm = RecipeBatchVM(batch: batch, store: store)
        XCTAssertEqual(vm.recipes.count, 3)
        XCTAssertEqual(vm.recipes[0].title, "T0")
        XCTAssertFalse(vm.headerDateString.isEmpty)
    }

    func test_headerDate_formatsCreatedAt() {
        let d = Date(timeIntervalSince1970: 1747584840)
        let batch = RecipeBatch(id: UUID(), createdAt: d,
                                inputIngredients: [],
                                inputImageThumbnailJPEG: nil,
                                recipes: [], source: .ai)
        let store = StubRecipeStore()
        let vm = RecipeBatchVM(batch: batch, store: store)
        XCTAssertTrue(vm.headerDateString.uppercased().contains("MAY"))
    }

    func test_deleteRecipe_partial_keepsBatchLoadedWithRemainingRecipes() async {
        let recipes = makeRecipes(3)
        let batch = RecipeBatch(id: UUID(), createdAt: Date(),
                                inputIngredients: [],
                                inputImageThumbnailJPEG: nil,
                                recipes: recipes, source: .ai)
        let store = StubRecipeStore()
        store.batches = [batch]
        let vm = RecipeBatchVM(batch: batch, store: store)

        await vm.deleteRecipe(id: recipes[1].id)

        XCTAssertEqual(store.deleteRecipeCalls, [recipes[1].id])
        XCTAssertEqual(vm.recipes.count, 2)
        if case .gone = vm.batchState { XCTFail("Should still be loaded") }
    }

    func test_deleteRecipe_last_transitionsToGone() async {
        let recipes = makeRecipes(1)
        let batch = RecipeBatch(id: UUID(), createdAt: Date(),
                                inputIngredients: [],
                                inputImageThumbnailJPEG: nil,
                                recipes: recipes, source: .user)
        let store = StubRecipeStore()
        store.batches = [batch]
        let vm = RecipeBatchVM(batch: batch, store: store)

        await vm.deleteRecipe(id: recipes[0].id)

        if case .gone = vm.batchState {} else {
            XCTFail("Expected .gone after deleting the last recipe; got \(vm.batchState)")
        }
    }
}
