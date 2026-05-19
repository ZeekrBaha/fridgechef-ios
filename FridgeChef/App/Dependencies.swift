import Foundation

@MainActor
struct Dependencies {
    let openAIClient: OpenAIClientProtocol
    let recipeStore: RecipeStoreProtocol

    static func makeLive() -> Dependencies {
        let stack = CoreDataStack()
        let store = RecipeStore(stack: stack)
        let apiKey = (try? APIKeyProvider.get()) ?? ""
        let client = OpenAIClient(apiKey: apiKey, session: .shared)
        return Dependencies(openAIClient: client, recipeStore: store)
    }

    static func makeUITestStubs() -> Dependencies {
        let recipes = (0..<3).map { i in
            Recipe(id: UUID(),
                   title: "Stubbed Recipe \(i)",
                   description: "Pre-canned for UI tests.",
                   ingredients: ["chips for UI test"],
                   steps: ["Run the test"],
                   estimatedTime: "5 min")
        }
        return Dependencies(
            openAIClient: UITestStubClient(recipes: recipes),
            recipeStore: UITestStubStore()
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
