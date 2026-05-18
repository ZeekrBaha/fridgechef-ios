import CoreData

@objc(RecipeBatchEntity)
final class RecipeBatchEntity: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var createdAt: Date?
    @NSManaged var inputIngredientsJSON: String?
    @NSManaged var inputImageThumbnailJPEG: Data?
    @NSManaged var recipes: NSOrderedSet?

    @nonobjc class func fetchRequest() -> NSFetchRequest<RecipeBatchEntity> {
        NSFetchRequest<RecipeBatchEntity>(entityName: "RecipeBatchEntity")
    }
}

@objc(RecipeEntity)
final class RecipeEntity: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var title: String?
    @NSManaged var recipeDescription: String?
    @NSManaged var ingredientsJSON: String?
    @NSManaged var stepsJSON: String?
    @NSManaged var estimatedTime: String?
    @NSManaged var order: Int16
    @NSManaged var batch: RecipeBatchEntity?

    @nonobjc class func fetchRequest() -> NSFetchRequest<RecipeEntity> {
        NSFetchRequest<RecipeEntity>(entityName: "RecipeEntity")
    }
}
