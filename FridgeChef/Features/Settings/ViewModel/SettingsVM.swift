import Foundation

@MainActor
final class SettingsVM {

    enum APIKeyStatus { case present, missing }

    private let theme: ThemeManager
    private let store: RecipeStoreProtocol
    private let keyProvider: () throws -> String

    init(theme: ThemeManager = .shared,
         store: RecipeStoreProtocol,
         keyProvider: @escaping () throws -> String = { try APIKeyProvider.get() }) {
        self.theme = theme
        self.store = store
        self.keyProvider = keyProvider
    }

    var currentTheme: ThemeManager.Style { theme.current }

    func setTheme(_ style: ThemeManager.Style) {
        theme.current = style
    }

    var apiKeyStatus: APIKeyStatus {
        (try? keyProvider()) != nil ? .present : .missing
    }

    var modelName: String { "gpt-4o" }

    var versionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    func clearAll() async {
        try? await store.deleteAll()
        NotificationCenter.default.post(name: .recipesDidChange, object: nil)
    }
}
