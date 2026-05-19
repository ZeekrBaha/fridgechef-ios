import Foundation

/// Style flavor passed to the prompt for the random "surprise me" path.
/// Not user-facing — purely a prompt modifier for variety across magic taps.
enum RecipeStyle: String, CaseIterable {
    case quick
    case comfort
    case healthy
    case fancy
    case onePot
    case vegetarian

    /// Short adjective phrase inserted into the prompt.
    var promptFragment: String {
        switch self {
        case .quick:       return "quick and easy"
        case .comfort:     return "comforting"
        case .healthy:     return "healthy"
        case .fancy:       return "restaurant-style"
        case .onePot:      return "one-pot"
        case .vegetarian:  return "vegetarian"
        }
    }
}
