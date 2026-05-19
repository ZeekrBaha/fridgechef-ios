import XCTest
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
    }
}
