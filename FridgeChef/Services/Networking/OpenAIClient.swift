import Foundation

protocol OpenAIClientProtocol {
    func suggestRecipes(ingredients: [String]) async throws -> [Recipe]
    func suggestRecipes(imageJPEG: Data) async throws -> [Recipe]
}

struct OpenAIClient: OpenAIClientProtocol {
    let apiKey: String
    let session: URLSession
    let model = "gpt-4o"
    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    func suggestRecipes(ingredients: [String]) async throws -> [Recipe] {
        let user = "Ingredients I have:\n" + ingredients.joined(separator: "\n")
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": Prompts.systemPrompt],
                ["role": "user", "content": user]
            ],
            "response_format": Self.responseFormat
        ]
        return try await send(body: body)
    }

    func suggestRecipes(imageJPEG: Data) async throws -> [Recipe] {
        let dataURL = "data:image/jpeg;base64,\(imageJPEG.base64EncodedString())"
        let userContent: [[String: Any]] = [
            ["type": "text", "text": "These are ingredients I have. Suggest recipes."],
            ["type": "image_url", "image_url": ["url": dataURL]]
        ]
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": Prompts.visionSystemPrompt],
                ["role": "user", "content": userContent]
            ],
            "response_format": Self.responseFormat
        ]
        return try await send(body: body)
    }

    private func send(body: [String: Any]) async throws -> [Recipe] {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: req)
        } catch let urlErr as URLError {
            throw OpenAIError.network(urlErr.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else { throw OpenAIError.invalidResponse }

        switch http.statusCode {
        case 200..<300: break
        case 401:       throw OpenAIError.unauthorized
        case 429:       throw OpenAIError.rateLimited
        case 500..<600: throw OpenAIError.server(http.statusCode)
        default:        throw OpenAIError.server(http.statusCode)
        }

        struct Envelope: Decodable {
            struct Choice: Decodable { let message: Message }
            struct Message: Decodable { let content: String }
            let choices: [Choice]
        }
        struct RecipesResponse: Decodable { let recipes: [APIRecipe] }
        struct APIRecipe: Decodable {
            let title: String
            let description: String
            let ingredients: [String]
            let steps: [String]
            let estimatedTime: String
        }

        let envelope: Envelope
        do {
            envelope = try JSONDecoder().decode(Envelope.self, from: data)
        } catch {
            throw OpenAIError.invalidResponse
        }

        guard let contentString = envelope.choices.first?.message.content,
              let contentData = contentString.data(using: .utf8) else {
            throw OpenAIError.invalidResponse
        }

        let parsed: RecipesResponse
        do {
            parsed = try JSONDecoder().decode(RecipesResponse.self, from: contentData)
        } catch {
            throw OpenAIError.decoding(String(describing: error))
        }

        if parsed.recipes.isEmpty { throw OpenAIError.noRecipesReturned }

        return parsed.recipes.map {
            Recipe(id: UUID(),
                   title: $0.title,
                   description: $0.description,
                   ingredients: $0.ingredients,
                   steps: $0.steps,
                   estimatedTime: $0.estimatedTime)
        }
    }

    private static let responseFormat: [String: Any] = [
        "type": "json_schema",
        "json_schema": [
            "name": "recipes_response",
            "strict": true,
            "schema": [
                "type": "object",
                "additionalProperties": false,
                "required": ["recipes"],
                "properties": [
                    "recipes": [
                        "type": "array",
                        "minItems": 3,
                        "maxItems": 3,
                        "items": [
                            "type": "object",
                            "additionalProperties": false,
                            "required": ["title", "description", "ingredients", "steps", "estimatedTime"],
                            "properties": [
                                "title": ["type": "string"],
                                "description": ["type": "string"],
                                "ingredients": ["type": "array", "items": ["type": "string"]],
                                "steps": ["type": "array", "items": ["type": "string"]],
                                "estimatedTime": ["type": "string"]
                            ]
                        ]
                    ]
                ]
            ]
        ]
    ]
}
