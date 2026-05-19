import CoreData

extension RecipeBatchEntity {
    var asBatch: RecipeBatch {
        let orderedRecipes = (recipes?.array as? [RecipeEntity] ?? [])
            .sorted { $0.order < $1.order }
            .map(\.asRecipe)
        let parsedSource = RecipeSource(rawValue: source ?? "ai") ?? .ai
        return RecipeBatch(
            id: id ?? UUID(),
            createdAt: createdAt ?? Date(),
            inputIngredients: decodeJSONArray(inputIngredientsJSON),
            inputImageThumbnailJPEG: inputImageThumbnailJPEG,
            recipes: orderedRecipes,
            source: parsedSource
        )
    }

    static func create(from batch: RecipeBatch,
                       in ctx: NSManagedObjectContext) -> RecipeBatchEntity {
        let e = RecipeBatchEntity(context: ctx)
        e.id = batch.id
        e.createdAt = batch.createdAt
        e.inputIngredientsJSON = encodeJSONArray(batch.inputIngredients)
        e.inputImageThumbnailJPEG = batch.inputImageThumbnailJPEG
        e.source = batch.source.rawValue
        let set = NSMutableOrderedSet()
        for (idx, r) in batch.recipes.enumerated() {
            let re = RecipeEntity.create(from: r, order: Int16(idx), in: ctx)
            re.batch = e
            set.add(re)
        }
        e.recipes = set
        return e
    }
}
