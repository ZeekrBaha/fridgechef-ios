import Foundation
import Combine

@MainActor
final class CreateEditRecipeVM {

    enum Mode {
        case new
        case edit(existing: Recipe, batchId: UUID)
    }

    enum SaveState: Equatable {
        case idle
        case saving
        case saved(Recipe)
        case error(String)
    }

    @Published var title: String = ""
    @Published var descriptionText: String = ""
    @Published var ingredients: [String] = [""]
    @Published var steps: [String] = [""]
    @Published var estimatedTime: String = ""

    @Published private(set) var isValid: Bool = false
    @Published private(set) var saveState: SaveState = .idle

    let mode: Mode
    private let store: RecipeStoreProtocol
    private let initialSnapshot: Snapshot
    private var cancellables = Set<AnyCancellable>()

    private struct Snapshot: Equatable {
        let title: String
        let description: String
        let ingredients: [String]
        let steps: [String]
        let estimatedTime: String
    }

    init(mode: Mode, store: RecipeStoreProtocol) {
        self.mode = mode
        self.store = store
        switch mode {
        case .new:
            self.initialSnapshot = Snapshot(title: "", description: "",
                                            ingredients: [""], steps: [""],
                                            estimatedTime: "")
        case .edit(let r, _):
            self.title = r.title
            self.descriptionText = r.description
            self.ingredients = r.ingredients.isEmpty ? [""] : r.ingredients
            self.steps = r.steps.isEmpty ? [""] : r.steps
            self.estimatedTime = r.estimatedTime
            self.initialSnapshot = Snapshot(
                title: r.title, description: r.description,
                ingredients: r.ingredients.isEmpty ? [""] : r.ingredients,
                steps: r.steps.isEmpty ? [""] : r.steps,
                estimatedTime: r.estimatedTime
            )
        }
        bindValidation()
    }

    var hasUnsavedChanges: Bool {
        let current = Snapshot(title: title, description: descriptionText,
                               ingredients: ingredients, steps: steps,
                               estimatedTime: estimatedTime)
        return current != initialSnapshot
    }

    private func bindValidation() {
        Publishers.CombineLatest3($title, $ingredients, $steps)
            .map { title, ings, steps in
                let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                let hasIng = ings.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                let hasStep = steps.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                return !trimmedTitle.isEmpty && hasIng && hasStep
            }
            .assign(to: &$isValid)
    }

    func addIngredientRow() { ingredients.append("") }
    func removeIngredientRow(at index: Int) {
        guard ingredients.indices.contains(index), ingredients.count > 1 else { return }
        ingredients.remove(at: index)
    }
    func addStepRow() { steps.append("") }
    func removeStepRow(at index: Int) {
        guard steps.indices.contains(index), steps.count > 1 else { return }
        steps.remove(at: index)
    }

    /// Delete the recipe being edited. No-op in `.new` mode.
    /// Returns true on success so the VC can pop back to the list.
    func delete() async -> Bool {
        guard case .edit(let existing, _) = mode else { return false }
        do {
            try await store.delete(recipeId: existing.id)
            return true
        } catch {
            saveState = .error(error.localizedDescription)
            return false
        }
    }

    func save() async {
        guard saveState != .saving else { return }
        saveState = .saving

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedIngredients = ingredients.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let cleanedSteps = steps.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let trimmedTime = estimatedTime.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            switch mode {
            case .new:
                let recipe = Recipe(
                    id: UUID(),
                    title: trimmedTitle,
                    description: descriptionText.trimmingCharacters(in: .whitespacesAndNewlines),
                    ingredients: cleanedIngredients,
                    steps: cleanedSteps,
                    estimatedTime: trimmedTime,
                    isFavorite: false,
                    updatedAt: nil
                )
                let batch = RecipeBatch(
                    id: UUID(),
                    createdAt: Date(),
                    inputIngredients: [],
                    inputImageThumbnailJPEG: nil,
                    recipes: [recipe],
                    source: .user
                )
                try await store.save(batch)
                saveState = .saved(recipe)

            case .edit(let existing, let batchId):
                let updated = Recipe(
                    id: existing.id,
                    title: trimmedTitle,
                    description: descriptionText.trimmingCharacters(in: .whitespacesAndNewlines),
                    ingredients: cleanedIngredients,
                    steps: cleanedSteps,
                    estimatedTime: trimmedTime,
                    isFavorite: existing.isFavorite,
                    updatedAt: nil
                )
                try await store.update(updated, in: batchId)
                saveState = .saved(updated)
            }
        } catch {
            saveState = .error(error.localizedDescription)
        }
    }
}
