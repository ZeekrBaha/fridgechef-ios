import Foundation
import Combine

@MainActor
final class RecipeDetailVM {

    @Published private(set) var recipe: Recipe
    @Published private(set) var isFavorite: Bool
    @Published private(set) var lastError: String?

    let batchId: UUID
    private let store: RecipeStoreProtocol
    private var notificationToken: NSObjectProtocol?

    init(recipe: Recipe, batchId: UUID, store: RecipeStoreProtocol) {
        self.recipe = recipe
        self.isFavorite = recipe.isFavorite
        self.batchId = batchId
        self.store = store
        notificationToken = NotificationCenter.default.addObserver(
            forName: .recipesDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            Task { await self?.reload() }
        }
    }

    deinit {
        if let t = notificationToken { NotificationCenter.default.removeObserver(t) }
    }

    func toggleFavorite() async {
        let newValue = !isFavorite
        isFavorite = newValue
        do {
            try await store.setFavorite(recipeId: recipe.id, isFavorite: newValue)
        } catch {
            isFavorite = !newValue
            lastError = error.localizedDescription
        }
    }

    func clearError() { lastError = nil }

    func makeStoreReference() -> RecipeStoreProtocol { store }

    private func reload() async {
        guard let batch = try? await store.batch(id: batchId),
              let updated = batch.recipes.first(where: { $0.id == recipe.id }) else { return }
        recipe = updated
        isFavorite = updated.isFavorite
    }
}
