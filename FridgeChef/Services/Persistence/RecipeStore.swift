import CoreData

protocol RecipeStoreProtocol {
    func save(_ batch: RecipeBatch) async throws
    func allBatches() async throws -> [RecipeBatch]
    func batch(id: UUID) async throws -> RecipeBatch?
    func deleteAll() async throws
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
        // NSBatchDeleteRequest doesn't support NSInMemoryStoreType, so iterate.
        // Dataset is tiny (max a few hundred batches in practice).
        let ctx = stack.newBackgroundContext()
        try await ctx.perform {
            let req: NSFetchRequest<RecipeBatchEntity> = RecipeBatchEntity.fetchRequest()
            let all = try ctx.fetch(req)
            for entity in all { ctx.delete(entity) }
            try ctx.save()
        }
    }
}
