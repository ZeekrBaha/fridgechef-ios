import XCTest
@testable import FridgeChef

@MainActor
final class RecipeBatchVMTests: XCTestCase {
    func test_init_populatesBatchAndRecipes() {
        let recipes = (0..<3).map { i in
            Recipe(id: UUID(), title: "T\(i)", description: "d",
                   ingredients: [], steps: [], estimatedTime: "5 min",
                   isFavorite: false, updatedAt: nil)
        }
        let batch = RecipeBatch(id: UUID(), createdAt: Date(),
                                inputIngredients: ["tomato"],
                                inputImageThumbnailJPEG: nil,
                                recipes: recipes,
                                source: .ai)
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
                                recipes: [],
                                source: .ai)
        let store = StubRecipeStore()
        let vm = RecipeBatchVM(batch: batch, store: store)
        XCTAssertTrue(vm.headerDateString.uppercased().contains("MAY"))
    }
}
