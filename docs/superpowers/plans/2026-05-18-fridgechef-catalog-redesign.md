# FridgeChef Catalog Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace chips-based Home tab with a Recipe Catalog layout — top dish-name input, 2×2 grid of category cards (Breakfast / Lunch / Dinner / From my fridge), and a magic surprise button. Each card shows a daily-cached "Today's pick" subtitle.

**Architecture:** Clean-break refactor: delete `Features/Home/`, add `Features/Catalog/` with `CatalogVC` + `CatalogVM`. New `Services/DailyPicks/` for daily-cached AI title fetching via `UserDefaults`. Three new `OpenAIClientProtocol` methods. Existing `RecipeBatch` model, `RecipeStore`, `RecipeBatchVC`, `RecipesVC`, `SettingsVC`, `ThemeManager` are unchanged.

**Tech Stack:** UIKit + Combine + MVVM + `async/await`, XCTest + XCUITest, Core Data for batch history, XcodeGen for project generation, GPT-4o (user actions) + GPT-4o-mini (daily picks) via direct `URLSession`.

**Spec:** `docs/superpowers/specs/2026-05-18-fridgechef-catalog-redesign-design.md`

**Branch:** `feat/catalog-redesign` (already created off `feat/v1`)

---

## File map

**Created:**
```
FridgeChef/SharedModels/MealType.swift
FridgeChef/SharedModels/RecipeStyle.swift
FridgeChef/SharedModels/DailyPicks.swift
FridgeChef/Services/DailyPicks/DailyPicksService.swift
FridgeChef/Features/Catalog/View/CatalogVC.swift
FridgeChef/Features/Catalog/View/CategoryCardCell.swift
FridgeChef/Features/Catalog/ViewModel/CatalogVM.swift
FridgeChefTests/SharedModels/DailyPicksTests.swift
FridgeChefTests/Services/DailyPicksServiceTests.swift
FridgeChefTests/Features/CatalogVMTests.swift
FridgeChefTests/Stubs/StubDailyPicksService.swift
```

**Modified:**
```
FridgeChef/App/RootTabBarController.swift      # swap HomeVC → CatalogVC + outline icons
FridgeChef/App/Dependencies.swift              # add DailyPicksService factory
FridgeChef/Services/Networking/OpenAIClient.swift   # +3 methods, +1 response format
FridgeChef/Services/Networking/Prompts.swift   # +3 prompts
FridgeChefTests/Stubs/StubOpenAIClient.swift   # +3 stubbed methods
FridgeChefUITests/SmokeTests.swift             # update home assertions for new IDs
```

**Moved:**
```
FridgeChef/Features/Home/View/PhotoSourceActionSheet.swift
  → FridgeChef/Features/Catalog/View/PhotoSourceActionSheet.swift
```

**Deleted:**
```
FridgeChef/Features/Home/View/HomeVC.swift
FridgeChef/Features/Home/View/IngredientChipView.swift
FridgeChef/Features/Home/ViewModel/HomeVM.swift
FridgeChef/Features/Home/                      # empty parent folder
FridgeChefTests/Features/HomeVMTests.swift
```

---

## Phase 0 — Pre-flight & baseline

### Task 0.1: Confirm branch and clean tree

**Files:** none

- [ ] **Step 1: Verify branch**

Run: `git status && git branch --show-current`
Expected: branch is `feat/catalog-redesign`, working tree clean (no modifications to tracked files; `.claude/` untracked is OK).

- [ ] **Step 2: If on wrong branch, stop and ask**

If not on `feat/catalog-redesign`, do NOT proceed. Surface the issue and wait for direction.

### Task 0.2: Baseline test pass

**Files:** none

- [ ] **Step 1: Run all tests to capture baseline**

Run via XcodeBuildMCP `test_sim` with the configured FridgeChef scheme (or `xcodebuild test -scheme FridgeChef -destination 'platform=iOS Simulator,name=iPhone 15'`).
Expected: **46 tests pass** (current v1 state). If anything fails on baseline, stop and report — do not proceed with a redesign on a broken tree.

---

## Phase 1 — Domain types

Three small value types used by every layer that follows.

### Task 1.1: Create `MealType` enum

**Files:**
- Create: `FridgeChef/SharedModels/MealType.swift`

- [ ] **Step 1: Write the file**

```swift
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
```

- [ ] **Step 2: Regenerate Xcode project**

Run: `xcodegen generate`
Expected: `Generated project successfully`. The new file is now in the FridgeChef target.

### Task 1.2: Create `RecipeStyle` enum

**Files:**
- Create: `FridgeChef/SharedModels/RecipeStyle.swift`

- [ ] **Step 1: Write the file**

```swift
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
```

- [ ] **Step 2: Regenerate**

Run: `xcodegen generate`

### Task 1.3: Create `DailyPicks` struct + test

**Files:**
- Create: `FridgeChef/SharedModels/DailyPicks.swift`
- Test: `FridgeChefTests/SharedModels/DailyPicksTests.swift`

- [ ] **Step 1: Write the failing test**

`FridgeChefTests/SharedModels/DailyPicksTests.swift`:
```swift
import XCTest
@testable import FridgeChef

final class DailyPicksTests: XCTestCase {

    func test_roundTripsThroughJSON() throws {
        let original = DailyPicks(
            breakfast: "Avocado toast",
            lunch: "Pesto pasta",
            dinner: "Miso salmon",
            savedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DailyPicks.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func test_titleForMealReturnsCorrectValue() {
        let picks = DailyPicks(
            breakfast: "Oats",
            lunch: "Salad",
            dinner: "Curry",
            savedAt: Date()
        )
        XCTAssertEqual(picks.title(for: .breakfast), "Oats")
        XCTAssertEqual(picks.title(for: .lunch), "Salad")
        XCTAssertEqual(picks.title(for: .dinner), "Curry")
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild test -scheme FridgeChef -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:FridgeChefTests/DailyPicksTests`
Expected: COMPILE FAILURE — `DailyPicks` doesn't exist.

- [ ] **Step 3: Create the type**

`FridgeChef/SharedModels/DailyPicks.swift`:
```swift
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
```

- [ ] **Step 4: Regenerate and rerun**

Run: `xcodegen generate && xcodebuild test -scheme FridgeChef -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:FridgeChefTests/DailyPicksTests`
Expected: 2 tests pass.

### Task 1.4: Commit Phase 1

- [ ] **Step 1: Commit**

```bash
git add FridgeChef/SharedModels/MealType.swift \
        FridgeChef/SharedModels/RecipeStyle.swift \
        FridgeChef/SharedModels/DailyPicks.swift \
        FridgeChefTests/SharedModels/DailyPicksTests.swift \
        project.yml
git commit -m "$(cat <<'EOF'
feat(catalog): add MealType, RecipeStyle, DailyPicks value types

Foundational types for the catalog redesign. MealType + RecipeStyle drive
the new OpenAIClient methods; DailyPicks is what DailyPicksService caches
in UserDefaults.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Phase 2 — DailyPicksService

Protocol + live implementation + a stub for VM tests. Backed by `UserDefaults` with a calendar-day staleness rule.

### Task 2.1: Write DailyPicksService tests first

**Files:**
- Test: `FridgeChefTests/Services/DailyPicksServiceTests.swift`

- [ ] **Step 1: Write the failing tests**

`FridgeChefTests/Services/DailyPicksServiceTests.swift`:
```swift
import XCTest
import Combine
@testable import FridgeChef

@MainActor
final class DailyPicksServiceTests: XCTestCase {

    var defaults: UserDefaults!
    var stubClient: StubOpenAIClient!
    var service: LiveDailyPicksService!
    var cancellables: Set<AnyCancellable>!

    override func setUp() async throws {
        try await super.setUp()
        defaults = UserDefaults(suiteName: "DailyPicksServiceTests")!
        defaults.removePersistentDomain(forName: "DailyPicksServiceTests")
        stubClient = StubOpenAIClient()
        service = LiveDailyPicksService(client: stubClient, defaults: defaults)
        cancellables = []
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: "DailyPicksServiceTests")
        cancellables = nil
        try await super.tearDown()
    }

    func test_firstLaunch_fetchesAndCaches() async {
        // Arrange: no cached value, stub returns picks
        let picks = DailyPicks(
            breakfast: "Oats", lunch: "Salad", dinner: "Curry",
            savedAt: Date()
        )
        stubClient.dailyPicksResult = .success(picks)

        // Act
        await service.refreshIfStale()

        // Assert: service.current populated, stub was called once
        XCTAssertEqual(service.current?.breakfast, "Oats")
        XCTAssertEqual(stubClient.dailyPicksCallCount, 1)
    }

    func test_freshCache_skipsFetch() async {
        // Arrange: cache from today
        let todayPicks = DailyPicks(
            breakfast: "Cached", lunch: nil, dinner: nil,
            savedAt: Date()
        )
        let encoded = try! JSONEncoder().encode(todayPicks)
        defaults.set(encoded, forKey: "DailyPicksService.cache")

        // Re-init to pick up cached value
        service = LiveDailyPicksService(client: stubClient, defaults: defaults)
        stubClient.dailyPicksResult = .success(
            DailyPicks(breakfast: "FRESH", lunch: nil, dinner: nil, savedAt: Date())
        )

        // Act
        await service.refreshIfStale()

        // Assert: cached value retained, stub NOT called
        XCTAssertEqual(service.current?.breakfast, "Cached")
        XCTAssertEqual(stubClient.dailyPicksCallCount, 0)
    }

    func test_staleCache_refetches() async {
        // Arrange: cache from yesterday
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let oldPicks = DailyPicks(
            breakfast: "Old", lunch: nil, dinner: nil,
            savedAt: yesterday
        )
        let encoded = try! JSONEncoder().encode(oldPicks)
        defaults.set(encoded, forKey: "DailyPicksService.cache")
        service = LiveDailyPicksService(client: stubClient, defaults: defaults)

        stubClient.dailyPicksResult = .success(
            DailyPicks(breakfast: "Fresh", lunch: "L", dinner: "D", savedAt: Date())
        )

        // Act
        await service.refreshIfStale()

        // Assert: refetched, cache replaced
        XCTAssertEqual(service.current?.breakfast, "Fresh")
        XCTAssertEqual(stubClient.dailyPicksCallCount, 1)
    }

    func test_fetchFailure_keepsStaleValueAndDoesNotThrow() async {
        // Arrange: stale cache + failing network
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let oldPicks = DailyPicks(
            breakfast: "Survived", lunch: nil, dinner: nil,
            savedAt: yesterday
        )
        let encoded = try! JSONEncoder().encode(oldPicks)
        defaults.set(encoded, forKey: "DailyPicksService.cache")
        service = LiveDailyPicksService(client: stubClient, defaults: defaults)

        struct Boom: Error {}
        stubClient.dailyPicksResult = .failure(Boom())

        // Act — must not throw
        await service.refreshIfStale()

        // Assert: old value still present
        XCTAssertEqual(service.current?.breakfast, "Survived")
    }
}
```

- [ ] **Step 2: Run test to verify it fails (compile)**

Run: `xcodebuild test -scheme FridgeChef -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:FridgeChefTests/DailyPicksServiceTests`
Expected: COMPILE FAILURE — `LiveDailyPicksService` undefined, `StubOpenAIClient.dailyPicksResult` undefined.

### Task 2.2: Create DailyPicksService protocol + LiveDailyPicksService

**Files:**
- Create: `FridgeChef/Services/DailyPicks/DailyPicksService.swift`

- [ ] **Step 1: Write the file**

```swift
import Foundation
import Combine

/// Cached, once-per-day AI recipe-title suggestions for the catalog cards.
/// Lives in UserDefaults — tiny payload (~120 bytes), no Core Data needed.
@MainActor
protocol DailyPicksService: AnyObject {
    /// Latest known picks. Nil if no fetch has ever succeeded.
    var current: DailyPicks? { get }

    /// Fires whenever `current` changes (including initial load from cache).
    var publisher: AnyPublisher<DailyPicks?, Never> { get }

    /// Fetch fresh picks if the cached value is from a previous calendar day
    /// (or missing entirely). Never throws — failures keep stale value.
    func refreshIfStale() async
}

@MainActor
final class LiveDailyPicksService: DailyPicksService {

    static let cacheKey = "DailyPicksService.cache"

    private let client: OpenAIClientProtocol
    private let defaults: UserDefaults
    private let calendar: Calendar
    private let subject: CurrentValueSubject<DailyPicks?, Never>

    init(client: OpenAIClientProtocol,
         defaults: UserDefaults = .standard,
         calendar: Calendar = .current) {
        self.client = client
        self.defaults = defaults
        self.calendar = calendar

        // Load from cache on init so the publisher fires the cached value
        // before any network call.
        let loaded: DailyPicks?
        if let data = defaults.data(forKey: Self.cacheKey),
           let decoded = try? JSONDecoder().decode(DailyPicks.self, from: data) {
            loaded = decoded
        } else {
            loaded = nil
        }
        self.subject = CurrentValueSubject(loaded)
    }

    var current: DailyPicks? { subject.value }

    var publisher: AnyPublisher<DailyPicks?, Never> {
        subject.eraseToAnyPublisher()
    }

    func refreshIfStale() async {
        if !isStale(subject.value) { return }
        do {
            let fresh = try await client.dailyPicks()
            // Persist
            if let encoded = try? JSONEncoder().encode(fresh) {
                defaults.set(encoded, forKey: Self.cacheKey)
            }
            subject.send(fresh)
        } catch {
            // Swallow — daily picks must never break the UI.
            // (Stale value remains; a real app would log to os_log here.)
        }
    }

    private func isStale(_ picks: DailyPicks?) -> Bool {
        guard let picks else { return true }
        let savedDay = calendar.startOfDay(for: picks.savedAt)
        let today = calendar.startOfDay(for: Date())
        return savedDay != today
    }
}
```

- [ ] **Step 2: Regenerate project**

Run: `xcodegen generate`

### Task 2.3: Extend StubOpenAIClient with dailyPicks support

**Files:**
- Modify: `FridgeChefTests/Stubs/StubOpenAIClient.swift`

- [ ] **Step 1: Add `dailyPicks` stubbing — replace file contents**

```swift
import Foundation
@testable import FridgeChef

final class StubOpenAIClient: OpenAIClientProtocol {
    // Text & image (existing)
    var textResult: Result<[Recipe], Error> = .success([])
    var imageResult: Result<[Recipe], Error> = .success([])
    private(set) var lastIngredients: [String]?
    private(set) var lastImageJPEG: Data?

    // Dish-name variant (new in Phase 3)
    var dishResult: Result<[Recipe], Error> = .success([])
    private(set) var lastDishName: String?

    // Meal variant (new in Phase 3)
    var mealResult: Result<[Recipe], Error> = .success([])
    private(set) var lastMeal: MealType?
    private(set) var lastStyle: RecipeStyle?

    // Daily picks (new in Phase 2)
    var dailyPicksResult: Result<DailyPicks, Error> = .success(
        DailyPicks(breakfast: nil, lunch: nil, dinner: nil, savedAt: Date())
    )
    private(set) var dailyPicksCallCount: Int = 0

    func suggestRecipes(ingredients: [String]) async throws -> [Recipe] {
        lastIngredients = ingredients
        return try textResult.get()
    }

    func suggestRecipes(imageJPEG: Data) async throws -> [Recipe] {
        lastImageJPEG = imageJPEG
        return try imageResult.get()
    }

    func suggestRecipes(dishName: String) async throws -> [Recipe] {
        lastDishName = dishName
        return try dishResult.get()
    }

    func suggestRecipes(forMeal meal: MealType, style: RecipeStyle?) async throws -> [Recipe] {
        lastMeal = meal
        lastStyle = style
        return try mealResult.get()
    }

    func dailyPicks() async throws -> DailyPicks {
        dailyPicksCallCount += 1
        return try dailyPicksResult.get()
    }
}
```

Note: this references `OpenAIClientProtocol` methods that don't exist yet — the protocol will be extended in Phase 3. The compile failure that follows is **expected** and will be resolved in Phase 3.

### Task 2.4: Run DailyPicksService tests (still failing due to protocol gap)

- [ ] **Step 1: Confirm compile failure surfaces the right gap**

Run: `xcodebuild test -scheme FridgeChef -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:FridgeChefTests/DailyPicksServiceTests`
Expected: COMPILE FAILURE pointing at `OpenAIClientProtocol` missing `dailyPicks()`. **Do not implement the protocol yet** — Phase 3 covers that. Just confirm the failure is the expected shape, then move on.

### Task 2.5: Commit Phase 2 scaffold

- [ ] **Step 1: Commit (work-in-progress, compile broken intentionally)**

```bash
git add FridgeChef/Services/DailyPicks/DailyPicksService.swift \
        FridgeChefTests/Services/DailyPicksServiceTests.swift \
        FridgeChefTests/Stubs/StubOpenAIClient.swift \
        project.yml
git commit -m "$(cat <<'EOF'
feat(catalog): DailyPicksService + tests, extend StubOpenAIClient

Adds LiveDailyPicksService (UserDefaults-backed, calendar-day staleness)
and its 4 unit tests. Extends StubOpenAIClient with hooks for the three
new methods + dailyPicks. Tree intentionally won't compile until Phase 3
adds the matching OpenAIClientProtocol methods.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Phase 3 — OpenAIClient: three new methods

Add `suggestRecipes(dishName:)`, `suggestRecipes(forMeal:style:)`, and `dailyPicks()`. Use the same `response_format: json_schema` pattern as the existing methods. Daily picks uses `gpt-4o-mini` for cost; user actions use `gpt-4o` for quality.

### Task 3.1: Add prompts

**Files:**
- Modify: `FridgeChef/Services/Networking/Prompts.swift`

- [ ] **Step 1: Replace file with extended prompts**

```swift
import Foundation

enum Prompts {
    static let systemPrompt = """
    You are a cooking assistant. Given a list of ingredients the user has on hand, suggest exactly 3 recipes the user can make. Prefer recipes that use as many of the provided ingredients as possible. Each recipe must have: a short title, a one-paragraph description, an ingredient list (with rough quantities), step-by-step instructions, and an estimated total time as a short string like "30 min".
    """

    static let visionSystemPrompt = """
    You are a cooking assistant. The image shows the contents of someone's fridge or pantry. First, identify the visible ingredients. Then suggest exactly 3 recipes the user can make from them. Prefer recipes that use as many of the visible ingredients as possible. Each recipe must have: a short title, a one-paragraph description, an ingredient list (with rough quantities), step-by-step instructions, and an estimated total time as a short string like "30 min". Ignore non-edible items in the image.
    """

    static let dishSystemPrompt = """
    You are a cooking assistant. The user has named a dish they want to cook. Suggest exactly 3 variations of that dish — for example: a classic version, a healthier/lighter version, and a fancy/restaurant-style version. Each recipe must have: a short title (clearly indicating the variation), a one-paragraph description, an ingredient list (with rough quantities), step-by-step instructions, and an estimated total time as a short string like "30 min".
    """

    static func mealSystemPrompt(meal: MealType, style: RecipeStyle?) -> String {
        let styleClause: String
        if let style {
            styleClause = " Make them \(style.promptFragment)."
        } else {
            styleClause = ""
        }
        return """
        You are a cooking assistant. Suggest exactly 3 \(meal.displayName.lowercased()) recipes someone could cook today.\(styleClause) Vary the recipes — don't give three nearly-identical dishes. Each recipe must have: a short title, a one-paragraph description, an ingredient list (with rough quantities), step-by-step instructions, and an estimated total time as a short string like "30 min".
        """
    }

    static let dailyPicksSystemPrompt = """
    You are a cooking assistant. Suggest one specific recipe title (just the title, no description) for each meal type today: breakfast, lunch, and dinner. Pick recipes that are interesting but achievable in a normal home kitchen. Titles should be short and concrete — for example: "Avocado toast with poached egg" not "A delicious breakfast option". Return JSON with keys breakfast, lunch, dinner.
    """
}
```

### Task 3.2: Add `suggestRecipes(dishName:)` test

**Files:**
- Modify: `FridgeChefTests/Services/OpenAIClientTests.swift`

- [ ] **Step 1: Append the test**

Add this method to the existing `OpenAIClientTests` class (after the last existing test):

```swift
    func test_dishName_sendsCorrectRequest_andDecodesRecipes() async throws {
        // Arrange
        let recipes = (0..<3).map { i in
            ["title": "Var \(i)", "description": "d", "ingredients": ["a"], "steps": ["s"], "estimatedTime": "10 min"]
        }
        let envelope: [String: Any] = [
            "choices": [
                ["message": ["content": String(data: try JSONSerialization.data(withJSONObject: ["recipes": recipes]), encoding: .utf8)!]]
            ]
        ]
        StubURLProtocol.responder = { request in
            // assert the request shape
            let body = try! JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
            let messages = body["messages"] as! [[String: Any]]
            XCTAssertEqual(messages[0]["role"] as? String, "system")
            XCTAssertTrue((messages[0]["content"] as? String)?.contains("variation") == true)
            XCTAssertEqual(messages[1]["role"] as? String, "user")
            XCTAssertEqual(messages[1]["content"] as? String, "Dish: ramen")
            let data = try! JSONSerialization.data(withJSONObject: envelope)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }
        let client = OpenAIClient(apiKey: "test", session: Self.stubSession())

        // Act
        let result = try await client.suggestRecipes(dishName: "ramen")

        // Assert
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0].title, "Var 0")
    }
```

If your existing tests reference a helper for stub session creation (e.g. `stubSession()`), reuse it. If not, here's the helper to add as a static method to the test class:

```swift
    private static func stubSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }
```

(Skip the helper if it already exists.)

- [ ] **Step 2: Run, verify fail**

Run: `xcodebuild test -scheme FridgeChef -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:FridgeChefTests/OpenAIClientTests/test_dishName_sendsCorrectRequest_andDecodesRecipes`
Expected: COMPILE FAILURE — `suggestRecipes(dishName:)` doesn't exist on `OpenAIClient`.

### Task 3.3: Implement `suggestRecipes(dishName:)`

**Files:**
- Modify: `FridgeChef/Services/Networking/OpenAIClient.swift`

- [ ] **Step 1: Extend protocol**

Replace lines 3–6 (the `protocol OpenAIClientProtocol` block) with:

```swift
protocol OpenAIClientProtocol {
    func suggestRecipes(ingredients: [String]) async throws -> [Recipe]
    func suggestRecipes(imageJPEG: Data) async throws -> [Recipe]
    func suggestRecipes(dishName: String) async throws -> [Recipe]
    func suggestRecipes(forMeal meal: MealType, style: RecipeStyle?) async throws -> [Recipe]
    func dailyPicks() async throws -> DailyPicks
}
```

- [ ] **Step 2: Add the dish-name method**

Add inside the `struct OpenAIClient: OpenAIClientProtocol { ... }` body (after the existing `suggestRecipes(imageJPEG:)` method, before `private func send(...)`):

```swift
    func suggestRecipes(dishName: String) async throws -> [Recipe] {
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": Prompts.dishSystemPrompt],
                ["role": "user", "content": "Dish: \(dishName)"]
            ],
            "response_format": Self.responseFormat
        ]
        return try await send(body: body)
    }
```

- [ ] **Step 3: Run, verify pass**

Run: `xcodebuild test -scheme FridgeChef -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:FridgeChefTests/OpenAIClientTests/test_dishName_sendsCorrectRequest_andDecodesRecipes`
Expected: PASS.

### Task 3.4: Add `suggestRecipes(forMeal:style:)` test

**Files:**
- Modify: `FridgeChefTests/Services/OpenAIClientTests.swift`

- [ ] **Step 1: Append the test**

```swift
    func test_forMeal_includesMealAndStyleInPrompt() async throws {
        let recipes = (0..<3).map { i in
            ["title": "R\(i)", "description": "d", "ingredients": ["a"], "steps": ["s"], "estimatedTime": "20 min"]
        }
        let envelope: [String: Any] = [
            "choices": [
                ["message": ["content": String(data: try JSONSerialization.data(withJSONObject: ["recipes": recipes]), encoding: .utf8)!]]
            ]
        ]
        StubURLProtocol.responder = { request in
            let body = try! JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
            let messages = body["messages"] as! [[String: Any]]
            let system = messages[0]["content"] as! String
            XCTAssertTrue(system.lowercased().contains("dinner"), "system prompt should mention meal type")
            XCTAssertTrue(system.contains("comforting"), "system prompt should include style fragment")
            let data = try! JSONSerialization.data(withJSONObject: envelope)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }
        let client = OpenAIClient(apiKey: "test", session: Self.stubSession())

        let result = try await client.suggestRecipes(forMeal: .dinner, style: .comfort)
        XCTAssertEqual(result.count, 3)
    }
```

- [ ] **Step 2: Run, verify fail (no implementation yet)**

Run only this test.
Expected: COMPILE FAILURE — method doesn't exist yet.

### Task 3.5: Implement `suggestRecipes(forMeal:style:)`

- [ ] **Step 1: Add the method**

In `FridgeChef/Services/Networking/OpenAIClient.swift`, after the new `suggestRecipes(dishName:)` method:

```swift
    func suggestRecipes(forMeal meal: MealType, style: RecipeStyle?) async throws -> [Recipe] {
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": Prompts.mealSystemPrompt(meal: meal, style: style)],
                ["role": "user", "content": "Suggest \(meal.displayName.lowercased()) recipes."]
            ],
            "response_format": Self.responseFormat
        ]
        return try await send(body: body)
    }
```

- [ ] **Step 2: Run, verify pass**

Run only the new test.
Expected: PASS.

### Task 3.6: Add `dailyPicks()` test

- [ ] **Step 1: Append the test**

```swift
    func test_dailyPicks_decodesThreeTitles() async throws {
        let picksJSON: [String: Any] = [
            "breakfast": "Avocado toast",
            "lunch": "Pesto pasta",
            "dinner": "Miso salmon"
        ]
        let envelope: [String: Any] = [
            "choices": [
                ["message": ["content": String(data: try JSONSerialization.data(withJSONObject: picksJSON), encoding: .utf8)!]]
            ]
        ]
        StubURLProtocol.responder = { request in
            // verify the cheaper model is used
            let body = try! JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
            XCTAssertEqual(body["model"] as? String, "gpt-4o-mini")
            let data = try! JSONSerialization.data(withJSONObject: envelope)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }
        let client = OpenAIClient(apiKey: "test", session: Self.stubSession())

        let picks = try await client.dailyPicks()
        XCTAssertEqual(picks.breakfast, "Avocado toast")
        XCTAssertEqual(picks.lunch, "Pesto pasta")
        XCTAssertEqual(picks.dinner, "Miso salmon")
    }
```

- [ ] **Step 2: Run, verify fail**

Expected: COMPILE FAILURE — `dailyPicks()` doesn't exist on concrete type.

### Task 3.7: Implement `dailyPicks()` with its own response_format + cheaper model

- [ ] **Step 1: Add method + new response format constant**

In `FridgeChef/Services/Networking/OpenAIClient.swift`:

Add this method body (after `suggestRecipes(forMeal:style:)`):

```swift
    func dailyPicks() async throws -> DailyPicks {
        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": Prompts.dailyPicksSystemPrompt],
                ["role": "user", "content": "Pick today's recipes."]
            ],
            "response_format": Self.dailyPicksResponseFormat
        ]

        // Custom send path — different response shape than [Recipe]
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: req)
        } catch let urlErr as URLError {
            throw OpenAIError.network(urlErr.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw OpenAIError.invalidResponse }
        switch http.statusCode {
        case 200..<300: break
        case 401:       throw OpenAIError.unauthorized
        case 429:       throw OpenAIError.rateLimited
        default:        throw OpenAIError.server(http.statusCode)
        }

        struct Envelope: Decodable {
            struct Choice: Decodable { let message: Message }
            struct Message: Decodable { let content: String }
            let choices: [Choice]
        }
        struct PicksContent: Decodable {
            let breakfast: String
            let lunch: String
            let dinner: String
        }

        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        guard let contentString = envelope.choices.first?.message.content,
              let contentData = contentString.data(using: .utf8) else {
            throw OpenAIError.invalidResponse
        }
        let parsed = try JSONDecoder().decode(PicksContent.self, from: contentData)
        return DailyPicks(
            breakfast: parsed.breakfast,
            lunch: parsed.lunch,
            dinner: parsed.dinner,
            savedAt: Date()
        )
    }

    private static let dailyPicksResponseFormat: [String: Any] = [
        "type": "json_schema",
        "json_schema": [
            "name": "daily_picks_response",
            "strict": true,
            "schema": [
                "type": "object",
                "additionalProperties": false,
                "required": ["breakfast", "lunch", "dinner"],
                "properties": [
                    "breakfast": ["type": "string"],
                    "lunch":     ["type": "string"],
                    "dinner":    ["type": "string"]
                ]
            ]
        ]
    ]
```

- [ ] **Step 2: Run all new OpenAIClient tests + the daily picks service tests**

Run:
```bash
xcodebuild test -scheme FridgeChef -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:FridgeChefTests/OpenAIClientTests \
  -only-testing:FridgeChefTests/DailyPicksServiceTests \
  -only-testing:FridgeChefTests/DailyPicksTests
```
Expected: All tests in those 3 classes pass (10 original OpenAIClient + 3 new = 13; DailyPicksService 4; DailyPicksTests 2 = 19 total).

### Task 3.8: Wire UITestStubClient to new methods

**Files:**
- Modify: `FridgeChef/App/Dependencies.swift`

- [ ] **Step 1: Update `UITestStubClient` to conform to extended protocol**

Replace the `UITestStubClient` class at the bottom of `Dependencies.swift`:

```swift
private final class UITestStubClient: OpenAIClientProtocol {
    let recipes: [Recipe]
    init(recipes: [Recipe]) { self.recipes = recipes }
    func suggestRecipes(ingredients: [String]) async throws -> [Recipe] { recipes }
    func suggestRecipes(imageJPEG: Data) async throws -> [Recipe] { recipes }
    func suggestRecipes(dishName: String) async throws -> [Recipe] { recipes }
    func suggestRecipes(forMeal meal: MealType, style: RecipeStyle?) async throws -> [Recipe] { recipes }
    func dailyPicks() async throws -> DailyPicks {
        DailyPicks(
            breakfast: "Stubbed Toast",
            lunch: "Stubbed Salad",
            dinner: "Stubbed Curry",
            savedAt: Date()
        )
    }
}
```

(Leave the rest of `Dependencies.swift` alone — Phase 8 handles the `DailyPicksService` factory wiring.)

### Task 3.9: Build the whole tree (compile gate)

- [ ] **Step 1: Full build**

Run: `xcodebuild build -scheme FridgeChef -destination 'platform=iOS Simulator,name=iPhone 15'`
Expected: BUILD SUCCEEDED. Any residual compile errors must be fixed before continuing.

### Task 3.10: Commit Phase 3

- [ ] **Step 1: Commit**

```bash
git add FridgeChef/Services/Networking/OpenAIClient.swift \
        FridgeChef/Services/Networking/Prompts.swift \
        FridgeChef/App/Dependencies.swift \
        FridgeChefTests/Services/OpenAIClientTests.swift
git commit -m "$(cat <<'EOF'
feat(openai): add dishName / forMeal / dailyPicks methods

Three new OpenAIClientProtocol methods backing the catalog redesign:
- suggestRecipes(dishName:) — variations of a named dish
- suggestRecipes(forMeal:style:) — meal-typed recipes for cards / magic
- dailyPicks() — one cheap gpt-4o-mini call for the daily card subtitles

Adds matching prompts in Prompts.swift, a second response_format for the
3-string picks payload, and stubs in UITestStubClient. Tree compiles.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Phase 4 — CatalogVM

The view model. Uses the same `State` enum pattern as `HomeVM`. Subscribes to `DailyPicksService.publisher` for reactive card updates.

### Task 4.1: Create CatalogVM tests stub file

**Files:**
- Create: `FridgeChefTests/Features/CatalogVMTests.swift`
- Create: `FridgeChefTests/Stubs/StubDailyPicksService.swift`

- [ ] **Step 1: Create stub service**

`FridgeChefTests/Stubs/StubDailyPicksService.swift`:
```swift
import Foundation
import Combine
@testable import FridgeChef

@MainActor
final class StubDailyPicksService: DailyPicksService {
    private let subject: CurrentValueSubject<DailyPicks?, Never>
    private(set) var refreshCallCount = 0

    init(initial: DailyPicks? = nil) {
        self.subject = CurrentValueSubject(initial)
    }

    var current: DailyPicks? { subject.value }
    var publisher: AnyPublisher<DailyPicks?, Never> { subject.eraseToAnyPublisher() }

    func refreshIfStale() async {
        refreshCallCount += 1
    }

    /// Test helper — emit a value as if a fresh fetch landed.
    func emit(_ picks: DailyPicks?) {
        subject.send(picks)
    }
}
```

- [ ] **Step 2: Create skeleton test file**

`FridgeChefTests/Features/CatalogVMTests.swift`:
```swift
import XCTest
import Combine
@testable import FridgeChef

@MainActor
final class CatalogVMTests: XCTestCase {

    var client: StubOpenAIClient!
    var store: StubRecipeStore!
    var dailyPicks: StubDailyPicksService!
    var vm: CatalogVM!
    var cancellables: Set<AnyCancellable>!

    override func setUp() async throws {
        try await super.setUp()
        client = StubOpenAIClient()
        store = StubRecipeStore()
        dailyPicks = StubDailyPicksService()
        vm = CatalogVM(client: client, store: store, dailyPicks: dailyPicks)
        cancellables = []
    }

    override func tearDown() async throws {
        cancellables = nil
        try await super.tearDown()
    }
}
```

### Task 4.2: Test + implement `generateForDish`

- [ ] **Step 1: Append test**

Add inside `CatalogVMTests`:
```swift
    func test_generateForDish_savesBatchAndTransitionsToLoaded() async throws {
        // Arrange
        let recipes = (0..<3).map { i in
            Recipe(id: UUID(), title: "T\(i)", description: "d",
                   ingredients: ["a"], steps: ["s"], estimatedTime: "10 min")
        }
        client.dishResult = .success(recipes)

        // Track state transitions
        var states: [CatalogVM.State] = []
        vm.$state.sink { states.append($0) }.store(in: &cancellables)

        // Act
        vm.generateForDish("ramen")

        // Wait for task completion
        await Task.yield()
        // Spin briefly until state settles
        for _ in 0..<10 where !states.contains(where: { if case .loaded = $0 { return true } else { return false } }) {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        // Assert
        XCTAssertEqual(client.lastDishName, "ramen")
        XCTAssertEqual(store.savedBatches.count, 1)
        if case .loaded(let batch) = vm.state {
            XCTAssertEqual(batch.recipes.count, 3)
        } else {
            XCTFail("Expected .loaded, got \(vm.state)")
        }
    }
```

- [ ] **Step 2: Run, verify compile fail**

Run: `xcodebuild test -scheme FridgeChef -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:FridgeChefTests/CatalogVMTests`
Expected: COMPILE FAILURE — `CatalogVM` doesn't exist.

- [ ] **Step 3: Create `CatalogVM`**

`FridgeChef/Features/Catalog/ViewModel/CatalogVM.swift`:
```swift
import Foundation
import Combine
import UIKit

@MainActor
final class CatalogVM {

    enum State: Equatable {
        case idle
        case loading
        case loaded(RecipeBatch)
        case error(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var dailyPicks: DailyPicks?
    @Published private(set) var presentPhotoPicker: Bool = false

    private let client: OpenAIClientProtocol
    private let store: RecipeStoreProtocol
    private let dailyPicksService: DailyPicksService
    private var task: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init(client: OpenAIClientProtocol,
         store: RecipeStoreProtocol,
         dailyPicks: DailyPicksService) {
        self.client = client
        self.store = store
        self.dailyPicksService = dailyPicks
        // Seed dailyPicks from service and subscribe to future changes.
        self.dailyPicks = dailyPicks.current
        dailyPicks.publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.dailyPicks = $0 }
            .store(in: &cancellables)
    }

    deinit { task?.cancel() }

    // MARK: - generation paths

    func generateForDish(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        run { [client] in try await client.suggestRecipes(dishName: trimmed) }
    }

    func generateForMeal(_ meal: MealType) {
        run { [client] in try await client.suggestRecipes(forMeal: meal, style: nil) }
    }

    func generateRandom() {
        let meal = MealType.allCases.randomElement() ?? .dinner
        let style = RecipeStyle.allCases.randomElement()
        run { [client] in try await client.suggestRecipes(forMeal: meal, style: style) }
    }

    func generateFromImage(_ jpegData: Data) {
        run { [client] in try await client.suggestRecipes(imageJPEG: jpegData) }
    }

    // MARK: - photo picker bridge

    func openPhotoPicker() { presentPhotoPicker = true }
    func didDismissPhotoPicker() { presentPhotoPicker = false }

    // MARK: - daily picks

    func refreshDailyPicksIfStale() {
        Task { [dailyPicksService] in
            await dailyPicksService.refreshIfStale()
        }
    }

    // MARK: - shared run/save/transition

    private func run(_ fetch: @escaping () async throws -> [Recipe]) {
        task?.cancel()
        state = .loading
        task = Task { [weak self, store] in
            guard let self else { return }
            do {
                let recipes = try await fetch()
                let batch = RecipeBatch(
                    id: UUID(),
                    createdAt: Date(),
                    inputIngredients: [],
                    inputImageThumbnailJPEG: nil,
                    recipes: recipes)
                try await store.save(batch)
                if Task.isCancelled { return }
                self.state = .loaded(batch)
            } catch {
                if Task.isCancelled { return }
                self.state = .error(error.localizedDescription)
            }
        }
    }
}
```

- [ ] **Step 4: Regenerate + run**

Run:
```bash
xcodegen generate && \
xcodebuild test -scheme FridgeChef -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:FridgeChefTests/CatalogVMTests/test_generateForDish_savesBatchAndTransitionsToLoaded
```
Expected: PASS.

### Task 4.3: Test + verify `generateForMeal`

- [ ] **Step 1: Append test**

```swift
    func test_generateForMeal_callsClientWithMeal_andNilStyle() async throws {
        let recipes = (0..<3).map { _ in
            Recipe(id: UUID(), title: "x", description: "d",
                   ingredients: ["a"], steps: ["s"], estimatedTime: "10 min")
        }
        client.mealResult = .success(recipes)

        vm.generateForMeal(.lunch)

        for _ in 0..<10 where vm.state == .loading || vm.state == .idle {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        XCTAssertEqual(client.lastMeal, .lunch)
        XCTAssertNil(client.lastStyle)
        if case .loaded = vm.state {} else {
            XCTFail("Expected .loaded, got \(vm.state)")
        }
    }
```

- [ ] **Step 2: Run, verify pass**

Run only this test.
Expected: PASS (no new VM code needed; method already implemented).

### Task 4.4: Test `generateRandom` picks a meal and a style

- [ ] **Step 1: Append test**

```swift
    func test_generateRandom_callsClientWithSomeMealAndSomeStyle() async throws {
        let recipes = (0..<3).map { _ in
            Recipe(id: UUID(), title: "x", description: "d",
                   ingredients: ["a"], steps: ["s"], estimatedTime: "10 min")
        }
        client.mealResult = .success(recipes)

        vm.generateRandom()

        for _ in 0..<10 where vm.state == .loading || vm.state == .idle {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        XCTAssertNotNil(client.lastMeal, "generateRandom must pick a meal type")
        XCTAssertNotNil(client.lastStyle, "generateRandom must pick a style")
    }
```

- [ ] **Step 2: Run, verify pass**

Expected: PASS.

### Task 4.5: Test daily-picks reactive update

- [ ] **Step 1: Append test**

```swift
    func test_dailyPicks_reactsToServicePublisher() async throws {
        XCTAssertNil(vm.dailyPicks)

        let exp = expectation(description: "vm receives picks")
        vm.$dailyPicks
            .dropFirst()
            .sink { picks in
                if picks?.breakfast == "Oats" { exp.fulfill() }
            }
            .store(in: &cancellables)

        let fresh = DailyPicks(breakfast: "Oats", lunch: "Salad", dinner: "Curry", savedAt: Date())
        dailyPicks.emit(fresh)

        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertEqual(vm.dailyPicks?.breakfast, "Oats")
    }
```

- [ ] **Step 2: Run, verify pass**

Expected: PASS.

### Task 4.6: Test error path

- [ ] **Step 1: Append test**

```swift
    func test_generateForDish_failure_transitionsToError() async throws {
        struct Boom: LocalizedError { var errorDescription: String? { "boom" } }
        client.dishResult = .failure(Boom())

        vm.generateForDish("ramen")

        for _ in 0..<10 where vm.state == .loading || vm.state == .idle {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        if case .error(let msg) = vm.state {
            XCTAssertEqual(msg, "boom")
        } else {
            XCTFail("Expected .error, got \(vm.state)")
        }
    }
```

- [ ] **Step 2: Run, verify pass**

Expected: PASS.

### Task 4.7: Test `refreshDailyPicksIfStale` calls service

- [ ] **Step 1: Append test**

```swift
    func test_refreshDailyPicksIfStale_callsService() async throws {
        XCTAssertEqual(dailyPicks.refreshCallCount, 0)

        vm.refreshDailyPicksIfStale()

        // give the fire-and-forget Task a moment
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(dailyPicks.refreshCallCount, 1)
    }
```

- [ ] **Step 2: Run all CatalogVM tests**

Run:
```bash
xcodebuild test -scheme FridgeChef -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:FridgeChefTests/CatalogVMTests
```
Expected: All 5 CatalogVM tests pass.

### Task 4.8: Commit Phase 4

- [ ] **Step 1: Commit**

```bash
git add FridgeChef/Features/Catalog/ViewModel/CatalogVM.swift \
        FridgeChefTests/Features/CatalogVMTests.swift \
        FridgeChefTests/Stubs/StubDailyPicksService.swift \
        project.yml
git commit -m "$(cat <<'EOF'
feat(catalog): CatalogVM with 5 generation paths + daily-picks binding

CatalogVM owns the catalog screen's state. Five generation entry points
(generateForDish, generateForMeal, generateRandom, generateFromImage,
openPhotoPicker) all converge on a shared run() that fetches, saves,
and transitions to .loaded. Subscribes to DailyPicksService.publisher
for reactive card subtitle updates.

5 unit tests cover all behaviors; StubDailyPicksService added for
isolation.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Phase 5 — Catalog view: `CategoryCardCell`

Reusable cell for the 2×2 grid. Renders the card title + a "Today: …" subtitle when daily picks are available.

### Task 5.1: Create CategoryCardCell

**Files:**
- Create: `FridgeChef/Features/Catalog/View/CategoryCardCell.swift`

- [ ] **Step 1: Write the cell**

```swift
import UIKit

/// One card in the catalog grid. Shows a title and an optional
/// "Today: <pick>" subtitle. Used for all four cards (meals + fridge).
final class CategoryCardCell: UICollectionViewCell {

    static let reuseID = "CategoryCardCell"

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = Typography.title
        l.textColor = .ink
        l.numberOfLines = 2
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.font = Typography.body
        l.textColor = .inkSoft
        l.numberOfLines = 2
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .paper2
        contentView.layer.cornerRadius = 12
        contentView.layer.cornerCurve = .continuous

        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Spacing.s16),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Spacing.s16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Spacing.s16),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Spacing.s16)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Configure for a meal card.
    /// - Parameters:
    ///   - title: "Breakfast ideas" etc.
    ///   - pick: today's recipe title or nil; if nil, subtitle shows placeholder
    func configure(title: String, pick: String?) {
        titleLabel.text = title
        if let pick {
            subtitleLabel.text = "Today: \(pick)"
        } else {
            subtitleLabel.text = "Loading…"
        }
    }

    /// Configure for the static "From my fridge" card (no AI pick).
    func configureFridge() {
        titleLabel.text = "From my\nfridge"
        subtitleLabel.text = "Snap a photo"
    }
}
```

All tokens used (`Typography.title`, `Typography.body`, `Spacing.s16`, `.ink`, `.inkSoft`, `.paper2`) are the actual v1 tokens (verified against `FridgeChef/DesignSystem/`).

- [ ] **Step 2: Build to verify**

Run: `xcodegen generate && xcodebuild build -scheme FridgeChef -destination 'platform=iOS Simulator,name=iPhone 15'`
Expected: BUILD SUCCEEDED. If typography/spacing token names mismatch, fix and rebuild.

### Task 5.2: Commit cell

- [ ] **Step 1: Commit**

```bash
git add FridgeChef/Features/Catalog/View/CategoryCardCell.swift project.yml
git commit -m "$(cat <<'EOF'
feat(catalog): CategoryCardCell for catalog grid

Reusable cell — title + 'Today: <pick>' subtitle (or static
'Snap a photo' for the fridge card). Uses existing v1 design tokens.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Phase 6 — Catalog view: `CatalogVC`

The screen. Scroll view → input + helper → "Recipe Catalog" header → 2×2 grid → magic button. Wires VM via Combine; pushes `RecipeBatchVC` on `.loaded`.

### Task 6.1: Create CatalogVC

**Files:**
- Create: `FridgeChef/Features/Catalog/View/CatalogVC.swift`

- [ ] **Step 1: Write the screen**

```swift
import UIKit
import Combine
import PhotosUI

final class CatalogVC: UIViewController {

    // MARK: - Cards model

    private enum Card: Hashable {
        case meal(MealType)
        case fridge
    }

    // MARK: - VM

    private let vm: CatalogVM
    private var cancellables = Set<AnyCancellable>()

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let inputField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "How to cook…"
        tf.font = Typography.body
        tf.borderStyle = .roundedRect
        tf.returnKeyType = .go
        tf.accessibilityIdentifier = "catalog.input"
        return tf
    }()

    private let helperLabel: UILabel = {
        let l = UILabel()
        l.text = "Enter the name of any dish"
        l.font = Typography.caption
        l.textColor = .inkSoft
        return l
    }()

    private let sectionHeader: UILabel = {
        let l = UILabel()
        l.text = "Recipe Catalog"
        l.font = Typography.largeTitle
        l.textColor = .ink
        l.accessibilityIdentifier = "catalog.header"
        return l
    }()

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewCompositionalLayout { _, _ in
            let item = NSCollectionLayoutItem(layoutSize: .init(
                widthDimension: .fractionalWidth(0.5),
                heightDimension: .fractionalHeight(1.0)))
            item.contentInsets = .init(top: 6, leading: 6, bottom: 6, trailing: 6)
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: .init(widthDimension: .fractionalWidth(1.0),
                                  heightDimension: .absolute(140)),
                subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = .init(top: 6, leading: 10, bottom: 6, trailing: 10)
            return section
        }
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.isScrollEnabled = false
        cv.register(CategoryCardCell.self, forCellWithReuseIdentifier: CategoryCardCell.reuseID)
        return cv
    }()

    private var dataSource: UICollectionViewDiffableDataSource<Int, Card>!

    private let magicButton: UIButton = {
        let b = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
        b.setImage(UIImage(systemName: "sparkles", withConfiguration: cfg), for: .normal)
        b.tintColor = .white
        b.backgroundColor = .terracotta
        b.layer.cornerRadius = 28
        b.translatesAutoresizingMaskIntoConstraints = false
        b.accessibilityIdentifier = "catalog.magic"
        b.accessibilityLabel = "Surprise me"
        b.accessibilityHint = "Generate three random recipes"
        NSLayoutConstraint.activate([
            b.widthAnchor.constraint(equalToConstant: 56),
            b.heightAnchor.constraint(equalToConstant: 56)
        ])
        return b
    }()

    private let magicHelper: UILabel = {
        let l = UILabel()
        l.text = "Can't decide what to cook?\nJust press the button"
        l.numberOfLines = 2
        l.textAlignment = .center
        l.font = Typography.caption
        l.textColor = .inkSoft
        return l
    }()

    // Loading overlay (inlined — pattern lifted from HomeVC v1).
    private var loadingOverlay: UIView?

    // MARK: - Init

    init(vm: CatalogVM) {
        self.vm = vm
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .paper
        title = "Home"

        setUpLayout()
        configureDataSource()
        bindVM()
        wireActions()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        vm.refreshDailyPicksIfStale()
    }

    // MARK: - Layout

    private func setUpLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        contentStack.axis = .vertical
        contentStack.spacing = Spacing.s24
        contentStack.alignment = .fill
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        let inputBlock = UIStackView(arrangedSubviews: [inputField, helperLabel])
        inputBlock.axis = .vertical
        inputBlock.spacing = Spacing.s4

        let magicBlock = UIStackView(arrangedSubviews: [magicButton, magicHelper])
        magicBlock.axis = .vertical
        magicBlock.alignment = .center
        magicBlock.spacing = Spacing.s8

        [inputBlock, sectionHeader, collectionView, magicBlock].forEach {
            contentStack.addArrangedSubview($0)
        }
        collectionView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: Spacing.s24),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -Spacing.s24),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: Spacing.s24),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -Spacing.s24),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -Spacing.s24 * 2),

            // The 2x2 grid: 2 rows × 140pt = 280 + insets
            collectionView.heightAnchor.constraint(equalToConstant: 292)
        ])
    }

    // MARK: - Diffable

    private func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Int, Card>(
            collectionView: collectionView
        ) { [weak self] cv, indexPath, card in
            let cell = cv.dequeueReusableCell(withReuseIdentifier: CategoryCardCell.reuseID, for: indexPath) as! CategoryCardCell
            switch card {
            case .meal(let meal):
                let pick = self?.vm.dailyPicks?.title(for: meal)
                cell.configure(title: "\(meal.displayName)\nideas", pick: pick)
                cell.accessibilityIdentifier = "catalog.card.\(meal.rawValue)"
                cell.accessibilityLabel = "\(meal.displayName) ideas. " +
                    (pick.map { "Today: \($0)." } ?? "Loading.")
            case .fridge:
                cell.configureFridge()
                cell.accessibilityIdentifier = "catalog.card.fridge"
                cell.accessibilityLabel = "From my fridge. Snap a photo."
            }
            return cell
        }
        collectionView.delegate = self
        applySnapshot()
    }

    private func applySnapshot() {
        var snap = NSDiffableDataSourceSnapshot<Int, Card>()
        snap.appendSections([0])
        snap.appendItems([.meal(.breakfast), .meal(.lunch), .meal(.dinner), .fridge])
        dataSource.apply(snap, animatingDifferences: false)
    }

    // MARK: - VM bindings

    private func bindVM() {
        vm.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in self?.render(state) }
            .store(in: &cancellables)

        vm.$dailyPicks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // Re-render visible cards so subtitles update.
                self?.applySnapshot()
            }
            .store(in: &cancellables)

        vm.$presentPhotoPicker
            .receive(on: DispatchQueue.main)
            .sink { [weak self] show in
                if show { self?.presentPhotoPicker() }
            }
            .store(in: &cancellables)
    }

    private func render(_ state: CatalogVM.State) {
        switch state {
        case .idle:
            hideOverlay()
        case .loading:
            showOverlay()
        case .loaded(let batch):
            hideOverlay()
            let detail = RecipeBatchVC(batch: batch)
            navigationController?.pushViewController(detail, animated: true)
        case .error(let msg):
            hideOverlay()
            let alert = UIAlertController(title: "Couldn't generate", message: msg, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }

    private func showOverlay() {
        guard loadingOverlay == nil else { return }
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = UIColor.ink.withAlphaComponent(0.6)

        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .paper
        spinner.startAnimating()
        let label = UILabel()
        label.text = "Cooking up ideas…"
        label.textColor = .paper
        label.font = Typography.body
        let stack = UIStackView(arrangedSubviews: [spinner, label])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = Spacing.s8
        stack.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: v.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: v.centerYAnchor)
        ])

        view.addSubview(v)
        NSLayoutConstraint.activate([
            v.topAnchor.constraint(equalTo: view.topAnchor),
            v.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            v.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            v.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        loadingOverlay = v
    }

    private func hideOverlay() {
        loadingOverlay?.removeFromSuperview()
        loadingOverlay = nil
    }

    // MARK: - Actions

    private func wireActions() {
        inputField.delegate = self
        magicButton.addTarget(self, action: #selector(didTapMagic), for: .touchUpInside)
    }

    @objc private func didTapMagic() { vm.generateRandom() }

    private func presentPhotoPicker() {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }
}

// MARK: - UITextFieldDelegate

extension CatalogVC: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        if let text = textField.text { vm.generateForDish(text) }
        textField.text = ""
        return true
    }
}

// MARK: - UICollectionViewDelegate

extension CatalogVC: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let card = dataSource.itemIdentifier(for: indexPath) else { return }
        collectionView.deselectItem(at: indexPath, animated: true)
        switch card {
        case .meal(let meal): vm.generateForMeal(meal)
        case .fridge:         vm.openPhotoPicker()
        }
    }
}

// MARK: - PHPickerViewControllerDelegate

extension CatalogVC: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        vm.didDismissPhotoPicker()
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] obj, _ in
            guard let image = obj as? UIImage,
                  let jpeg = image.jpegData(compressionQuality: 0.7) else { return }
            Task { @MainActor in self?.vm.generateFromImage(jpeg) }
        }
    }
}
```

- [ ] **Step 2: Reconcile typography/spacing/color tokens**

All tokens referenced (`Typography.title`, `Typography.largeTitle`, `Typography.body`, `Typography.caption`, `Spacing.s4/.s8/.s16/.s24`, `.ink`, `.inkSoft`, `.paper`, `.paper2`, `.terracotta`) are the actual v1 tokens defined in `FridgeChef/DesignSystem/Typography.swift`, `Spacing.swift`, `Colors.swift`. The loading overlay and error alert are inlined in `CatalogVC` (no shared classes — pattern lifted from `HomeVC` v1). If a build error reports a missing token, double-check against the DesignSystem files; do NOT invent new tokens.

- [ ] **Step 3: Build**

Run: `xcodegen generate && xcodebuild build -scheme FridgeChef -destination 'platform=iOS Simulator,name=iPhone 15'`
Expected: BUILD SUCCEEDED.

### Task 6.2: Commit catalog screen

- [ ] **Step 1: Commit**

```bash
git add FridgeChef/Features/Catalog/View/CatalogVC.swift project.yml
git commit -m "$(cat <<'EOF'
feat(catalog): CatalogVC — input + 2x2 grid + magic button

Composes the catalog screen with a UIScrollView + diffable
UICollectionView (2x2 grid). Bindings to CatalogVM state for loading
overlay, error banner, navigation push, and reactive daily-picks
re-render. PHPicker integration for the fridge card.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Phase 7 — Wire up at app boundary

Replace `HomeVC` with `CatalogVC` in the tab bar; add `DailyPicksService` to the dependency graph; swap tab icons to outline variants.

### Task 7.1: Add `DailyPicksService` to `Dependencies`

**Files:**
- Modify: `FridgeChef/App/Dependencies.swift`

- [ ] **Step 1: Update struct + factories**

Replace the entire contents of `FridgeChef/App/Dependencies.swift`:

```swift
import Foundation
import Combine

@MainActor
struct Dependencies {
    let openAIClient: OpenAIClientProtocol
    let recipeStore: RecipeStoreProtocol
    let dailyPicksService: DailyPicksService

    static func makeLive() -> Dependencies {
        let stack = CoreDataStack()
        let store = RecipeStore(stack: stack)
        let apiKey = (try? APIKeyProvider.get()) ?? ""
        let client = OpenAIClient(apiKey: apiKey, session: .shared)
        let picks = LiveDailyPicksService(client: client)
        return Dependencies(
            openAIClient: client,
            recipeStore: store,
            dailyPicksService: picks
        )
    }

    static func makeUITestStubs() -> Dependencies {
        let recipes = (0..<3).map { i in
            Recipe(id: UUID(),
                   title: "Stubbed Recipe \(i)",
                   description: "Pre-canned for UI tests.",
                   ingredients: ["chips for UI test"],
                   steps: ["Run the test"],
                   estimatedTime: "5 min")
        }
        let stubClient = UITestStubClient(recipes: recipes)
        let stubPicks = UITestStubDailyPicksService()
        return Dependencies(
            openAIClient: stubClient,
            recipeStore: UITestStubStore(),
            dailyPicksService: stubPicks
        )
    }
}

private final class UITestStubClient: OpenAIClientProtocol {
    let recipes: [Recipe]
    init(recipes: [Recipe]) { self.recipes = recipes }
    func suggestRecipes(ingredients: [String]) async throws -> [Recipe] { recipes }
    func suggestRecipes(imageJPEG: Data) async throws -> [Recipe] { recipes }
    func suggestRecipes(dishName: String) async throws -> [Recipe] { recipes }
    func suggestRecipes(forMeal meal: MealType, style: RecipeStyle?) async throws -> [Recipe] { recipes }
    func dailyPicks() async throws -> DailyPicks {
        DailyPicks(
            breakfast: "Stubbed Toast",
            lunch: "Stubbed Salad",
            dinner: "Stubbed Curry",
            savedAt: Date()
        )
    }
}

private final class UITestStubStore: RecipeStoreProtocol {
    private var batches: [RecipeBatch] = []
    func save(_ batch: RecipeBatch) async throws { batches.insert(batch, at: 0) }
    func allBatches() async throws -> [RecipeBatch] { batches }
    func batch(id: UUID) async throws -> RecipeBatch? { batches.first { $0.id == id } }
    func deleteAll() async throws { batches = [] }
}

@MainActor
private final class UITestStubDailyPicksService: DailyPicksService {
    var current: DailyPicks? = DailyPicks(
        breakfast: "Stub Pick",
        lunch: "Stub Pick",
        dinner: "Stub Pick",
        savedAt: Date()
    )
    var publisher: AnyPublisher<DailyPicks?, Never> {
        Just(current).eraseToAnyPublisher()
    }
    func refreshIfStale() async { /* no-op */ }
}
```

### Task 7.2: Update RootTabBarController

**Files:**
- Modify: `FridgeChef/App/RootTabBarController.swift`

- [ ] **Step 1: Replace file contents**

```swift
import UIKit

final class RootTabBarController: UITabBarController {

    var deps: Dependencies?

    override func viewDidLoad() {
        super.viewDidLoad()
        let deps = self.deps ?? Dependencies.makeLive()

        let catalogVM = CatalogVM(
            client: deps.openAIClient,
            store: deps.recipeStore,
            dailyPicks: deps.dailyPicksService
        )
        let catalogVC = CatalogVC(vm: catalogVM)
        let catalogNav = UINavigationController(rootViewController: catalogVC)
        catalogNav.tabBarItem = UITabBarItem(
            title: "Home",
            image: UIImage(systemName: "house"),
            tag: 0
        )

        let recipesVM = RecipesVM(store: deps.recipeStore)
        let recipesVC = RecipesVC(vm: recipesVM)
        let recipesNav = UINavigationController(rootViewController: recipesVC)
        recipesNav.tabBarItem = UITabBarItem(
            title: "Recipes",
            image: UIImage(systemName: "square.grid.2x2"),
            tag: 1
        )

        let settingsVM = SettingsVM(store: deps.recipeStore)
        let settingsVC = SettingsVC(vm: settingsVM)
        let settingsNav = UINavigationController(rootViewController: settingsVC)
        settingsNav.tabBarItem = UITabBarItem(
            title: "Settings",
            image: UIImage(systemName: "slider.horizontal.3"),
            tag: 2
        )

        viewControllers = [catalogNav, recipesNav, settingsNav]
    }
}
```

- [ ] **Step 2: Build + boot the simulator**

Run: `xcodegen generate && xcodebuild build -scheme FridgeChef -destination 'platform=iOS Simulator,name=iPhone 15'`
Expected: BUILD SUCCEEDED.

If it fails because `HomeVC` is still referenced elsewhere (it shouldn't be, but in case), fix the reference; the Home folder gets deleted in Phase 10.

- [ ] **Step 3: Launch and smoke-check visually**

Via XcodeBuildMCP: `build_run_sim`, then `screenshot` to confirm the new home shows the input, the 4 cards, and the magic button.

### Task 7.3: Commit wire-up

- [ ] **Step 1: Commit**

```bash
git add FridgeChef/App/Dependencies.swift FridgeChef/App/RootTabBarController.swift
git commit -m "$(cat <<'EOF'
feat(catalog): wire CatalogVC into tab bar, add DailyPicksService to DI

Replaces HomeVC with CatalogVC at the Home tab slot. Swaps tab icons
to outline SF Symbols (house / square.grid.2x2 / slider.horizontal.3).
Extends Dependencies with dailyPicksService factory (live + UI-test stub).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Phase 8 — Update UI smoke test

The existing `SmokeTests.testHomeShowsCoreElements` looks for chip-era IDs. Point it at the new catalog IDs.

### Task 8.1: Find the existing assertion

**Files:**
- Inspect: `FridgeChefUITests/SmokeTests.swift`

- [ ] **Step 1: Read the file**

Run: `cat FridgeChefUITests/SmokeTests.swift`
Note which identifiers (`home.inputField`, `home.addButton`, `home.suggestButton`, etc.) are currently asserted.

### Task 8.2: Update the home test

**Files:**
- Modify: `FridgeChefUITests/SmokeTests.swift`

- [ ] **Step 1: Replace the home-tab test method**

Find `testHomeShowsCoreElements()` (or whatever the equivalent is) and replace it with:

```swift
    func testHomeShowsCoreCatalogElements() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestMode"]
        app.launch()

        // Bottom Home tab is the first tab — should already be selected.
        let input = app.textFields["catalog.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 4), "Catalog input should be visible")

        // All four cards should be present.
        for id in ["catalog.card.breakfast",
                   "catalog.card.lunch",
                   "catalog.card.dinner",
                   "catalog.card.fridge"] {
            XCTAssertTrue(app.cells[id].exists || app.otherElements[id].exists,
                          "Card \(id) should be visible")
        }

        // Magic button.
        XCTAssertTrue(app.buttons["catalog.magic"].exists, "Magic button should be visible")
    }
```

Note: if cards aren't matching `app.cells` or `app.otherElements`, fall back to `app.descendants(matching: .any).matching(identifier: id).firstMatch.exists`.

- [ ] **Step 2: Run UI test**

Run: `xcodebuild test -scheme FridgeChef -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:FridgeChefUITests/SmokeTests/testHomeShowsCoreCatalogElements`
Expected: PASS.

### Task 8.3: Run the full UI test suite

- [ ] **Step 1: Run all UI tests**

Run: `xcodebuild test -scheme FridgeChef -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:FridgeChefUITests`
Expected: All UI tests pass (the Recipes + Settings smoke tests should be unchanged).

### Task 8.4: Commit smoke test update

- [ ] **Step 1: Commit**

```bash
git add FridgeChefUITests/SmokeTests.swift
git commit -m "$(cat <<'EOF'
test(ui): point home smoke test at catalog IDs

testHomeShowsCoreElements becomes testHomeShowsCoreCatalogElements,
asserting catalog.input + four catalog.card.* + catalog.magic instead
of the v1 chip IDs.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Phase 9 — Delete legacy Home

Now that everything's wired and tested, remove the dead `Features/Home/` folder and its tests. `PhotoSourceActionSheet` is deleted here too — `CatalogVC` uses `PHPickerViewController` directly (library filter), so the action-sheet camera-vs-library prompt is not needed for the fridge card.

### Task 9.1: Delete Home view + viewmodel

**Files:**
- Delete: `FridgeChef/Features/Home/View/HomeVC.swift`
- Delete: `FridgeChef/Features/Home/View/IngredientChipView.swift`
- Delete: `FridgeChef/Features/Home/View/PhotoSourceActionSheet.swift`
- Delete: `FridgeChef/Features/Home/ViewModel/HomeVM.swift`
- Delete: `FridgeChef/Features/Home/View/` (empty dir)
- Delete: `FridgeChef/Features/Home/ViewModel/` (empty dir)
- Delete: `FridgeChef/Features/Home/` (empty dir)

- [ ] **Step 1: Remove files**

```bash
git rm FridgeChef/Features/Home/View/HomeVC.swift \
       FridgeChef/Features/Home/View/IngredientChipView.swift \
       FridgeChef/Features/Home/View/PhotoSourceActionSheet.swift \
       FridgeChef/Features/Home/ViewModel/HomeVM.swift
rmdir FridgeChef/Features/Home/View FridgeChef/Features/Home/ViewModel FridgeChef/Features/Home 2>/dev/null || true
```

### Task 9.2: Delete HomeVMTests

**Files:**
- Delete: `FridgeChefTests/Features/HomeVMTests.swift`

- [ ] **Step 1: Remove file**

```bash
git rm FridgeChefTests/Features/HomeVMTests.swift
```

### Task 9.3: Regenerate, build, run all tests

- [ ] **Step 1: Regenerate + build + test**

Run:
```bash
xcodegen generate && \
xcodebuild test -scheme FridgeChef -destination 'platform=iOS Simulator,name=iPhone 15'
```
Expected: BUILD SUCCEEDED + all tests pass. Target count: ~49 (46 baseline − 9 HomeVMTests + 5 CatalogVMTests + 4 DailyPicksServiceTests + 2 DailyPicksTests + 3 OpenAIClient additions = 51; minor adjustments OK).

### Task 9.4: Commit cleanup

- [ ] **Step 1: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
chore(catalog): remove legacy Home feature folder

Features/Home and HomeVMTests deleted. CatalogVC is the new Home.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Phase 10 — End-to-end verification + PR

### Task 10.1: Manual flow check

- [ ] **Step 1: Run the app and exercise each path**

Via XcodeBuildMCP (or a real run):
1. Launch — confirm catalog screen shows.
2. Wait ~2s — confirm cards' "Loading…" subtitles get replaced by daily picks.
3. Type "ramen" + return — confirm push to `RecipeBatchVC` with 3 recipes.
4. Back out. Tap Breakfast card — confirm push with 3 recipes.
5. Back out. Tap magic button — confirm push with 3 recipes (will vary).
6. Back out. Tap "From my fridge" card — confirm photo picker opens. Cancel.
7. Switch to Recipes tab — confirm 3+ batches saved.
8. Switch to Settings — confirm unchanged.
9. Toggle dark mode — confirm catalog renders correctly.

If any step fails, fix the issue, add a regression test, and commit before continuing.

### Task 10.2: Capture new screenshots (optional)

- [ ] **Step 1: Update README screenshots if desired**

Hand off to the user — README updates aren't in scope for this plan. If they want fresh screenshots, that's a follow-up task.

### Task 10.3: Push branch

- [ ] **Step 1: Push**

```bash
git push -u origin feat/catalog-redesign
```

### Task 10.4: Open draft PR

- [ ] **Step 1: Open PR via gh**

Defer to the user — they may want to merge `feat/v1` (PR #1) first before stacking this. Suggest:

> "Branch pushed. Two PR options:
> 1. PR against `main` (independent of PR #1 — they'll merge in either order)
> 2. PR against `feat/v1` (stacked — merge PR #1 first, then this)
> Want me to open it, and against which base?"

---

## Done

Tests: target ~51 (was 46). All UI paths exercised. No HomeVC left in tree.
