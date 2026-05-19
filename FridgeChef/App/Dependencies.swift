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

private final class UITestStubStore: RecipeStoreProtocol {
    private var batches: [RecipeBatch] = []
    func save(_ batch: RecipeBatch) async throws { batches.insert(batch, at: 0) }
    func allBatches() async throws -> [RecipeBatch] { batches }
    func batch(id: UUID) async throws -> RecipeBatch? { batches.first { $0.id == id } }
    func deleteAll() async throws { batches = [] }
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
