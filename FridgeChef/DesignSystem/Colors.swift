import UIKit

extension UIColor {
    static let paper = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 28/255, green: 26/255, blue: 22/255, alpha: 1)
            : UIColor(red: 245/255, green: 241/255, blue: 232/255, alpha: 1)
    }
    static let paper2 = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 38/255, green: 35/255, blue: 30/255, alpha: 1)
            : UIColor(red: 239/255, green: 233/255, blue: 220/255, alpha: 1)
    }
    static let ink = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 240/255, green: 236/255, blue: 228/255, alpha: 1)
            : UIColor(red: 44/255, green: 42/255, blue: 38/255, alpha: 1)
    }
    static let inkSoft = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 168/255, green: 163/255, blue: 154/255, alpha: 1)
            : UIColor(red: 107/255, green: 104/255, blue: 98/255, alpha: 1)
    }
    static let rule = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 58/255, green: 54/255, blue: 49/255, alpha: 1)
            : UIColor(red: 221/255, green: 215/255, blue: 202/255, alpha: 1)
    }
    static let sage = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 163/255, green: 197/255, blue: 148/255, alpha: 1)
            : UIColor(red: 135/255, green: 168/255, blue: 120/255, alpha: 1)
    }
    static let terracotta = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 224/255, green: 146/255, blue: 117/255, alpha: 1)
            : UIColor(red: 201/255, green: 123/255, blue: 92/255, alpha: 1)
    }
    static let butter = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 62/255, green: 56/255, blue: 35/255, alpha: 1)
            : UIColor(red: 240/255, green: 228/255, blue: 184/255, alpha: 1)
    }
}
