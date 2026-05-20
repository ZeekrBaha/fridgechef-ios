import Foundation

enum OpenAIError: Error, LocalizedError, Equatable {
    case missingAPIKey
    case unauthorized
    case rateLimited
    case server(Int)
    case invalidResponse
    case decoding(String)
    case network(String)
    case noRecipesReturned

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:      return "OpenAI key not found in Info.plist. Re-build from Xcode."
        case .unauthorized:       return "API key invalid. Check Settings."
        case .rateLimited:        return "Too many requests. Try again in a moment."
        case .server(let s):      return "OpenAI server error (\(s)). Try again later."
        case .invalidResponse:    return "Unexpected response from OpenAI."
        case .decoding(let why):  return "Could not parse OpenAI response: \(why)"
        case .network(let why):   return "Network error: \(why)"
        case .noRecipesReturned:  return "No recipes were returned. Try again."
        }
    }
}
