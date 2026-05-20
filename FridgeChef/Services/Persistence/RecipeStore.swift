import CoreData
import Foundation

enum RecipeStoreError: Error, LocalizedError {
    case notFound

    var errorDescription: String? {
        switch self {
        case .notFound: return "Recipe or batch not found."
        }
    }
}

protocol RecipeStoreProtocol {
    func save(_ batch: RecipeBatch) async throws
    func allBatches() async throws -> [RecipeBatch]
    func batch(id: UUID) async throws -> RecipeBatch?
    func deleteAll() async throws

    func update(_ recipe: Recipe, in batchId: UUID) async throws
    func setFavorite(recipeId: UUID, isFavorite: Bool) async throws
    func delete(recipeId: UUID) async throws
    func delete(batchId: UUID) async throws
}

final class RecipeStore: RecipeStoreProtocol {
    private let stack: CoreDataStack

    init(stack: CoreDataStack) {
        self.stack = stack
    }

    func save(_ batch: RecipeBatch) async throws {
        let ctx = stack.newBackgroundContext()
        try await ctx.perform {
            _ = RecipeBatchEntity.create(from: batch, in: ctx)
            try ctx.save()
        }
        postChanged()
    }

    func allBatches() async throws -> [RecipeBatch] {
        let ctx = stack.newBackgroundContext()
        return try await ctx.perform {
            let req: NSFetchRequest<RecipeBatchEntity> = RecipeBatchEntity.fetchRequest()
            req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            let entities = try ctx.fetch(req)
            return entities.map(\.asBatch)
        }
    }

    func batch(id: UUID) async throws -> RecipeBatch? {
        let ctx = stack.newBackgroundContext()
        return try await ctx.perform {
            let req: NSFetchRequest<RecipeBatchEntity> = RecipeBatchEntity.fetchRequest()
            req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            req.fetchLimit = 1
            return try ctx.fetch(req).first?.asBatch
        }
    }

    func deleteAll() async throws {
        let ctx = stack.newBackgroundContext()
        try await ctx.perform {
            let req: NSFetchRequest<RecipeBatchEntity> = RecipeBatchEntity.fetchRequest()
            let all = try ctx.fetch(req)
            for entity in all { ctx.delete(entity) }
            try ctx.save()
        }
        postChanged()
    }

    func update(_ recipe: Recipe, in batchId: UUID) async throws {
        let ctx = stack.newBackgroundContext()
        try await ctx.perform {
            let req: NSFetchRequest<RecipeEntity> = RecipeEntity.fetchRequest()
            req.predicate = NSPredicate(format: "id == %@", recipe.id as CVarArg)
            req.fetchLimit = 1
            guard let entity = try ctx.fetch(req).first,
                  entity.batch?.id == batchId else {
                throw RecipeStoreError.notFound
            }
            entity.title = recipe.title
            entity.recipeDescription = recipe.description
            entity.ingredientsJSON = encodeJSONArray(recipe.ingredients)
            entity.stepsJSON = encodeJSONArray(recipe.steps)
            entity.estimatedTime = recipe.estimatedTime
            entity.updatedAt = Date()
            try ctx.save()
        }
        postChanged()
    }

    func setFavorite(recipeId: UUID, isFavorite: Bool) async throws {
        let ctx = stack.newBackgroundContext()
        try await ctx.perform {
            let req: NSFetchRequest<RecipeEntity> = RecipeEntity.fetchRequest()
            req.predicate = NSPredicate(format: "id == %@", recipeId as CVarArg)
            req.fetchLimit = 1
            guard let entity = try ctx.fetch(req).first else {
                throw RecipeStoreError.notFound
            }
            entity.isFavorite = isFavorite
            try ctx.save()
        }
        postChanged()
    }

    func delete(recipeId: UUID) async throws {
        let ctx = stack.newBackgroundContext()
        try await ctx.perform {
            let req: NSFetchRequest<RecipeEntity> = RecipeEntity.fetchRequest()
            req.predicate = NSPredicate(format: "id == %@", recipeId as CVarArg)
            req.fetchLimit = 1
            guard let entity = try ctx.fetch(req).first else {
                throw RecipeStoreError.notFound
            }
            let parent = entity.batch
            ctx.delete(entity)
            if let parent {
                let remaining = (parent.recipes?.count ?? 0) - 1
                if remaining <= 0 {
                    ctx.delete(parent)
                }
            }
            try ctx.save()
        }
        postChanged()
    }

    func delete(batchId: UUID) async throws {
        let ctx = stack.newBackgroundContext()
        try await ctx.perform {
            let req: NSFetchRequest<RecipeBatchEntity> = RecipeBatchEntity.fetchRequest()
            req.predicate = NSPredicate(format: "id == %@", batchId as CVarArg)
            req.fetchLimit = 1
            guard let entity = try ctx.fetch(req).first else {
                throw RecipeStoreError.notFound
            }
            ctx.delete(entity)
            try ctx.save()
        }
        postChanged()
    }

    private func postChanged() {
        NotificationCenter.default.post(name: .recipesDidChange, object: nil)
    }
}
