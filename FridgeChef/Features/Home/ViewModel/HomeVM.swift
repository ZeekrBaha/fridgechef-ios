import Foundation
import Combine
import UIKit

@MainActor
final class HomeVM {

    enum State: Equatable {
        case idle
        case loading
        case loaded(RecipeBatch)
        case error(String)
    }

    @Published private(set) var chips: [String] = []
    @Published private(set) var state: State = .idle

    private let client: OpenAIClientProtocol
    private let store: RecipeStoreProtocol
    private var task: Task<Void, Never>?

    init(client: OpenAIClientProtocol, store: RecipeStoreProtocol) {
        self.client = client
        self.store = store
    }

    deinit { task?.cancel() }

    // MARK: - chip mutations

    func addChip(_ raw: String) {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleaned.isEmpty else { return }
        guard !chips.contains(cleaned) else { return }
        chips.append(cleaned)
    }

    func removeChip(_ name: String) {
        chips.removeAll { $0 == name }
    }

    var canGenerate: Bool { !chips.isEmpty }

    // MARK: - generation

    func generate() {
        guard canGenerate else { return }
        let ingredients = chips
        task?.cancel()
        state = .loading
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let recipes = try await client.suggestRecipes(ingredients: ingredients)
                let batch = RecipeBatch(
                    id: UUID(),
                    createdAt: Date(),
                    inputIngredients: ingredients,
                    inputImageThumbnailJPEG: nil,
                    recipes: recipes)
                try await store.save(batch)
                if Task.isCancelled { return }
                self.state = .loaded(batch)
            } catch {
                if Task.isCancelled { return }
                self.state = .error(error.localizedDescription)
            }
        }
    }

    func generate(image: UIImage) {
        guard let jpeg = Self.resizeAndJPEG(image, maxLongestSide: 1024, quality: 0.7) else {
            state = .error("Could not read photo.")
            return
        }
        task?.cancel()
        state = .loading
        let ingredientsAtStart = chips
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let recipes = try await client.suggestRecipes(imageJPEG: jpeg)
                let batch = RecipeBatch(
                    id: UUID(),
                    createdAt: Date(),
                    inputIngredients: ingredientsAtStart,
                    inputImageThumbnailJPEG: jpeg,
                    recipes: recipes)
                try await store.save(batch)
                if Task.isCancelled { return }
                self.state = .loaded(batch)
            } catch {
                if Task.isCancelled { return }
                self.state = .error(error.localizedDescription)
            }
        }
    }

    private static func resizeAndJPEG(_ image: UIImage,
                                      maxLongestSide: CGFloat,
                                      quality: CGFloat) -> Data? {
        let size = image.size
        let longest = max(size.width, size.height)
        let scale: CGFloat = longest > maxLongestSide ? maxLongestSide / longest : 1
        let target = CGSize(width: floor(size.width * scale), height: floor(size.height * scale))
        let renderer = UIGraphicsImageRenderer(size: target)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: target)) }
        return resized.jpegData(compressionQuality: quality)
    }
}
