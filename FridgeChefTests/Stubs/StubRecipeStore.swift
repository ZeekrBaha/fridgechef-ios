import Foundation
@testable import FridgeChef

final class StubRecipeStore: RecipeStoreProtocol {
    var batches: [RecipeBatch] = []
    var saveError: Error?

    func save(_ batch: RecipeBatch) async throws {
        if let saveError { throw saveError }
        batches.insert(batch, at: 0)
    }

    func allBatches() async throws -> [RecipeBatch] { batches }

    func batch(id: UUID) async throws -> RecipeBatch? {
        batches.first { $0.id == id }
    }

    func deleteAll() async throws { batches = [] }
}
