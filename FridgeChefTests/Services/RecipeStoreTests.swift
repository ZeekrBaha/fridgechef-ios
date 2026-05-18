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

    private func sampleBatch(ingredients: [String],
                             recipeCount: Int,
                             createdAt: Date = Date()) -> RecipeBatch {
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
                       estimatedTime: "\(i*5) min")
            }
        )
    }
}
