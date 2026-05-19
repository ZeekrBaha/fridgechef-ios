import XCTest
import CoreData
@testable import FridgeChef

final class RecipeStoreTests: XCTestCase {

    private var store: RecipeStore!

    override func setUp() {
        super.setUp()
        store = RecipeStore(stack: CoreDataStack(inMemory: true))
    }

    override func tearDown() {
        store = nil
        super.tearDown()
    }

    func test_save_then_allBatches_returnsBatch() async throws {
        let batch = sampleBatch(ingredients: ["tomato", "basil"], recipeCount: 3)
        try await store.save(batch)
        let all = try await store.allBatches()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all[0].inputIngredients, ["tomato", "basil"])
        XCTAssertEqual(all[0].recipes.count, 3)
        XCTAssertEqual(all[0].recipes.map(\.title), ["R0", "R1", "R2"])
    }

    func test_allBatches_returnsNewestFirst() async throws {
        let older = sampleBatch(ingredients: ["a"], recipeCount: 1, createdAt: Date(timeIntervalSince1970: 1000))
        let newer = sampleBatch(ingredients: ["b"], recipeCount: 1, createdAt: Date(timeIntervalSince1970: 2000))
        try await store.save(older)
        try await store.save(newer)
        let all = try await store.allBatches()
        XCTAssertEqual(all.map(\.inputIngredients), [["b"], ["a"]])
    }

    func test_batch_byId_returnsMatching() async throws {
        let batch = sampleBatch(ingredients: ["x"], recipeCount: 2)
        try await store.save(batch)
        let fetched = try await store.batch(id: batch.id)
        XCTAssertEqual(fetched?.id, batch.id)
        XCTAssertEqual(fetched?.recipes.count, 2)
    }

    func test_batch_byId_unknownReturnsNil() async throws {
        let fetched = try await store.batch(id: UUID())
        XCTAssertNil(fetched)
    }

    func test_deleteAll_removesEverything() async throws {
        try await store.save(sampleBatch(ingredients: ["a"], recipeCount: 1))
        try await store.save(sampleBatch(ingredients: ["b"], recipeCount: 2))
        try await store.deleteAll()
        let all = try await store.allBatches()
        XCTAssertEqual(all, [])
    }

    // MARK: - update

    func test_update_rewritesAllFields_andBumpsUpdatedAt() async throws {
        let batch = sampleBatch(ingredients: ["a"], recipeCount: 1)
        try await store.save(batch)
        let original = batch.recipes[0]
        let edited = Recipe(
            id: original.id,
            title: "New title",
            description: "New desc",
            ingredients: ["new1", "new2"],
            steps: ["s1", "s2", "s3"],
            estimatedTime: "12 min",
            isFavorite: original.isFavorite,
            updatedAt: original.updatedAt
        )
        try await store.update(edited, in: batch.id)

        let reloaded = try await store.batch(id: batch.id)
        let r = reloaded?.recipes.first
        XCTAssertEqual(r?.title, "New title")
        XCTAssertEqual(r?.description, "New desc")
        XCTAssertEqual(r?.ingredients, ["new1", "new2"])
        XCTAssertEqual(r?.steps, ["s1", "s2", "s3"])
        XCTAssertEqual(r?.estimatedTime, "12 min")
        XCTAssertNotNil(r?.updatedAt, "update should set updatedAt to non-nil")
    }

    func test_update_missingRecipe_throwsNotFound() async throws {
        let batch = sampleBatch(ingredients: ["a"], recipeCount: 1)
        try await store.save(batch)
        let bogus = Recipe(id: UUID(), title: "x", description: "",
                           ingredients: [], steps: [], estimatedTime: "",
                           isFavorite: false, updatedAt: nil)
        do {
            try await store.update(bogus, in: batch.id)
            XCTFail("Expected .notFound")
        } catch RecipeStoreError.notFound {
            // ok
        }
    }

    // MARK: - setFavorite

    func test_setFavorite_persistsTheNewValue() async throws {
        let batch = sampleBatch(ingredients: ["a"], recipeCount: 2)
        try await store.save(batch)
        let target = batch.recipes[1]
        try await store.setFavorite(recipeId: target.id, isFavorite: true)

        let reloaded = try await store.batch(id: batch.id)
        XCTAssertEqual(reloaded?.recipes.first(where: { $0.id == target.id })?.isFavorite, true)
        XCTAssertEqual(reloaded?.recipes.first(where: { $0.id == batch.recipes[0].id })?.isFavorite, false)
    }

    // MARK: - delete recipe

    func test_deleteRecipe_removesOnlyThatRecipe() async throws {
        let batch = sampleBatch(ingredients: ["a"], recipeCount: 3)
        try await store.save(batch)
        let middle = batch.recipes[1]

        try await store.delete(recipeId: middle.id)

        let reloaded = try await store.batch(id: batch.id)
        XCTAssertEqual(reloaded?.recipes.count, 2)
        XCTAssertFalse(reloaded?.recipes.contains(where: { $0.id == middle.id }) ?? true)
    }

    func test_deleteRecipe_lastInBatch_cascadesBatch() async throws {
        let batch = sampleBatch(ingredients: ["a"], recipeCount: 1)
        try await store.save(batch)

        try await store.delete(recipeId: batch.recipes[0].id)

        let reloaded = try await store.batch(id: batch.id)
        XCTAssertNil(reloaded, "deleting the last recipe in a batch should cascade-delete the batch")
    }

    // MARK: - delete batch

    func test_deleteBatch_removesBatchAndAllRecipes() async throws {
        let batch = sampleBatch(ingredients: ["a"], recipeCount: 3)
        try await store.save(batch)

        try await store.delete(batchId: batch.id)

        let reloaded = try await store.batch(id: batch.id)
        XCTAssertNil(reloaded)
        let all = try await store.allBatches()
        XCTAssertEqual(all, [])
    }

    private func sampleBatch(ingredients: [String],
                             recipeCount: Int,
                             createdAt: Date = Date(),
                             source: RecipeSource = .ai) -> RecipeBatch {
        RecipeBatch(
            id: UUID(),
            createdAt: createdAt,
            inputIngredients: ingredients,
            inputImageThumbnailJPEG: nil,
            recipes: (0..<recipeCount).map { i in
                Recipe(id: UUID(),
                       title: "R\(i)",
                       description: "d\(i)",
                       ingredients: ["ing\(i)"],
                       steps: ["step\(i)"],
                       estimatedTime: "\(i*5) min",
                       isFavorite: false,
                       updatedAt: nil)
            },
            source: source
        )
    }
}
