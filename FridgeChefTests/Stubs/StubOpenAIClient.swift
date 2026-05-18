import Foundation
@testable import FridgeChef

final class StubOpenAIClient: OpenAIClientProtocol {
    var textResult: Result<[Recipe], Error> = .success([])
    var imageResult: Result<[Recipe], Error> = .success([])
    private(set) var lastIngredients: [String]?
    private(set) var lastImageJPEG: Data?

    func suggestRecipes(ingredients: [String]) async throws -> [Recipe] {
        lastIngredients = ingredients
        return try textResult.get()
    }

    func suggestRecipes(imageJPEG: Data) async throws -> [Recipe] {
        lastImageJPEG = imageJPEG
        return try imageResult.get()
    }
}
