import XCTest
@testable import FridgeChef

@MainActor
final class RecipeDetailVMTests: XCTestCase {
    func test_passthrough() {
        let r = Recipe(id: UUID(), title: "X", description: "d", ingredients: ["a"], steps: ["s"], estimatedTime: "1 min")
        let vm = RecipeDetailVM(recipe: r)
        XCTAssertEqual(vm.recipe.title, "X")
    }
}
