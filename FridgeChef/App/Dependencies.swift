import Foundation
import Combine

@MainActor
struct Dependencies {
    let openAIClient: OpenAIClientProtocol
    let recipeStore: RecipeStoreProtocol
    let dailyPicksService: DailyPicksService

    static func makeLive() -> Dependencies {
        let stack = CoreDataStack()
        let store = RecipeStore(stack: stack)
        let apiKey = (try? APIKeyProvider.get()) ?? ""
        let client = OpenAIClient(apiKey: apiKey, session: .shared)
        let picks = LiveDailyPicksService(client: client)
        return Dependencies(
            openAIClient: client,
            recipeStore: store,
            dailyPicksService: picks
        )
    }

    static func makeUITestStubs() -> Dependencies {
        let recipes = (0..<3).map { i in
            Recipe(id: UUID(),
                   title: "Stubbed Recipe \(i)",
                   description: "Pre-canned for UI tests.",
                   ingredients: ["chips for UI test"],
                   steps: ["Run the test"],
                   estimatedTime: "5 min",
                   isFavorite: false,
                   updatedAt: nil)
        }
        let stubClient = UITestStubClient(recipes: recipes)
        let stubPicks = UITestStubDailyPicksService()
        return Dependencies(
            openAIClient: stubClient,
            recipeStore: UITestStubStore(),
            dailyPicksService: stubPicks
        )
    }
}

private final class UITestStubClient: OpenAIClientProtocol {
    let recipes: [Recipe]
    init(recipes: [Recipe]) { self.recipes = recipes }
    func suggestRecipes(ingredients: [String]) async throws -> [Recipe] { recipes }
    func suggestRecipes(imageJPEG: Data) async throws -> [Recipe] { recipes }
    func suggestRecipes(dishName: String) async throws -> [Recipe] { recipes }
    func suggestRecipes(forMeal meal: MealType, style: RecipeStyle?) async throws -> [Recipe] { recipes }
    func dailyPicks() async throws -> DailyPicks {
        DailyPicks(
            breakfast: "Stubbed Toast",
            lunch: "Stubbed Salad",
            dinner: "Stubbed Curry",
            savedAt: Date()
        )
    }
}

@MainActor
private final class UITestStubStore: RecipeStoreProtocol {
    private var batches: [RecipeBatch] = []

    func save(_ batch: RecipeBatch) async throws {
        batches.insert(batch, at: 0)
        postChanged()
    }
    func allBatches() async throws -> [RecipeBatch] { batches }
    func batch(id: UUID) async throws -> RecipeBatch? { batches.first { $0.id == id } }
    func deleteAll() async throws { batches = []; postChanged() }

    func update(_ recipe: Recipe, in batchId: UUID) async throws {
        guard let bi = batches.firstIndex(where: { $0.id == batchId }),
              let ri = batches[bi].recipes.firstIndex(where: { $0.id == recipe.id }) else {
            throw RecipeStoreError.notFound
        }
        var recipes = batches[bi].recipes
        recipes[ri] = recipe
        let old = batches[bi]
        batches[bi] = RecipeBatch(id: old.id, createdAt: old.createdAt,
                                  inputIngredients: old.inputIngredients,
                                  inputImageThumbnailJPEG: old.inputImageThumbnailJPEG,
                                  recipes: recipes, source: old.source)
        postChanged()
    }

    func setFavorite(recipeId: UUID, isFavorite: Bool) async throws {
        for (bi, batch) in batches.enumerated() {
            guard let ri = batch.recipes.firstIndex(where: { $0.id == recipeId }) else { continue }
            var recipes = batch.recipes
            let old = recipes[ri]
            recipes[ri] = Recipe(id: old.id, title: old.title, description: old.description,
                                 ingredients: old.ingredients, steps: old.steps,
                                 estimatedTime: old.estimatedTime, isFavorite: isFavorite,
                                 updatedAt: old.updatedAt)
            batches[bi] = RecipeBatch(id: batch.id, createdAt: batch.createdAt,
                                      inputIngredients: batch.inputIngredients,
                                      inputImageThumbnailJPEG: batch.inputImageThumbnailJPEG,
                                      recipes: recipes, source: batch.source)
            postChanged()
            return
        }
        throw RecipeStoreError.notFound
    }

    func delete(recipeId: UUID) async throws {
        for (bi, batch) in batches.enumerated() {
            guard let ri = batch.recipes.firstIndex(where: { $0.id == recipeId }) else { continue }
            var recipes = batch.recipes
            recipes.remove(at: ri)
            if recipes.isEmpty {
                batches.remove(at: bi)
            } else {
                let old = batch
                batches[bi] = RecipeBatch(id: old.id, createdAt: old.createdAt,
                                          inputIngredients: old.inputIngredients,
                                          inputImageThumbnailJPEG: old.inputImageThumbnailJPEG,
                                          recipes: recipes, source: old.source)
            }
            postChanged()
            return
        }
        throw RecipeStoreError.notFound
    }

    func delete(batchId: UUID) async throws {
        guard let idx = batches.firstIndex(where: { $0.id == batchId }) else {
            throw RecipeStoreError.notFound
        }
        batches.remove(at: idx)
        postChanged()
    }

    private func postChanged() {
        NotificationCenter.default.post(name: .recipesDidChange, object: nil)
    }
}

@MainActor
private final class UITestStubDailyPicksService: DailyPicksService {
    var current: DailyPicks? = DailyPicks(
        breakfast: "Stub Pick",
        lunch: "Stub Pick",
        dinner: "Stub Pick",
        savedAt: Date()
    )
    var publisher: AnyPublisher<DailyPicks?, Never> {
        Just(current).eraseToAnyPublisher()
    }
    func refreshIfStale() async { /* no-op */ }
}
