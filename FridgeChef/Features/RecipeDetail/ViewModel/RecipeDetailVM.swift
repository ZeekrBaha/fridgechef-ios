import Foundation

@MainActor
final class RecipeDetailVM {
    let recipe: Recipe
    init(recipe: Recipe) { self.recipe = recipe }
}
