import Foundation

@MainActor
final class RecipeBatchVM {
    let batch: RecipeBatch
    var recipes: [Recipe] { batch.recipes }

    let store: RecipeStoreProtocol?

    init(batch: RecipeBatch, store: RecipeStoreProtocol? = nil) {
        self.batch = batch
        self.store = store
    }

    var headerDateString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d · h:mm a"
        return fmt.string(from: batch.createdAt).uppercased()
    }
}
