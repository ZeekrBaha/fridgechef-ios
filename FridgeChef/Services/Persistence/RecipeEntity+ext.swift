import CoreData

extension RecipeEntity {
    var asRecipe: Recipe {
        Recipe(
            id: id ?? UUID(),
            title: title ?? "",
            description: recipeDescription ?? "",
            ingredients: decodeJSONArray(ingredientsJSON),
            steps: decodeJSONArray(stepsJSON),
            estimatedTime: estimatedTime ?? "",
            isFavorite: isFavorite,
            updatedAt: updatedAt
        )
    }

    static func create(from recipe: Recipe, order: Int16,
                       in ctx: NSManagedObjectContext) -> RecipeEntity {
        let e = RecipeEntity(context: ctx)
        e.id = recipe.id
        e.title = recipe.title
        e.recipeDescription = recipe.description
        e.ingredientsJSON = encodeJSONArray(recipe.ingredients)
        e.stepsJSON = encodeJSONArray(recipe.steps)
        e.estimatedTime = recipe.estimatedTime
        e.order = order
        e.isFavorite = recipe.isFavorite
        e.updatedAt = recipe.updatedAt
        return e
    }
}

func decodeJSONArray(_ json: String?) -> [String] {
    guard let json, let data = json.data(using: .utf8),
          let arr = try? JSONDecoder().decode([String].self, from: data) else { return [] }
    return arr
}

func encodeJSONArray(_ arr: [String]) -> String {
    guard let data = try? JSONEncoder().encode(arr),
          let s = String(data: data, encoding: .utf8) else { return "[]" }
    return s
}
