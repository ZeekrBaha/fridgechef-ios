import Foundation

struct RecipeBatch: Identifiable, Hashable {
    let id: UUID
    let createdAt: Date
    let inputIngredients: [String]
    let inputImageThumbnailJPEG: Data?
    let recipes: [Recipe]
    let source: RecipeSource
}
