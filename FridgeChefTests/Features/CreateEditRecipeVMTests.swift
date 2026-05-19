import XCTest
import Combine
@testable import FridgeChef

@MainActor
final class CreateEditRecipeVMTests: XCTestCase {

    private var store: StubRecipeStore!

    override func setUp() {
        super.setUp()
        store = StubRecipeStore()
    }

    func test_init_newMode_hasEmptyFields_andIsInvalid() {
        let vm = CreateEditRecipeVM(mode: .new, store: store)
        XCTAssertEqual(vm.title, "")
        XCTAssertEqual(vm.descriptionText, "")
        XCTAssertEqual(vm.ingredients, [""])
        XCTAssertEqual(vm.steps, [""])
        XCTAssertEqual(vm.estimatedTime, "")
        XCTAssertFalse(vm.isValid)
    }

    func test_init_editMode_prefillsFromRecipe_andIsValid() {
        let r = Recipe(id: UUID(), title: "Existing",
                       description: "d",
                       ingredients: ["a", "b"], steps: ["s1"],
                       estimatedTime: "10 min",
                       isFavorite: false, updatedAt: nil)
        let vm = CreateEditRecipeVM(mode: .edit(existing: r, batchId: UUID()), store: store)
        XCTAssertEqual(vm.title, "Existing")
        XCTAssertEqual(vm.descriptionText, "d")
        XCTAssertEqual(vm.ingredients, ["a", "b"])
        XCTAssertEqual(vm.steps, ["s1"])
        XCTAssertEqual(vm.estimatedTime, "10 min")
        XCTAssertTrue(vm.isValid)
    }

    func test_validation_requiresTitle_oneIngredient_oneStep() async {
        let vm = CreateEditRecipeVM(mode: .new, store: store)
        XCTAssertFalse(vm.isValid)

        vm.title = "Pancakes"
        await Task.yield()
        XCTAssertFalse(vm.isValid, "title alone is not enough")

        vm.ingredients = ["flour"]
        await Task.yield()
        XCTAssertFalse(vm.isValid, "title + ingredient still missing a step")

        vm.steps = ["mix and cook"]
        await Task.yield()
        XCTAssertTrue(vm.isValid, "title + ingredient + step is the minimum")

        vm.title = "   "
        await Task.yield()
        XCTAssertFalse(vm.isValid, "whitespace-only title should invalidate")
    }

    func test_save_newMode_callsSave_withSourceUser_oneRecipe_andStripsEmpty() async {
        let vm = CreateEditRecipeVM(mode: .new, store: store)
        vm.title = "Pancakes"
        vm.descriptionText = "Fluffy"
        vm.ingredients = ["flour", "", "milk"]
        vm.steps = ["mix", ""]
        vm.estimatedTime = "20 min"

        await vm.save()

        XCTAssertEqual(store.batches.count, 1)
        let b = store.batches[0]
        XCTAssertEqual(b.source, .user)
        XCTAssertEqual(b.recipes.count, 1)
        let r = b.recipes[0]
        XCTAssertEqual(r.title, "Pancakes")
        XCTAssertEqual(r.ingredients, ["flour", "milk"])
        XCTAssertEqual(r.steps, ["mix"])
    }

    func test_save_editMode_callsUpdate_withEditedFields() async {
        let existing = Recipe(id: UUID(), title: "Old",
                              description: "od",
                              ingredients: ["x"], steps: ["y"],
                              estimatedTime: "5 min",
                              isFavorite: true, updatedAt: nil)
        let batchId = UUID()
        store.batches = [RecipeBatch(id: batchId, createdAt: Date(),
                                     inputIngredients: [], inputImageThumbnailJPEG: nil,
                                     recipes: [existing], source: .user)]

        let vm = CreateEditRecipeVM(mode: .edit(existing: existing, batchId: batchId), store: store)
        vm.title = "Updated"

        await vm.save()

        XCTAssertEqual(store.updateCalls.count, 1)
        XCTAssertEqual(store.updateCalls[0].recipe.title, "Updated")
        XCTAssertEqual(store.updateCalls[0].batchId, batchId)
    }

    func test_save_storeThrows_setsErrorState_andLeavesFieldsIntact() async {
        struct Boom: LocalizedError { var errorDescription: String? { "boom" } }
        store.saveError = Boom()
        let vm = CreateEditRecipeVM(mode: .new, store: store)
        vm.title = "X"
        vm.ingredients = ["a"]
        vm.steps = ["s"]

        await vm.save()

        if case .error(let msg) = vm.saveState {
            XCTAssertEqual(msg, "boom")
        } else {
            XCTFail("expected .error, got \(vm.saveState)")
        }
        XCTAssertEqual(vm.title, "X", "fields must remain after a failed save")
        XCTAssertEqual(vm.ingredients, ["a"])
        XCTAssertEqual(vm.steps, ["s"])
    }
}
