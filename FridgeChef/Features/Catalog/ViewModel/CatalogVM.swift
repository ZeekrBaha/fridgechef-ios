import Foundation
import Combine
import UIKit

@MainActor
final class CatalogVM {

    enum State: Equatable {
        case idle
        case loading
        case loaded(RecipeBatch)
        case error(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var dailyPicks: DailyPicks?
    @Published private(set) var presentPhotoPicker: Bool = false

    private let client: OpenAIClientProtocol
    private let store: RecipeStoreProtocol
    private let dailyPicksService: DailyPicksService
    private var task: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init(client: OpenAIClientProtocol,
         store: RecipeStoreProtocol,
         dailyPicks: DailyPicksService) {
        self.client = client
        self.store = store
        self.dailyPicksService = dailyPicks
        self.dailyPicks = dailyPicks.current
        dailyPicks.publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.dailyPicks = $0 }
            .store(in: &cancellables)
    }

    deinit { task?.cancel() }

    // MARK: - generation paths

    func generateForDish(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        run { [client] in try await client.suggestRecipes(dishName: trimmed) }
    }

    func generateForMeal(_ meal: MealType) {
        run { [client] in try await client.suggestRecipes(forMeal: meal, style: nil) }
    }

    func generateRandom() {
        let meal = MealType.allCases.randomElement() ?? .dinner
        let style = RecipeStyle.allCases.randomElement()
        run { [client] in try await client.suggestRecipes(forMeal: meal, style: style) }
    }

    func generateFromImage(_ jpegData: Data) {
        run { [client] in try await client.suggestRecipes(imageJPEG: jpegData) }
    }

    // MARK: - photo picker bridge

    func openPhotoPicker() { presentPhotoPicker = true }
    func didDismissPhotoPicker() { presentPhotoPicker = false }

    // MARK: - daily picks

    func refreshDailyPicksIfStale() {
        Task { [dailyPicksService] in
            await dailyPicksService.refreshIfStale()
        }
    }

    // MARK: - shared run/save/transition

    private func run(_ fetch: @escaping () async throws -> [Recipe]) {
        task?.cancel()
        state = .loading
        task = Task { [weak self, store] in
            guard let self else { return }
            do {
                let recipes = try await fetch()
                let batch = RecipeBatch(
                    id: UUID(),
                    createdAt: Date(),
                    inputIngredients: [],
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
}
