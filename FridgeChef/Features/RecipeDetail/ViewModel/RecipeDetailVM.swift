import Foundation

@MainActor
final class RecipeDetailVM {
    let recipe: Recipe
    init(recipe: Recipe, batchId: UUID? = nil, store: RecipeStoreProtocol? = nil) { self.recipe = recipe }
}
