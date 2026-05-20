import UIKit

final class ThemeManager {
    enum Style: Int {
        case system = 0, light = 1, dark = 2

        var asInterfaceStyle: UIUserInterfaceStyle {
            switch self {
            case .system: return .unspecified
            case .light: return .light
            case .dark: return .dark
            }
        }
    }

    static let shared = ThemeManager()

    private let defaults: UserDefaults
    private let key = "userInterfaceStyle"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var current: Style {
        get { Style(rawValue: defaults.integer(forKey: key)) ?? .system }
        set {
            defaults.set(newValue.rawValue, forKey: key)
            apply()
        }
    }

    func apply() {
        let style = current.asInterfaceStyle
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.windows }
            .flatMap { $0 }
            .forEach { $0.overrideUserInterfaceStyle = style }
    }
}
