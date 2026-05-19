import Foundation
import Combine

@MainActor
final class RecipeBatchVM {

    enum BatchState: Equatable {
        case loaded(RecipeBatch)
        case gone
    }

    @Published private(set) var batchState: BatchState

    let store: RecipeStoreProtocol
    let initialBatchId: UUID

    init(batch: RecipeBatch, store: RecipeStoreProtocol) {
        self.batchState = .loaded(batch)
        self.initialBatchId = batch.id
        self.store = store
    }

    var currentBatch: RecipeBatch? {
        if case .loaded(let b) = batchState { return b } else { return nil }
    }
    var recipes: [Recipe] { currentBatch?.recipes ?? [] }

    var headerDateString: String {
        guard let b = currentBatch else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d · h:mm a"
        return fmt.string(from: b.createdAt).uppercased()
    }

    func deleteRecipe(id: UUID) async {
        do {
            try await store.delete(recipeId: id)
            if let refreshed = try await store.batch(id: initialBatchId) {
                batchState = .loaded(refreshed)
            } else {
                batchState = .gone
            }
        } catch {
            // VC shows a generic alert; VM stays in current state
        }
    }
}
