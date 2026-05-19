import Foundation

/// Meal categories the catalog supports.
/// Note: "fridge" is NOT a meal type — it's a separate generation path
/// (photo of fridge contents). Keep this enum to just the three meals.
enum MealType: String, Codable, CaseIterable {
    case breakfast
    case lunch
    case dinner

    /// User-facing card title — short, capitalized, no "ideas" suffix
    /// (the suffix is added by the cell layout).
    var displayName: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch:     return "Lunch"
        case .dinner:    return "Dinner"
        }
    }
}
