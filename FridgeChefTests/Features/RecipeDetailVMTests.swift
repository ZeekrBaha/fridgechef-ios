import XCTest
import Combine
@testable import FridgeChef

@MainActor
final class RecipeDetailVMTests: XCTestCase {

    func test_passthrough() {
        let r = Recipe(id: UUID(), title: "X", description: "d",
                       ingredients: ["a"], steps: ["s"], estimatedTime: "1 min",
                       isFavorite: false, updatedAt: nil)
        let store = StubRecipeStore()
        let vm = RecipeDetailVM(recipe: r, batchId: UUID(), store: store)
        XCTAssertEqual(vm.recipe.title, "X")
        XCTAssertFalse(vm.isFavorite)
    }

    func test_toggleFavorite_flipsState_andPersists() async {
        let r = Recipe(id: UUID(), title: "X", description: "d",
                       ingredients: ["a"], steps: ["s"], estimatedTime: "1 min",
                       isFavorite: false, updatedAt: nil)
        let store = StubRecipeStore()
        store.batches = [RecipeBatch(id: UUID(), createdAt: Date(),
                                     inputIngredients: [], inputImageThumbnailJPEG: nil,
                                     recipes: [r], source: .ai)]
        let vm = RecipeDetailVM(recipe: r, batchId: store.batches[0].id, store: store)

        await vm.toggleFavorite()
        XCTAssertTrue(vm.isFavorite)
        XCTAssertEqual(store.setFavoriteCalls.count, 1)
        XCTAssertEqual(store.setFavoriteCalls[0].recipeId, r.id)
        XCTAssertEqual(store.setFavoriteCalls[0].isFavorite, true)
    }

    func test_toggleFavorite_storeThrows_revertsAndSetsError() async {
        struct Boom: LocalizedError { var errorDescription: String? { "boom" } }
        let r = Recipe(id: UUID(), title: "X", description: "d",
                       ingredients: ["a"], steps: ["s"], estimatedTime: "1 min",
                       isFavorite: false, updatedAt: nil)
        let store = StubRecipeStore()
        store.nextError = Boom()
        let vm = RecipeDetailVM(recipe: r, batchId: UUID(), store: store)

        await vm.toggleFavorite()

        XCTAssertFalse(vm.isFavorite, "state must revert on error")
        XCTAssertEqual(vm.lastError, "boom")
    }
}
