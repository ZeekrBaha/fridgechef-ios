import Foundation
@testable import FridgeChef

final class StubRecipeStore: RecipeStoreProtocol {
    var batches: [RecipeBatch] = []
    var saveError: Error?
    var nextError: Error?

    var updateCalls: [(recipe: Recipe, batchId: UUID)] = []
    var setFavoriteCalls: [(recipeId: UUID, isFavorite: Bool)] = []
    var deleteRecipeCalls: [UUID] = []
    var deleteBatchCalls: [UUID] = []

    func save(_ batch: RecipeBatch) async throws {
        if let saveError { throw saveError }
        batches.insert(batch, at: 0)
    }

    func allBatches() async throws -> [RecipeBatch] { batches }

    func batch(id: UUID) async throws -> RecipeBatch? {
        batches.first { $0.id == id }
    }

    func deleteAll() async throws { batches = [] }

    func update(_ recipe: Recipe, in batchId: UUID) async throws {
        if let nextError { throw nextError }
        updateCalls.append((recipe, batchId))
        guard let bIdx = batches.firstIndex(where: { $0.id == batchId }) else {
            throw RecipeStoreError.notFound
        }
        let b = batches[bIdx]
        guard let rIdx = b.recipes.firstIndex(where: { $0.id == recipe.id }) else {
            throw RecipeStoreError.notFound
        }
        var updated = b.recipes
        updated[rIdx] = Recipe(
            id: recipe.id,
            title: recipe.title,
            description: recipe.description,
            ingredients: recipe.ingredients,
            steps: recipe.steps,
            estimatedTime: recipe.estimatedTime,
            isFavorite: recipe.isFavorite,
            updatedAt: Date()
        )
        batches[bIdx] = RecipeBatch(
            id: b.id, createdAt: b.createdAt,
            inputIngredients: b.inputIngredients,
            inputImageThumbnailJPEG: b.inputImageThumbnailJPEG,
            recipes: updated, source: b.source
        )
    }

    func setFavorite(recipeId: UUID, isFavorite: Bool) async throws {
        if let nextError { throw nextError }
        setFavoriteCalls.append((recipeId, isFavorite))
        for (bIdx, b) in batches.enumerated() {
            if let rIdx = b.recipes.firstIndex(where: { $0.id == recipeId }) {
                var updated = b.recipes
                let r = updated[rIdx]
                updated[rIdx] = Recipe(
                    id: r.id, title: r.title, description: r.description,
                    ingredients: r.ingredients, steps: r.steps,
                    estimatedTime: r.estimatedTime,
                    isFavorite: isFavorite, updatedAt: r.updatedAt
                )
                batches[bIdx] = RecipeBatch(
                    id: b.id, createdAt: b.createdAt,
                    inputIngredients: b.inputIngredients,
                    inputImageThumbnailJPEG: b.inputImageThumbnailJPEG,
                    recipes: updated, source: b.source
                )
                return
            }
        }
        throw RecipeStoreError.notFound
    }

    func delete(recipeId: UUID) async throws {
        if let nextError { throw nextError }
        deleteRecipeCalls.append(recipeId)
        for (bIdx, b) in batches.enumerated() {
            if let rIdx = b.recipes.firstIndex(where: { $0.id == recipeId }) {
                var updated = b.recipes
                updated.remove(at: rIdx)
                if updated.isEmpty {
                    batches.remove(at: bIdx)
                } else {
                    batches[bIdx] = RecipeBatch(
                        id: b.id, createdAt: b.createdAt,
                        inputIngredients: b.inputIngredients,
                        inputImageThumbnailJPEG: b.inputImageThumbnailJPEG,
                        recipes: updated, source: b.source
                    )
                }
                return
            }
        }
        throw RecipeStoreError.notFound
    }

    func delete(batchId: UUID) async throws {
        if let nextError { throw nextError }
        deleteBatchCalls.append(batchId)
        guard let idx = batches.firstIndex(where: { $0.id == batchId }) else {
            throw RecipeStoreError.notFound
        }
        batches.remove(at: idx)
    }
}
