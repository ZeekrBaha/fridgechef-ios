import Foundation
@testable import FridgeChef

final class StubOpenAIClient: OpenAIClientProtocol {
    // Text & image (existing)
    var textResult: Result<[Recipe], Error> = .success([])
    var imageResult: Result<[Recipe], Error> = .success([])
    private(set) var lastIngredients: [String]?
    private(set) var lastImageJPEG: Data?

    // Dish-name variant (new in Phase 3)
    var dishResult: Result<[Recipe], Error> = .success([])
    private(set) var lastDishName: String?

    // Meal variant (new in Phase 3)
    var mealResult: Result<[Recipe], Error> = .success([])
    private(set) var lastMeal: MealType?
    private(set) var lastStyle: RecipeStyle?

    // Daily picks (new in Phase 2)
    var dailyPicksResult: Result<DailyPicks, Error> = .success(
        DailyPicks(breakfast: nil, lunch: nil, dinner: nil, savedAt: Date())
    )
    private(set) var dailyPicksCallCount: Int = 0

    func suggestRecipes(ingredients: [String]) async throws -> [Recipe] {
        lastIngredients = ingredients
        return try textResult.get()
    }

    func suggestRecipes(imageJPEG: Data) async throws -> [Recipe] {
        lastImageJPEG = imageJPEG
        return try imageResult.get()
    }

    func suggestRecipes(dishName: String) async throws -> [Recipe] {
        lastDishName = dishName
        return try dishResult.get()
    }

    func suggestRecipes(forMeal meal: MealType, style: RecipeStyle?) async throws -> [Recipe] {
        lastMeal = meal
        lastStyle = style
        return try mealResult.get()
    }

    func dailyPicks() async throws -> DailyPicks {
        dailyPicksCallCount += 1
        return try dailyPicksResult.get()
    }
}
