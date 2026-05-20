// FridgeChef/SharedModels/DailyPicks.swift
import Foundation

/// Cached AI-suggested recipe titles for today, one per meal type.
/// Populated by `DailyPicksService` once per calendar day; consumed by `CatalogVM`
/// to render the "Today: …" subtitle on each meal card.
struct DailyPicks: Codable, Equatable {
    let breakfast: String?
    let lunch: String?
    let dinner: String?
    let savedAt: Date

    func title(for meal: MealType) -> String? {
        switch meal {
        case .breakfast: return breakfast
        case .lunch:     return lunch
        case .dinner:    return dinner
        }
    }
}
