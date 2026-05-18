import UIKit

enum Typography {
    static func fraunces(_ size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        let name = (weight == .bold) ? "Fraunces72pt-Bold" : "Fraunces72pt-Regular"
        return UIFont(name: name, size: size) ?? UIFont.systemFont(ofSize: size, weight: weight)
    }
    static func dmSans(_ size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        let name = (weight == .medium || weight == .semibold) ? "DMSans-Medium" : "DMSans-Regular"
        return UIFont(name: name, size: size) ?? UIFont.systemFont(ofSize: size, weight: weight)
    }

    static let largeTitle = fraunces(34, weight: .bold)
    static let title = fraunces(22, weight: .bold)
    static let bigNumber = fraunces(48, weight: .bold)
    static let bodyLg = dmSans(17)
    static let body = dmSans(15)
    static let caption = dmSans(13, weight: .medium)
    static let micro = dmSans(11, weight: .medium)
}
