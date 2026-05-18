import Foundation

@MainActor
final class RecipeBatchVM {
    let batch: RecipeBatch
    var recipes: [Recipe] { batch.recipes }

    init(batch: RecipeBatch) { self.batch = batch }

    var headerDateString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d · h:mm a"
        return fmt.string(from: batch.createdAt).uppercased()
    }
}
