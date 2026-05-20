import Foundation

protocol InfoDictionaryProvider {
    func object(forInfoDictionaryKey key: String) -> Any?
}

extension Bundle: InfoDictionaryProvider {}

struct APIKeyProvider {
    static func get(from bundle: InfoDictionaryProvider = Bundle.main) throws -> String {
        guard let k = bundle.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String,
              !k.isEmpty else { throw OpenAIError.missingAPIKey }
        return k
    }
}
