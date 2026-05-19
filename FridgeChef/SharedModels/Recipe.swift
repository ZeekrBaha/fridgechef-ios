import Foundation

struct Recipe: Codable, Hashable, Identifiable {
    let id: UUID
    let title: String
    let description: String
    let ingredients: [String]
    let steps: [String]
    let estimatedTime: String
    let isFavorite: Bool
    let updatedAt: Date?
}
