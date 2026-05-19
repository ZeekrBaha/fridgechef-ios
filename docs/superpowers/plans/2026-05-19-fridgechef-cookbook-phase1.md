# FridgeChef Cookbook Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the Recipes tab from "AI-batch history" into the start of a personal cookbook — users can create their own recipe, edit any recipe (AI or user), favorite individual recipes (with a list filter), and delete recipes/batches.

**Architecture:** Additive Core Data lightweight migration (3 new attributes). One new screen `CreateEditRecipeVC` with `Mode.new` / `Mode.edit`. Four new `RecipeStore` methods (`update`, `setFavorite`, `delete(recipeId:)`, `delete(batchId:)`) with a cascade rule that deletes a batch when its last recipe is removed. Existing `RecipeBatch` concept is reused as the storage for user-created recipes (one batch with one child, `source = .user`), so every existing list / detail view continues to work unchanged in shape.

**Tech Stack:** iOS UIKit + MVVM + Combine + Core Data, iOS 17+, XcodeGen, zero third-party deps. XCTest + XCUITest.

**Reference:** Spec at `docs/superpowers/specs/2026-05-19-fridgechef-cookbook-phase1-design.md`.

**Branch:** `feat/cookbook-phase1` stacked on `feat/catalog-redesign` (current working branch). Final PR target: `feat/v1` (or `main` if v1 has merged by then).

---

## File Structure

### New files

| Path | Responsibility |
|---|---|
| `FridgeChef/SharedModels/RecipeSource.swift` | `enum RecipeSource: String, Codable { case ai, user }` |
| `FridgeChef/Services/Persistence/FridgeChef.xcdatamodeld/FridgeChef v2.xcdatamodel/contents` | New Core Data model version: adds `source` to batch entity, `isFavorite` + `updatedAt` to recipe entity |
| `FridgeChef/Services/Persistence/FridgeChef.xcdatamodeld/.xccurrentversion` | Plist pointing the model bundle at `FridgeChef v2.xcdatamodel` |
| `FridgeChef/Features/CreateEditRecipe/ViewModel/CreateEditRecipeVM.swift` | New screen view model with `Mode.new` / `Mode.edit`, validation, save |
| `FridgeChef/Features/CreateEditRecipe/View/CreateEditRecipeVC.swift` | New screen UI: scrollable form with dynamic ingredient/step rows |
| `FridgeChefTests/Features/CreateEditRecipeVMTests.swift` | 6 unit tests for the new VM |

### Modified files

| Path | Change |
|---|---|
| `FridgeChef/SharedModels/Recipe.swift` | + `isFavorite: Bool`, + `updatedAt: Date?` |
| `FridgeChef/SharedModels/RecipeBatch.swift` | + `source: RecipeSource` |
| `FridgeChef/Services/Persistence/Entities.swift` | + `@NSManaged var source: String?` on batch entity, + `@NSManaged var isFavorite: Bool`, + `@NSManaged var updatedAt: Date?` on recipe entity |
| `FridgeChef/Services/Persistence/RecipeBatchEntity+ext.swift` | Read/write `source` |
| `FridgeChef/Services/Persistence/RecipeEntity+ext.swift` | Read/write `isFavorite` + `updatedAt` |
| `FridgeChef/Services/Persistence/RecipeStore.swift` | + `RecipeStoreError`; + 4 protocol methods + impls; post `.recipesDidChange` from all mutating methods |
| `FridgeChef/Services/Networking/OpenAIClient.swift` | Decoder construction adds `isFavorite: false, updatedAt: nil` |
| `FridgeChef/Features/Catalog/ViewModel/CatalogVM.swift` | `RecipeBatch(...)` literal adds `source: .ai` |
| `FridgeChef/App/Dependencies.swift` | UITestStub fixtures use new fields; `UITestStubStore` gets 4 new no-op methods |
| `FridgeChef/App/RootTabBarController.swift` | (No structural change; `RecipesVC` still takes only the VM — VC accesses `vm.store`) |
| `FridgeChef/Features/Recipes/ViewModel/RecipesVM.swift` | `store` becomes internal (drop `private`); + `Filter` enum + `@Published filter`, + `visibleGroups`, + `deleteBatch(id:)` |
| `FridgeChef/Features/Recipes/View/RecipesVC.swift` | + `+` nav button, + segmented control, + swipe-delete, bind to `visibleGroups` |
| `FridgeChef/Features/Recipes/View/RecipesBatchCell.swift` | Show `heart.fill` leading icon when any recipe in batch is favorited |
| `FridgeChef/Features/RecipeBatch/ViewModel/RecipeBatchVM.swift` | + `store` property, + `BatchState` enum + `@Published batchState`, + `deleteRecipe(id:)`, computed `recipes`, `headerDateString` |
| `FridgeChef/Features/RecipeBatch/View/RecipeBatchVC.swift` | Pass `vm.store` into `RecipeDetailVM`; bind to `batchState`; pop on `.gone`; + swipe-delete |
| `FridgeChef/Features/RecipeBatch/View/RecipeBatchCardCell.swift` | Overlay `heart.fill` top-right when `recipe.isFavorite` |
| `FridgeChef/Features/RecipeDetail/ViewModel/RecipeDetailVM.swift` | Replace `let recipe` with `@Published recipe`; add `store`, `batchId`, `isFavorite`, `lastError`, `toggleFavorite()`, notification-driven reload |
| `FridgeChef/Features/RecipeDetail/View/RecipeDetailVC.swift` | Bind heart + Edit nav buttons; rebuild content stack on `vm.$recipe` |
| `FridgeChefTests/Stubs/StubRecipeStore.swift` | + 4 new methods with capture arrays + `nextError` |
| `FridgeChefTests/Services/RecipeStoreTests.swift` | + 5 new tests |
| `FridgeChefTests/Features/RecipesVMTests.swift` | + 2 new tests |
| `FridgeChefTests/Features/RecipeBatchVMTests.swift` | + 2 new tests; existing tests get `store: StubRecipeStore()` added to inits |
| `FridgeChefTests/Features/RecipeDetailVMTests.swift` | + 2 new tests; existing test gets new init params |
| `FridgeChefUITests/SmokeTests.swift` | + 1 test |
| Any test file that constructs `Recipe(...)` / `RecipeBatch(...)` literally | Add `isFavorite: false, updatedAt: nil` and/or `source: .ai` |

---

## Task 1: Create branch and verify clean state

**Files:** none yet — just git setup.

- [ ] **Step 1: Confirm we are on the catalog redesign branch with no uncommitted work**

```bash
cd /Users/baha/Desktop/llm-ai-projects/recipe-ingredients-ios
git status
git branch --show-current
```

Expected: `working tree clean` and current branch is `feat/catalog-redesign` (or `feat/v1` if v1.1 has merged).

- [ ] **Step 2: Create the Phase 1 branch**

```bash
git checkout -b feat/cookbook-phase1
```

- [ ] **Step 3: Confirm the spec is present**

```bash
ls docs/superpowers/specs/2026-05-19-fridgechef-cookbook-phase1-design.md
```

Expected: file exists. If missing, stop and investigate.

- [ ] **Step 4: Establish a baseline test run on the branch**

```bash
xcodegen generate
xcodebuild -project FridgeChef.xcodeproj -scheme FridgeChef \
  -destination 'platform=iOS Simulator,name=iPhone 16' test 2>&1 | tail -40
```

Expected: 52 tests pass. If any fail, fix before proceeding — Phase 1 must build on a green baseline.

---

## Task 2: Add `RecipeSource` enum

**Files:**
- Create: `FridgeChef/SharedModels/RecipeSource.swift`

- [ ] **Step 1: Write the file**

```swift
import Foundation

enum RecipeSource: String, Codable, Equatable {
    case ai
    case user
}
```

- [ ] **Step 2: Regenerate project and confirm it builds**

```bash
xcodegen generate
xcodebuild -project FridgeChef.xcodeproj -scheme FridgeChef \
  -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -20
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add FridgeChef/SharedModels/RecipeSource.swift
git commit -m "feat(cookbook): add RecipeSource enum"
```

---

## Task 3: Extend value types `Recipe` and `RecipeBatch`

**Files:**
- Modify: `FridgeChef/SharedModels/Recipe.swift`
- Modify: `FridgeChef/SharedModels/RecipeBatch.swift`

- [ ] **Step 1: Add `isFavorite` and `updatedAt` to `Recipe`**

Rewrite `FridgeChef/SharedModels/Recipe.swift`:

```swift
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
```

- [ ] **Step 2: Add `source` to `RecipeBatch`**

Rewrite `FridgeChef/SharedModels/RecipeBatch.swift`:

```swift
import Foundation

struct RecipeBatch: Identifiable, Hashable {
    let id: UUID
    let createdAt: Date
    let inputIngredients: [String]
    let inputImageThumbnailJPEG: Data?
    let recipes: [Recipe]
    let source: RecipeSource
}
```

- [ ] **Step 3: Try to build — it will fail with missing arg errors at every call site**

```bash
xcodebuild -project FridgeChef.xcodeproj -scheme FridgeChef \
  -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep "error:" | head -40
```

Expected: errors of the form `missing arguments for parameters 'isFavorite', 'updatedAt' in call` (app sources) and `missing argument for parameter 'source' in call`. We will fix these in Tasks 4 and 5.

- [ ] **Step 4: Commit (intentionally with broken build — next task fixes it)**

Skip commit until Task 5 — keep app sources + tests in sync within one commit boundary. If you prefer green-only commits, defer Step 4 of Task 3 until after Tasks 4 + 5. Either is fine.

---

## Task 4: Update app call sites for new fields

**Files:**
- Modify: `FridgeChef/Services/Networking/OpenAIClient.swift:186-193`
- Modify: `FridgeChef/Features/Catalog/ViewModel/CatalogVM.swift:84-89`
- Modify: `FridgeChef/Services/Persistence/RecipeEntity+ext.swift`
- Modify: `FridgeChef/Services/Persistence/RecipeBatchEntity+ext.swift`
- Modify: `FridgeChef/App/Dependencies.swift`

- [ ] **Step 1: Update `OpenAIClient` decoder to set new fields**

In `FridgeChef/Services/Networking/OpenAIClient.swift`, replace the literal at line 187:

```swift
return parsed.recipes.map {
    Recipe(id: UUID(),
           title: $0.title,
           description: $0.description,
           ingredients: $0.ingredients,
           steps: $0.steps,
           estimatedTime: $0.estimatedTime,
           isFavorite: false,
           updatedAt: nil)
}
```

- [ ] **Step 2: Update `CatalogVM.run` to set `source: .ai` on the new batch**

In `FridgeChef/Features/Catalog/ViewModel/CatalogVM.swift`, replace the batch literal at lines 84-89:

```swift
let batch = RecipeBatch(
    id: UUID(),
    createdAt: Date(),
    inputIngredients: [],
    inputImageThumbnailJPEG: nil,
    recipes: recipes,
    source: .ai)
```

- [ ] **Step 3: Update `RecipeEntity+ext.swift` to read/write new fields**

Rewrite `FridgeChef/Services/Persistence/RecipeEntity+ext.swift`:

```swift
import CoreData

extension RecipeEntity {
    var asRecipe: Recipe {
        Recipe(
            id: id ?? UUID(),
            title: title ?? "",
            description: recipeDescription ?? "",
            ingredients: decodeJSONArray(ingredientsJSON),
            steps: decodeJSONArray(stepsJSON),
            estimatedTime: estimatedTime ?? "",
            isFavorite: isFavorite,
            updatedAt: updatedAt
        )
    }

    static func create(from recipe: Recipe, order: Int16,
                       in ctx: NSManagedObjectContext) -> RecipeEntity {
        let e = RecipeEntity(context: ctx)
        e.id = recipe.id
        e.title = recipe.title
        e.recipeDescription = recipe.description
        e.ingredientsJSON = encodeJSONArray(recipe.ingredients)
        e.stepsJSON = encodeJSONArray(recipe.steps)
        e.estimatedTime = recipe.estimatedTime
        e.order = order
        e.isFavorite = recipe.isFavorite
        e.updatedAt = recipe.updatedAt
        return e
    }
}

func decodeJSONArray(_ json: String?) -> [String] {
    guard let json, let data = json.data(using: .utf8),
          let arr = try? JSONDecoder().decode([String].self, from: data) else { return [] }
    return arr
}

func encodeJSONArray(_ arr: [String]) -> String {
    guard let data = try? JSONEncoder().encode(arr),
          let s = String(data: data, encoding: .utf8) else { return "[]" }
    return s
}
```

- [ ] **Step 4: Update `RecipeBatchEntity+ext.swift` to read/write `source`**

Rewrite `FridgeChef/Services/Persistence/RecipeBatchEntity+ext.swift`:

```swift
import CoreData

extension RecipeBatchEntity {
    var asBatch: RecipeBatch {
        let orderedRecipes = (recipes?.array as? [RecipeEntity] ?? [])
            .sorted { $0.order < $1.order }
            .map(\.asRecipe)
        let parsedSource = RecipeSource(rawValue: source ?? "ai") ?? .ai
        return RecipeBatch(
            id: id ?? UUID(),
            createdAt: createdAt ?? Date(),
            inputIngredients: decodeJSONArray(inputIngredientsJSON),
            inputImageThumbnailJPEG: inputImageThumbnailJPEG,
            recipes: orderedRecipes,
            source: parsedSource
        )
    }

    static func create(from batch: RecipeBatch,
                       in ctx: NSManagedObjectContext) -> RecipeBatchEntity {
        let e = RecipeBatchEntity(context: ctx)
        e.id = batch.id
        e.createdAt = batch.createdAt
        e.inputIngredientsJSON = encodeJSONArray(batch.inputIngredients)
        e.inputImageThumbnailJPEG = batch.inputImageThumbnailJPEG
        e.source = batch.source.rawValue
        let set = NSMutableOrderedSet()
        for (idx, r) in batch.recipes.enumerated() {
            let re = RecipeEntity.create(from: r, order: Int16(idx), in: ctx)
            re.batch = e
            set.add(re)
        }
        e.recipes = set
        return e
    }
}
```

- [ ] **Step 5: Update `Dependencies.swift` UI-test stub fixtures**

In `FridgeChef/App/Dependencies.swift`, replace the `Recipe` literal block in `makeUITestStubs()` (lines 24-31):

```swift
let recipes = (0..<3).map { i in
    Recipe(id: UUID(),
           title: "Stubbed Recipe \(i)",
           description: "Pre-canned for UI tests.",
           ingredients: ["chips for UI test"],
           steps: ["Run the test"],
           estimatedTime: "5 min",
           isFavorite: false,
           updatedAt: nil)
}
```

The `UITestStubStore.save(_:)` and other methods do not construct `Recipe` literals, so they only need their `RecipeStoreProtocol` conformance to be updated in Task 8 (after the protocol grows). Leave them for now.

- [ ] **Step 6: Confirm app target builds**

```bash
xcodebuild -project FridgeChef.xcodeproj -scheme FridgeChef \
  -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`. (Tests will still fail to compile until Task 5.)

---

## Task 5: Update test call sites for new fields

**Files:**
- Modify: `FridgeChefTests/Features/RecipeDetailVMTests.swift:7`
- Modify: `FridgeChefTests/Features/RecipeBatchVMTests.swift:8,10,22`
- Modify: `FridgeChefTests/Features/CatalogVMTests.swift:30-32,56-58,76-78`
- Modify: `FridgeChefTests/Features/RecipesVMTests.swift:52`
- Modify: `FridgeChefTests/Features/SettingsVMTests.swift:44`
- Modify: `FridgeChefTests/Services/RecipeStoreTests.swift:62-76`
- Modify: `FridgeChefTests/Stubs/StubRecipeStore.swift` (only the existing methods — new ones come in Task 8)

- [ ] **Step 1: Update `RecipeStoreTests.sampleBatch` helper**

In `FridgeChefTests/Services/RecipeStoreTests.swift`, replace the `sampleBatch` private method (lines 59-77):

```swift
private func sampleBatch(ingredients: [String],
                         recipeCount: Int,
                         createdAt: Date = Date(),
                         source: RecipeSource = .ai) -> RecipeBatch {
    RecipeBatch(
        id: UUID(),
        createdAt: createdAt,
        inputIngredients: ingredients,
        inputImageThumbnailJPEG: nil,
        recipes: (0..<recipeCount).map { i in
            Recipe(id: UUID(),
                   title: "R\(i)",
                   description: "d\(i)",
                   ingredients: ["ing\(i)"],
                   steps: ["step\(i)"],
                   estimatedTime: "\(i*5) min",
                   isFavorite: false,
                   updatedAt: nil)
        },
        source: source
    )
}
```

- [ ] **Step 2: Update `RecipeDetailVMTests.test_passthrough`**

In `FridgeChefTests/Features/RecipeDetailVMTests.swift`, replace the test body:

```swift
import XCTest
@testable import FridgeChef

@MainActor
final class RecipeDetailVMTests: XCTestCase {
    func test_passthrough() {
        let r = Recipe(id: UUID(), title: "X", description: "d",
                       ingredients: ["a"], steps: ["s"], estimatedTime: "1 min",
                       isFavorite: false, updatedAt: nil)
        let store = StubRecipeStore()
        let vm = RecipeDetailVM(recipe: r, batchId: UUID(), store: store)
        XCTAssertEqual(vm.recipe.title, "X")
    }
}
```

Note: `RecipeDetailVM.init(recipe:batchId:store:)` doesn't exist yet — this test will fail to compile until Task 11. That's expected; one commit makes the whole compilation green.

- [ ] **Step 3: Update `RecipeBatchVMTests`**

In `FridgeChefTests/Features/RecipeBatchVMTests.swift`, replace both `Recipe` and `RecipeBatch` literals:

```swift
import XCTest
@testable import FridgeChef

@MainActor
final class RecipeBatchVMTests: XCTestCase {
    func test_init_populatesBatchAndRecipes() {
        let recipes = (0..<3).map { i in
            Recipe(id: UUID(), title: "T\(i)", description: "d",
                   ingredients: [], steps: [], estimatedTime: "5 min",
                   isFavorite: false, updatedAt: nil)
        }
        let batch = RecipeBatch(id: UUID(), createdAt: Date(),
                                inputIngredients: ["tomato"],
                                inputImageThumbnailJPEG: nil,
                                recipes: recipes,
                                source: .ai)
        let store = StubRecipeStore()
        let vm = RecipeBatchVM(batch: batch, store: store)
        XCTAssertEqual(vm.recipes.count, 3)
        XCTAssertEqual(vm.recipes[0].title, "T0")
        XCTAssertFalse(vm.headerDateString.isEmpty)
    }

    func test_headerDate_formatsCreatedAt() {
        let d = Date(timeIntervalSince1970: 1747584840)
        let batch = RecipeBatch(id: UUID(), createdAt: d,
                                inputIngredients: [],
                                inputImageThumbnailJPEG: nil,
                                recipes: [],
                                source: .ai)
        let store = StubRecipeStore()
        let vm = RecipeBatchVM(batch: batch, store: store)
        XCTAssertTrue(vm.headerDateString.uppercased().contains("MAY"))
    }
}
```

Note: `RecipeBatchVM.init(batch:store:)` doesn't exist yet — Task 14 makes that compile.

- [ ] **Step 4: Update `CatalogVMTests` — three `Recipe` literals**

In `FridgeChefTests/Features/CatalogVMTests.swift`, replace each of the three `Recipe(id: UUID(), ...)` literals (lines 29-32, 55-58, 75-78) by appending the new arguments. Example for the first one:

```swift
let recipes = (0..<3).map { i in
    Recipe(id: UUID(), title: "T\(i)", description: "d",
           ingredients: ["a"], steps: ["s"], estimatedTime: "10 min",
           isFavorite: false, updatedAt: nil)
}
```

Apply the same `isFavorite: false, updatedAt: nil` append to the literals at lines 55-58 and 75-78. The two anonymous `_ in` literals just need the same suffix.

- [ ] **Step 5: Update `RecipesVMTests.makeBatch`**

In `FridgeChefTests/Features/RecipesVMTests.swift`, replace lines 51-56:

```swift
private func makeBatch(date: Date) -> RecipeBatch {
    RecipeBatch(id: UUID(), createdAt: date,
                inputIngredients: ["x"],
                inputImageThumbnailJPEG: nil,
                recipes: [],
                source: .ai)
}
```

- [ ] **Step 6: Update `SettingsVMTests`**

In `FridgeChefTests/Features/SettingsVMTests.swift` line 44, replace the inline batch literal:

```swift
RecipeBatch(id: UUID(), createdAt: Date(),
            inputIngredients: [], inputImageThumbnailJPEG: nil,
            recipes: [], source: .ai)
```

- [ ] **Step 7: Update `StubRecipeStore` `save` / `allBatches` signatures only — leave new methods for Task 8**

In `FridgeChefTests/Stubs/StubRecipeStore.swift`, the existing methods don't reference `Recipe` or `RecipeBatch` literals, only the `RecipeBatch` type — so no edit is required in this task. Leave the file as is.

- [ ] **Step 8: Run app build to confirm app target still compiles**

```bash
xcodebuild -project FridgeChef.xcodeproj -scheme FridgeChef \
  -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`. Test target will still fail until VMs are updated (Tasks 11 and 14), but the app builds and runs.

- [ ] **Step 9: Commit value-type expansion + all call-site updates as one unit**

```bash
git add FridgeChef/SharedModels/Recipe.swift \
        FridgeChef/SharedModels/RecipeBatch.swift \
        FridgeChef/Services/Networking/OpenAIClient.swift \
        FridgeChef/Features/Catalog/ViewModel/CatalogVM.swift \
        FridgeChef/Services/Persistence/RecipeEntity+ext.swift \
        FridgeChef/Services/Persistence/RecipeBatchEntity+ext.swift \
        FridgeChef/App/Dependencies.swift \
        FridgeChefTests/Features/RecipeDetailVMTests.swift \
        FridgeChefTests/Features/RecipeBatchVMTests.swift \
        FridgeChefTests/Features/CatalogVMTests.swift \
        FridgeChefTests/Features/RecipesVMTests.swift \
        FridgeChefTests/Features/SettingsVMTests.swift \
        FridgeChefTests/Services/RecipeStoreTests.swift
git commit -m "feat(cookbook): extend Recipe/RecipeBatch with isFavorite, updatedAt, source"
```

---

## Task 6: Update Core Data model entity classes

**Files:**
- Modify: `FridgeChef/Services/Persistence/Entities.swift`

- [ ] **Step 1: Add the new `@NSManaged` properties**

Rewrite `FridgeChef/Services/Persistence/Entities.swift`:

```swift
import CoreData

@objc(RecipeBatchEntity)
final class RecipeBatchEntity: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var createdAt: Date?
    @NSManaged var inputIngredientsJSON: String?
    @NSManaged var inputImageThumbnailJPEG: Data?
    @NSManaged var source: String?
    @NSManaged var recipes: NSOrderedSet?

    @nonobjc class func fetchRequest() -> NSFetchRequest<RecipeBatchEntity> {
        NSFetchRequest<RecipeBatchEntity>(entityName: "RecipeBatchEntity")
    }
}

@objc(RecipeEntity)
final class RecipeEntity: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var title: String?
    @NSManaged var recipeDescription: String?
    @NSManaged var ingredientsJSON: String?
    @NSManaged var stepsJSON: String?
    @NSManaged var estimatedTime: String?
    @NSManaged var order: Int16
    @NSManaged var isFavorite: Bool
    @NSManaged var updatedAt: Date?
    @NSManaged var batch: RecipeBatchEntity?

    @nonobjc class func fetchRequest() -> NSFetchRequest<RecipeEntity> {
        NSFetchRequest<RecipeEntity>(entityName: "RecipeEntity")
    }
}
```

- [ ] **Step 2: Confirm app still builds (model file not yet updated — runtime would fail, but compile succeeds because Core Data XML is validated at load time, not compile time)**

```bash
xcodebuild -project FridgeChef.xcodeproj -scheme FridgeChef \
  -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`. Do **not** run yet — the model XML doesn't have these attributes, so `loadPersistentStores` will fatalError. Task 7 fixes that.

---

## Task 7: Add Core Data model v2

**Files:**
- Create: `FridgeChef/Services/Persistence/FridgeChef.xcdatamodeld/FridgeChef v2.xcdatamodel/contents`
- Create: `FridgeChef/Services/Persistence/FridgeChef.xcdatamodeld/.xccurrentversion`

- [ ] **Step 1: Create the v2 model directory**

```bash
mkdir -p "FridgeChef/Services/Persistence/FridgeChef.xcdatamodeld/FridgeChef v2.xcdatamodel"
```

- [ ] **Step 2: Write the v2 model contents**

Create `FridgeChef/Services/Persistence/FridgeChef.xcdatamodeld/FridgeChef v2.xcdatamodel/contents`:

```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<model type="com.apple.IDECoreDataModeler.DataModel" documentVersion="1.0" lastSavedToolsVersion="22000" systemVersion="23A344" minimumToolsVersion="Automatic" sourceLanguage="Swift" userDefinedModelVersionIdentifier="">
    <entity name="RecipeBatchEntity" representedClassName="RecipeBatchEntity" syncable="YES">
        <attribute name="id" optional="NO" attributeType="UUID" usesScalarValueType="NO"/>
        <attribute name="createdAt" optional="NO" attributeType="Date" usesScalarValueType="NO"/>
        <attribute name="inputIngredientsJSON" optional="NO" attributeType="String" defaultValueString="[]"/>
        <attribute name="inputImageThumbnailJPEG" optional="YES" attributeType="Binary" allowsExternalBinaryDataStorage="YES"/>
        <attribute name="source" optional="NO" attributeType="String" defaultValueString="ai"/>
        <relationship name="recipes" optional="YES" toMany="YES" deletionRule="Cascade" ordered="YES" destinationEntity="RecipeEntity" inverseName="batch" inverseEntity="RecipeEntity"/>
    </entity>
    <entity name="RecipeEntity" representedClassName="RecipeEntity" syncable="YES">
        <attribute name="id" optional="NO" attributeType="UUID" usesScalarValueType="NO"/>
        <attribute name="title" optional="NO" attributeType="String" defaultValueString=""/>
        <attribute name="recipeDescription" optional="NO" attributeType="String" defaultValueString=""/>
        <attribute name="ingredientsJSON" optional="NO" attributeType="String" defaultValueString="[]"/>
        <attribute name="stepsJSON" optional="NO" attributeType="String" defaultValueString="[]"/>
        <attribute name="estimatedTime" optional="NO" attributeType="String" defaultValueString=""/>
        <attribute name="order" optional="NO" attributeType="Integer 16" defaultValueString="0" usesScalarValueType="YES"/>
        <attribute name="isFavorite" optional="NO" attributeType="Boolean" defaultValueString="NO" usesScalarValueType="YES"/>
        <attribute name="updatedAt" optional="YES" attributeType="Date" usesScalarValueType="NO"/>
        <relationship name="batch" optional="YES" maxCount="1" deletionRule="Nullify" destinationEntity="RecipeBatchEntity" inverseName="recipes" inverseEntity="RecipeBatchEntity"/>
    </entity>
</model>
```

- [ ] **Step 3: Create `.xccurrentversion` plist**

Create `FridgeChef/Services/Persistence/FridgeChef.xcdatamodeld/.xccurrentversion`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>_XCCurrentVersionName</key>
    <string>FridgeChef v2.xcdatamodel</string>
</dict>
</plist>
```

- [ ] **Step 4: Regenerate Xcode project so XcodeGen picks up the new model version directory**

```bash
xcodegen generate
```

Expected output ends with `Created project at FridgeChef.xcodeproj`.

- [ ] **Step 5: Build + launch on simulator to verify model loads**

```bash
xcodebuild -project FridgeChef.xcodeproj -scheme FridgeChef \
  -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`.

Then with the simulator booted:

```bash
xcrun simctl install booted ~/Library/Developer/Xcode/DerivedData/FridgeChef-*/Build/Products/Debug-iphonesimulator/FridgeChef.app
xcrun simctl launch booted com.baha.fridgechef
```

Expected: app launches and lands on the Catalog screen without crashing. If `loadPersistentStores` fatalErrors, double-check:
- `.xccurrentversion` points to `FridgeChef v2.xcdatamodel` (with the space, no extension after `xcdatamodel`)
- both `FridgeChef.xcdatamodel/contents` (v1, unchanged) and `FridgeChef v2.xcdatamodel/contents` (v2, with new attrs) exist
- `NSPersistentContainer` does lightweight migration by default — we should NOT need to set `shouldMigrateStoreAutomatically` manually

- [ ] **Step 6: Commit entity classes + model v2 together**

```bash
git add FridgeChef/Services/Persistence/Entities.swift \
        "FridgeChef/Services/Persistence/FridgeChef.xcdatamodeld/FridgeChef v2.xcdatamodel" \
        FridgeChef/Services/Persistence/FridgeChef.xcdatamodeld/.xccurrentversion
git commit -m "feat(cookbook): add Core Data model v2 with isFavorite, updatedAt, source"
```

---

## Task 8: Add `RecipeStore` error type + 4 new protocol methods (failing tests first)

**Files:**
- Modify: `FridgeChef/Services/Persistence/RecipeStore.swift`
- Modify: `FridgeChefTests/Services/RecipeStoreTests.swift`
- Modify: `FridgeChefTests/Stubs/StubRecipeStore.swift`
- Modify: `FridgeChef/App/Dependencies.swift` (UITestStubStore must conform to expanded protocol)

### 8a — Write the failing tests first

- [ ] **Step 1: Append 5 new tests to `RecipeStoreTests`**

Add these test methods inside `RecipeStoreTests` (before the final `private func sampleBatch`):

```swift
// MARK: - update

func test_update_rewritesAllFields_andBumpsUpdatedAt() async throws {
    var batch = sampleBatch(ingredients: ["a"], recipeCount: 1)
    try await store.save(batch)
    let original = batch.recipes[0]
    let edited = Recipe(
        id: original.id,
        title: "New title",
        description: "New desc",
        ingredients: ["new1", "new2"],
        steps: ["s1", "s2", "s3"],
        estimatedTime: "12 min",
        isFavorite: original.isFavorite,
        updatedAt: original.updatedAt
    )
    try await store.update(edited, in: batch.id)

    let reloaded = try await store.batch(id: batch.id)
    let r = reloaded?.recipes.first
    XCTAssertEqual(r?.title, "New title")
    XCTAssertEqual(r?.description, "New desc")
    XCTAssertEqual(r?.ingredients, ["new1", "new2"])
    XCTAssertEqual(r?.steps, ["s1", "s2", "s3"])
    XCTAssertEqual(r?.estimatedTime, "12 min")
    XCTAssertNotNil(r?.updatedAt, "update should set updatedAt to non-nil")
}

func test_update_missingRecipe_throwsNotFound() async throws {
    let batch = sampleBatch(ingredients: ["a"], recipeCount: 1)
    try await store.save(batch)
    let bogus = Recipe(id: UUID(), title: "x", description: "",
                       ingredients: [], steps: [], estimatedTime: "",
                       isFavorite: false, updatedAt: nil)
    do {
        try await store.update(bogus, in: batch.id)
        XCTFail("Expected .notFound")
    } catch RecipeStoreError.notFound {
        // ok
    }
}

// MARK: - setFavorite

func test_setFavorite_persistsTheNewValue() async throws {
    let batch = sampleBatch(ingredients: ["a"], recipeCount: 2)
    try await store.save(batch)
    let target = batch.recipes[1]
    try await store.setFavorite(recipeId: target.id, isFavorite: true)

    let reloaded = try await store.batch(id: batch.id)
    XCTAssertEqual(reloaded?.recipes.first(where: { $0.id == target.id })?.isFavorite, true)
    XCTAssertEqual(reloaded?.recipes.first(where: { $0.id == batch.recipes[0].id })?.isFavorite, false)
}

// MARK: - delete recipe

func test_deleteRecipe_removesOnlyThatRecipe() async throws {
    let batch = sampleBatch(ingredients: ["a"], recipeCount: 3)
    try await store.save(batch)
    let middle = batch.recipes[1]

    try await store.delete(recipeId: middle.id)

    let reloaded = try await store.batch(id: batch.id)
    XCTAssertEqual(reloaded?.recipes.count, 2)
    XCTAssertFalse(reloaded?.recipes.contains(where: { $0.id == middle.id }) ?? true)
}

func test_deleteRecipe_lastInBatch_cascadesBatch() async throws {
    let batch = sampleBatch(ingredients: ["a"], recipeCount: 1)
    try await store.save(batch)

    try await store.delete(recipeId: batch.recipes[0].id)

    let reloaded = try await store.batch(id: batch.id)
    XCTAssertNil(reloaded, "deleting the last recipe in a batch should cascade-delete the batch")
}

// MARK: - delete batch

func test_deleteBatch_removesBatchAndAllRecipes() async throws {
    let batch = sampleBatch(ingredients: ["a"], recipeCount: 3)
    try await store.save(batch)

    try await store.delete(batchId: batch.id)

    let reloaded = try await store.batch(id: batch.id)
    XCTAssertNil(reloaded)
    // and there are no orphaned recipes: the entire all-batches list is empty
    let all = try await store.allBatches()
    XCTAssertEqual(all, [])
}
```

- [ ] **Step 2: Run the new tests — expect compile error first (RecipeStoreError + methods undefined)**

```bash
xcodebuild -project FridgeChef.xcodeproj -scheme FridgeChef \
  -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:FridgeChefTests/RecipeStoreTests 2>&1 | grep -E "error:|FAIL" | head -20
```

Expected: errors like `cannot find 'RecipeStoreError' in scope`, `value of type 'RecipeStore' has no member 'update'`, etc.

### 8b — Add the protocol + error type

- [ ] **Step 3: Rewrite `RecipeStore.swift` with error type, expanded protocol, and implementations**

Rewrite `FridgeChef/Services/Persistence/RecipeStore.swift`:

```swift
import CoreData
import Foundation

enum RecipeStoreError: Error, LocalizedError {
    case notFound

    var errorDescription: String? {
        switch self {
        case .notFound: return "Recipe or batch not found."
        }
    }
}

protocol RecipeStoreProtocol {
    func save(_ batch: RecipeBatch) async throws
    func allBatches() async throws -> [RecipeBatch]
    func batch(id: UUID) async throws -> RecipeBatch?
    func deleteAll() async throws

    func update(_ recipe: Recipe, in batchId: UUID) async throws
    func setFavorite(recipeId: UUID, isFavorite: Bool) async throws
    func delete(recipeId: UUID) async throws
    func delete(batchId: UUID) async throws
}

final class RecipeStore: RecipeStoreProtocol {
    private let stack: CoreDataStack

    init(stack: CoreDataStack) {
        self.stack = stack
    }

    func save(_ batch: RecipeBatch) async throws {
        let ctx = stack.newBackgroundContext()
        try await ctx.perform {
            _ = RecipeBatchEntity.create(from: batch, in: ctx)
            try ctx.save()
        }
        postChanged()
    }

    func allBatches() async throws -> [RecipeBatch] {
        let ctx = stack.newBackgroundContext()
        return try await ctx.perform {
            let req: NSFetchRequest<RecipeBatchEntity> = RecipeBatchEntity.fetchRequest()
            req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            let entities = try ctx.fetch(req)
            return entities.map(\.asBatch)
        }
    }

    func batch(id: UUID) async throws -> RecipeBatch? {
        let ctx = stack.newBackgroundContext()
        return try await ctx.perform {
            let req: NSFetchRequest<RecipeBatchEntity> = RecipeBatchEntity.fetchRequest()
            req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            req.fetchLimit = 1
            return try ctx.fetch(req).first?.asBatch
        }
    }

    func deleteAll() async throws {
        // NSBatchDeleteRequest doesn't support NSInMemoryStoreType, so iterate.
        let ctx = stack.newBackgroundContext()
        try await ctx.perform {
            let req: NSFetchRequest<RecipeBatchEntity> = RecipeBatchEntity.fetchRequest()
            let all = try ctx.fetch(req)
            for entity in all { ctx.delete(entity) }
            try ctx.save()
        }
        postChanged()
    }

    func update(_ recipe: Recipe, in batchId: UUID) async throws {
        let ctx = stack.newBackgroundContext()
        try await ctx.perform {
            let req: NSFetchRequest<RecipeEntity> = RecipeEntity.fetchRequest()
            req.predicate = NSPredicate(format: "id == %@", recipe.id as CVarArg)
            req.fetchLimit = 1
            guard let entity = try ctx.fetch(req).first,
                  entity.batch?.id == batchId else {
                throw RecipeStoreError.notFound
            }
            entity.title = recipe.title
            entity.recipeDescription = recipe.description
            entity.ingredientsJSON = encodeJSONArray(recipe.ingredients)
            entity.stepsJSON = encodeJSONArray(recipe.steps)
            entity.estimatedTime = recipe.estimatedTime
            entity.updatedAt = Date()
            try ctx.save()
        }
        postChanged()
    }

    func setFavorite(recipeId: UUID, isFavorite: Bool) async throws {
        let ctx = stack.newBackgroundContext()
        try await ctx.perform {
            let req: NSFetchRequest<RecipeEntity> = RecipeEntity.fetchRequest()
            req.predicate = NSPredicate(format: "id == %@", recipeId as CVarArg)
            req.fetchLimit = 1
            guard let entity = try ctx.fetch(req).first else {
                throw RecipeStoreError.notFound
            }
            entity.isFavorite = isFavorite
            try ctx.save()
        }
        postChanged()
    }

    func delete(recipeId: UUID) async throws {
        let ctx = stack.newBackgroundContext()
        try await ctx.perform {
            let req: NSFetchRequest<RecipeEntity> = RecipeEntity.fetchRequest()
            req.predicate = NSPredicate(format: "id == %@", recipeId as CVarArg)
            req.fetchLimit = 1
            guard let entity = try ctx.fetch(req).first else {
                throw RecipeStoreError.notFound
            }
            let parent = entity.batch
            ctx.delete(entity)
            // Cascade rule: if parent batch becomes empty after this delete, remove it too.
            if let parent {
                let remaining = (parent.recipes?.count ?? 0) - 1
                if remaining <= 0 {
                    ctx.delete(parent)
                }
            }
            try ctx.save()
        }
        postChanged()
    }

    func delete(batchId: UUID) async throws {
        let ctx = stack.newBackgroundContext()
        try await ctx.perform {
            let req: NSFetchRequest<RecipeBatchEntity> = RecipeBatchEntity.fetchRequest()
            req.predicate = NSPredicate(format: "id == %@", batchId as CVarArg)
            req.fetchLimit = 1
            guard let entity = try ctx.fetch(req).first else {
                throw RecipeStoreError.notFound
            }
            ctx.delete(entity) // child recipes cascade via the Cascade deletion rule on the relationship
            try ctx.save()
        }
        postChanged()
    }

    private func postChanged() {
        NotificationCenter.default.post(name: .recipesDidChange, object: nil)
    }
}
```

### 8c — Update `StubRecipeStore` to conform

- [ ] **Step 4: Rewrite `StubRecipeStore` with capture arrays for the new methods**

Rewrite `FridgeChefTests/Stubs/StubRecipeStore.swift`:

```swift
import Foundation
@testable import FridgeChef

final class StubRecipeStore: RecipeStoreProtocol {
    var batches: [RecipeBatch] = []
    var saveError: Error?
    var nextError: Error?

    var updateCalls: [(recipe: Recipe, batchId: UUID)] = []
    var setFavoriteCalls: [(recipeId: UUID, isFavorite: Bool)] = []
    var deleteRecipeCalls: [UUID] = []
    var deleteBatchCalls: [UUID] = []

    func save(_ batch: RecipeBatch) async throws {
        if let saveError { throw saveError }
        batches.insert(batch, at: 0)
    }

    func allBatches() async throws -> [RecipeBatch] { batches }

    func batch(id: UUID) async throws -> RecipeBatch? {
        batches.first { $0.id == id }
    }

    func deleteAll() async throws { batches = [] }

    func update(_ recipe: Recipe, in batchId: UUID) async throws {
        if let nextError { throw nextError }
        updateCalls.append((recipe, batchId))
        guard let bIdx = batches.firstIndex(where: { $0.id == batchId }) else {
            throw RecipeStoreError.notFound
        }
        let b = batches[bIdx]
        guard let rIdx = b.recipes.firstIndex(where: { $0.id == recipe.id }) else {
            throw RecipeStoreError.notFound
        }
        var updated = b.recipes
        updated[rIdx] = Recipe(
            id: recipe.id,
            title: recipe.title,
            description: recipe.description,
            ingredients: recipe.ingredients,
            steps: recipe.steps,
            estimatedTime: recipe.estimatedTime,
            isFavorite: recipe.isFavorite,
            updatedAt: Date()
        )
        batches[bIdx] = RecipeBatch(
            id: b.id, createdAt: b.createdAt,
            inputIngredients: b.inputIngredients,
            inputImageThumbnailJPEG: b.inputImageThumbnailJPEG,
            recipes: updated, source: b.source
        )
    }

    func setFavorite(recipeId: UUID, isFavorite: Bool) async throws {
        if let nextError { throw nextError }
        setFavoriteCalls.append((recipeId, isFavorite))
        for (bIdx, b) in batches.enumerated() {
            if let rIdx = b.recipes.firstIndex(where: { $0.id == recipeId }) {
                var updated = b.recipes
                let r = updated[rIdx]
                updated[rIdx] = Recipe(
                    id: r.id, title: r.title, description: r.description,
                    ingredients: r.ingredients, steps: r.steps,
                    estimatedTime: r.estimatedTime,
                    isFavorite: isFavorite, updatedAt: r.updatedAt
                )
                batches[bIdx] = RecipeBatch(
                    id: b.id, createdAt: b.createdAt,
                    inputIngredients: b.inputIngredients,
                    inputImageThumbnailJPEG: b.inputImageThumbnailJPEG,
                    recipes: updated, source: b.source
                )
                return
            }
        }
        throw RecipeStoreError.notFound
    }

    func delete(recipeId: UUID) async throws {
        if let nextError { throw nextError }
        deleteRecipeCalls.append(recipeId)
        for (bIdx, b) in batches.enumerated() {
            if let rIdx = b.recipes.firstIndex(where: { $0.id == recipeId }) {
                var updated = b.recipes
                updated.remove(at: rIdx)
                if updated.isEmpty {
                    batches.remove(at: bIdx)
                } else {
                    batches[bIdx] = RecipeBatch(
                        id: b.id, createdAt: b.createdAt,
                        inputIngredients: b.inputIngredients,
                        inputImageThumbnailJPEG: b.inputImageThumbnailJPEG,
                        recipes: updated, source: b.source
                    )
                }
                return
            }
        }
        throw RecipeStoreError.notFound
    }

    func delete(batchId: UUID) async throws {
        if let nextError { throw nextError }
        deleteBatchCalls.append(batchId)
        guard let idx = batches.firstIndex(where: { $0.id == batchId }) else {
            throw RecipeStoreError.notFound
        }
        batches.remove(at: idx)
    }
}
```

### 8d — Update the `UITestStubStore` in `Dependencies.swift`

- [ ] **Step 5: Add the 4 new no-op methods to `UITestStubStore`**

In `FridgeChef/App/Dependencies.swift`, replace the `private final class UITestStubStore` definition:

```swift
private final class UITestStubStore: RecipeStoreProtocol {
    private var batches: [RecipeBatch] = []
    func save(_ batch: RecipeBatch) async throws { batches.insert(batch, at: 0) }
    func allBatches() async throws -> [RecipeBatch] { batches }
    func batch(id: UUID) async throws -> RecipeBatch? { batches.first { $0.id == id } }
    func deleteAll() async throws { batches = [] }
    func update(_ recipe: Recipe, in batchId: UUID) async throws { /* no-op for UI tests */ }
    func setFavorite(recipeId: UUID, isFavorite: Bool) async throws { /* no-op */ }
    func delete(recipeId: UUID) async throws { /* no-op */ }
    func delete(batchId: UUID) async throws { /* no-op */ }
}
```

### 8e — Run + commit

- [ ] **Step 6: Run the RecipeStore tests; expect green**

```bash
xcodebuild -project FridgeChef.xcodeproj -scheme FridgeChef \
  -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:FridgeChefTests/RecipeStoreTests 2>&1 | tail -20
```

Expected: 10 tests pass (5 existing + 5 new).

- [ ] **Step 7: Commit**

```bash
git add FridgeChef/Services/Persistence/RecipeStore.swift \
        FridgeChef/App/Dependencies.swift \
        FridgeChefTests/Stubs/StubRecipeStore.swift \
        FridgeChefTests/Services/RecipeStoreTests.swift
git commit -m "feat(cookbook): RecipeStore update/setFavorite/delete with notFound"
```

---

## Task 9: `CreateEditRecipeVM` — failing tests first

**Files:**
- Create: `FridgeChefTests/Features/CreateEditRecipeVMTests.swift`

- [ ] **Step 1: Write all 6 failing tests for the new VM**

Create `FridgeChefTests/Features/CreateEditRecipeVMTests.swift`:

```swift
import XCTest
import Combine
@testable import FridgeChef

@MainActor
final class CreateEditRecipeVMTests: XCTestCase {

    private var store: StubRecipeStore!

    override func setUp() {
        super.setUp()
        store = StubRecipeStore()
    }

    func test_init_newMode_hasEmptyFields_andIsInvalid() {
        let vm = CreateEditRecipeVM(mode: .new, store: store)
        XCTAssertEqual(vm.title, "")
        XCTAssertEqual(vm.descriptionText, "")
        XCTAssertEqual(vm.ingredients, [""])
        XCTAssertEqual(vm.steps, [""])
        XCTAssertEqual(vm.estimatedTime, "")
        XCTAssertFalse(vm.isValid)
    }

    func test_init_editMode_prefillsFromRecipe_andIsValid() {
        let r = Recipe(id: UUID(), title: "Existing",
                       description: "d",
                       ingredients: ["a", "b"], steps: ["s1"],
                       estimatedTime: "10 min",
                       isFavorite: false, updatedAt: nil)
        let vm = CreateEditRecipeVM(mode: .edit(existing: r, batchId: UUID()), store: store)
        XCTAssertEqual(vm.title, "Existing")
        XCTAssertEqual(vm.descriptionText, "d")
        XCTAssertEqual(vm.ingredients, ["a", "b"])
        XCTAssertEqual(vm.steps, ["s1"])
        XCTAssertEqual(vm.estimatedTime, "10 min")
        XCTAssertTrue(vm.isValid)
    }

    func test_validation_requiresTitle_oneIngredient_oneStep() async {
        let vm = CreateEditRecipeVM(mode: .new, store: store)
        XCTAssertFalse(vm.isValid)

        vm.title = "Pancakes"
        await Task.yield()
        XCTAssertFalse(vm.isValid, "title alone is not enough")

        vm.ingredients = ["flour"]
        await Task.yield()
        XCTAssertFalse(vm.isValid, "title + ingredient still missing a step")

        vm.steps = ["mix and cook"]
        await Task.yield()
        XCTAssertTrue(vm.isValid, "title + ingredient + step is the minimum")

        vm.title = "   "
        await Task.yield()
        XCTAssertFalse(vm.isValid, "whitespace-only title should invalidate")
    }

    func test_save_newMode_callsSave_withSourceUser_oneRecipe_andStripsEmpty() async {
        let vm = CreateEditRecipeVM(mode: .new, store: store)
        vm.title = "Pancakes"
        vm.descriptionText = "Fluffy"
        vm.ingredients = ["flour", "", "milk"]
        vm.steps = ["mix", ""]
        vm.estimatedTime = "20 min"

        await vm.save()

        XCTAssertEqual(store.batches.count, 1)
        let b = store.batches[0]
        XCTAssertEqual(b.source, .user)
        XCTAssertEqual(b.recipes.count, 1)
        let r = b.recipes[0]
        XCTAssertEqual(r.title, "Pancakes")
        XCTAssertEqual(r.ingredients, ["flour", "milk"])
        XCTAssertEqual(r.steps, ["mix"])
    }

    func test_save_editMode_callsUpdate_withEditedFields() async {
        let existing = Recipe(id: UUID(), title: "Old",
                              description: "od",
                              ingredients: ["x"], steps: ["y"],
                              estimatedTime: "5 min",
                              isFavorite: true, updatedAt: nil)
        let batchId = UUID()
        // Seed the store so the stub's update() finds the row
        store.batches = [RecipeBatch(id: batchId, createdAt: Date(),
                                     inputIngredients: [], inputImageThumbnailJPEG: nil,
                                     recipes: [existing], source: .user)]

        let vm = CreateEditRecipeVM(mode: .edit(existing: existing, batchId: batchId), store: store)
        vm.title = "Updated"

        await vm.save()

        XCTAssertEqual(store.updateCalls.count, 1)
        XCTAssertEqual(store.updateCalls[0].recipe.title, "Updated")
        XCTAssertEqual(store.updateCalls[0].batchId, batchId)
    }

    func test_save_storeThrows_setsErrorState_andLeavesFieldsIntact() async {
        struct Boom: LocalizedError { var errorDescription: String? { "boom" } }
        store.saveError = Boom()
        let vm = CreateEditRecipeVM(mode: .new, store: store)
        vm.title = "X"
        vm.ingredients = ["a"]
        vm.steps = ["s"]

        await vm.save()

        if case .error(let msg) = vm.saveState {
            XCTAssertEqual(msg, "boom")
        } else {
            XCTFail("expected .error, got \(vm.saveState)")
        }
        XCTAssertEqual(vm.title, "X", "fields must remain after a failed save")
        XCTAssertEqual(vm.ingredients, ["a"])
        XCTAssertEqual(vm.steps, ["s"])
    }
}
```

- [ ] **Step 2: Run the new test file — expect a compile error because `CreateEditRecipeVM` doesn't exist yet**

```bash
xcodebuild -project FridgeChef.xcodeproj -scheme FridgeChef \
  -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:FridgeChefTests/CreateEditRecipeVMTests 2>&1 | grep -E "error:" | head -10
```

Expected: `cannot find 'CreateEditRecipeVM' in scope`.

---

## Task 10: Implement `CreateEditRecipeVM`

**Files:**
- Create: `FridgeChef/Features/CreateEditRecipe/ViewModel/CreateEditRecipeVM.swift`

- [ ] **Step 1: Create the VM**

Create `FridgeChef/Features/CreateEditRecipe/ViewModel/CreateEditRecipeVM.swift`:

```swift
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
            .receive(on: DispatchQueue.main)
            .assign(to: &$isValid)
    }

    // MARK: - row mutations

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

    // MARK: - save

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
                    updatedAt: nil // store sets actual timestamp
                )
                try await store.update(updated, in: batchId)
                saveState = .saved(updated)
            }
        } catch {
            saveState = .error(error.localizedDescription)
        }
    }
}
```

- [ ] **Step 2: Run the new tests; expect green**

```bash
xcodebuild -project FridgeChef.xcodeproj -scheme FridgeChef \
  -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:FridgeChefTests/CreateEditRecipeVMTests 2>&1 | tail -20
```

Expected: 6 tests pass.

- [ ] **Step 3: Commit**

```bash
xcodegen generate
git add FridgeChef/Features/CreateEditRecipe/ViewModel/CreateEditRecipeVM.swift \
        FridgeChefTests/Features/CreateEditRecipeVMTests.swift
git commit -m "feat(cookbook): CreateEditRecipeVM with new/edit modes + validation"
```

---

## Task 11: `RecipeDetailVM` extensions + tests

**Files:**
- Modify: `FridgeChef/Features/RecipeDetail/ViewModel/RecipeDetailVM.swift`
- Modify: `FridgeChefTests/Features/RecipeDetailVMTests.swift`

### 11a — Failing tests first

- [ ] **Step 1: Rewrite the test file with 3 tests (1 existing kept + 2 new)**

Rewrite `FridgeChefTests/Features/RecipeDetailVMTests.swift`:

```swift
import XCTest
import Combine
@testable import FridgeChef

@MainActor
final class RecipeDetailVMTests: XCTestCase {

    func test_passthrough() {
        let r = Recipe(id: UUID(), title: "X", description: "d",
                       ingredients: ["a"], steps: ["s"], estimatedTime: "1 min",
                       isFavorite: false, updatedAt: nil)
        let store = StubRecipeStore()
        let vm = RecipeDetailVM(recipe: r, batchId: UUID(), store: store)
        XCTAssertEqual(vm.recipe.title, "X")
        XCTAssertFalse(vm.isFavorite)
    }

    func test_toggleFavorite_flipsState_andPersists() async {
        let r = Recipe(id: UUID(), title: "X", description: "d",
                       ingredients: ["a"], steps: ["s"], estimatedTime: "1 min",
                       isFavorite: false, updatedAt: nil)
        let store = StubRecipeStore()
        store.batches = [RecipeBatch(id: UUID(), createdAt: Date(),
                                     inputIngredients: [], inputImageThumbnailJPEG: nil,
                                     recipes: [r], source: .ai)]
        let vm = RecipeDetailVM(recipe: r, batchId: store.batches[0].id, store: store)

        await vm.toggleFavorite()
        XCTAssertTrue(vm.isFavorite)
        XCTAssertEqual(store.setFavoriteCalls.count, 1)
        XCTAssertEqual(store.setFavoriteCalls[0].recipeId, r.id)
        XCTAssertEqual(store.setFavoriteCalls[0].isFavorite, true)
    }

    func test_toggleFavorite_storeThrows_revertsAndSetsError() async {
        struct Boom: LocalizedError { var errorDescription: String? { "boom" } }
        let r = Recipe(id: UUID(), title: "X", description: "d",
                       ingredients: ["a"], steps: ["s"], estimatedTime: "1 min",
                       isFavorite: false, updatedAt: nil)
        let store = StubRecipeStore()
        store.nextError = Boom()
        let vm = RecipeDetailVM(recipe: r, batchId: UUID(), store: store)

        await vm.toggleFavorite()

        XCTAssertFalse(vm.isFavorite, "state must revert on error")
        XCTAssertEqual(vm.lastError, "boom")
    }
}
```

- [ ] **Step 2: Run — expect compile error (new init, new methods undefined)**

```bash
xcodebuild -project FridgeChef.xcodeproj -scheme FridgeChef \
  -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:FridgeChefTests/RecipeDetailVMTests 2>&1 | grep -E "error:" | head -10
```

Expected: errors about unknown labels `batchId:` / `store:`, missing `isFavorite`, etc.

### 11b — Implement the VM

- [ ] **Step 3: Rewrite `RecipeDetailVM.swift`**

Rewrite `FridgeChef/Features/RecipeDetail/ViewModel/RecipeDetailVM.swift`:

```swift
import Foundation
import Combine

@MainActor
final class RecipeDetailVM {

    @Published private(set) var recipe: Recipe
    @Published private(set) var isFavorite: Bool
    @Published private(set) var lastError: String?

    let batchId: UUID
    private let store: RecipeStoreProtocol
    private var notificationToken: NSObjectProtocol?

    init(recipe: Recipe, batchId: UUID, store: RecipeStoreProtocol) {
        self.recipe = recipe
        self.isFavorite = recipe.isFavorite
        self.batchId = batchId
        self.store = store
        notificationToken = NotificationCenter.default.addObserver(
            forName: .recipesDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            Task { await self?.reload() }
        }
    }

    deinit {
        if let t = notificationToken { NotificationCenter.default.removeObserver(t) }
    }

    func toggleFavorite() async {
        let newValue = !isFavorite
        isFavorite = newValue            // optimistic
        do {
            try await store.setFavorite(recipeId: recipe.id, isFavorite: newValue)
        } catch {
            isFavorite = !newValue        // revert
            lastError = error.localizedDescription
        }
    }

    func clearError() { lastError = nil }

    private func reload() async {
        guard let batch = try? await store.batch(id: batchId),
              let updated = batch.recipes.first(where: { $0.id == recipe.id }) else { return }
        recipe = updated
        isFavorite = updated.isFavorite
    }
}
```

- [ ] **Step 4: Run tests — expect green**

```bash
xcodebuild -project FridgeChef.xcodeproj -scheme FridgeChef \
  -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:FridgeChefTests/RecipeDetailVMTests 2>&1 | tail -10
```

Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add FridgeChef/Features/RecipeDetail/ViewModel/RecipeDetailVM.swift \
        FridgeChefTests/Features/RecipeDetailVMTests.swift
git commit -m "feat(cookbook): RecipeDetailVM toggleFavorite + reload on change"
```

---

## Task 12: `RecipeBatchVM` extensions + tests

**Files:**
- Modify: `FridgeChef/Features/RecipeBatch/ViewModel/RecipeBatchVM.swift`
- Modify: `FridgeChefTests/Features/RecipeBatchVMTests.swift`

### 12a — Failing tests first

- [ ] **Step 1: Append 2 new tests to `RecipeBatchVMTests`**

Rewrite `FridgeChefTests/Features/RecipeBatchVMTests.swift`:

```swift
import XCTest
@testable import FridgeChef

@MainActor
final class RecipeBatchVMTests: XCTestCase {

    private func makeRecipes(_ n: Int) -> [Recipe] {
        (0..<n).map { i in
            Recipe(id: UUID(), title: "T\(i)", description: "d",
                   ingredients: [], steps: [], estimatedTime: "5 min",
                   isFavorite: false, updatedAt: nil)
        }
    }

    func test_init_populatesBatchAndRecipes() {
        let recipes = makeRecipes(3)
        let batch = RecipeBatch(id: UUID(), createdAt: Date(),
                                inputIngredients: ["tomato"],
                                inputImageThumbnailJPEG: nil,
                                recipes: recipes, source: .ai)
        let store = StubRecipeStore()
        let vm = RecipeBatchVM(batch: batch, store: store)
        XCTAssertEqual(vm.recipes.count, 3)
        XCTAssertEqual(vm.recipes[0].title, "T0")
        XCTAssertFalse(vm.headerDateString.isEmpty)
    }

    func test_headerDate_formatsCreatedAt() {
        let d = Date(timeIntervalSince1970: 1747584840)
        let batch = RecipeBatch(id: UUID(), createdAt: d,
                                inputIngredients: [],
                                inputImageThumbnailJPEG: nil,
                                recipes: [], source: .ai)
        let store = StubRecipeStore()
        let vm = RecipeBatchVM(batch: batch, store: store)
        XCTAssertTrue(vm.headerDateString.uppercased().contains("MAY"))
    }

    func test_deleteRecipe_partial_keepsBatchLoadedWithRemainingRecipes() async {
        let recipes = makeRecipes(3)
        let batch = RecipeBatch(id: UUID(), createdAt: Date(),
                                inputIngredients: [],
                                inputImageThumbnailJPEG: nil,
                                recipes: recipes, source: .ai)
        let store = StubRecipeStore()
        store.batches = [batch]
        let vm = RecipeBatchVM(batch: batch, store: store)

        await vm.deleteRecipe(id: recipes[1].id)

        XCTAssertEqual(store.deleteRecipeCalls, [recipes[1].id])
        XCTAssertEqual(vm.recipes.count, 2)
        if case .gone = vm.batchState { XCTFail("Should still be loaded") }
    }

    func test_deleteRecipe_last_transitionsToGone() async {
        let recipes = makeRecipes(1)
        let batch = RecipeBatch(id: UUID(), createdAt: Date(),
                                inputIngredients: [],
                                inputImageThumbnailJPEG: nil,
                                recipes: recipes, source: .user)
        let store = StubRecipeStore()
        store.batches = [batch]
        let vm = RecipeBatchVM(batch: batch, store: store)

        await vm.deleteRecipe(id: recipes[0].id)

        if case .gone = vm.batchState {} else {
            XCTFail("Expected .gone after deleting the last recipe; got \(vm.batchState)")
        }
    }
}
```

- [ ] **Step 2: Run — expect compile error (`store:` label, `deleteRecipe`, `batchState` undefined)**

```bash
xcodebuild -project FridgeChef.xcodeproj -scheme FridgeChef \
  -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:FridgeChefTests/RecipeBatchVMTests 2>&1 | grep -E "error:" | head -10
```

### 12b — Implement the VM

- [ ] **Step 3: Rewrite `RecipeBatchVM.swift`**

Rewrite `FridgeChef/Features/RecipeBatch/ViewModel/RecipeBatchVM.swift`:

```swift
import Foundation
import Combine

@MainActor
final class RecipeBatchVM {

    enum BatchState: Equatable {
        case loaded(RecipeBatch)
        case gone
    }

    @Published private(set) var batchState: BatchState

    let store: RecipeStoreProtocol
    let initialBatchId: UUID

    init(batch: RecipeBatch, store: RecipeStoreProtocol) {
        self.batchState = .loaded(batch)
        self.initialBatchId = batch.id
        self.store = store
    }

    var currentBatch: RecipeBatch? {
        if case .loaded(let b) = batchState { return b } else { return nil }
    }
    var recipes: [Recipe] { currentBatch?.recipes ?? [] }

    var headerDateString: String {
        guard let b = currentBatch else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d · h:mm a"
        return fmt.string(from: b.createdAt).uppercased()
    }

    func deleteRecipe(id: UUID) async {
        do {
            try await store.delete(recipeId: id)
            if let refreshed = try await store.batch(id: initialBatchId) {
                batchState = .loaded(refreshed)
            } else {
                batchState = .gone
            }
        } catch {
            // Surface error to the VC by re-throwing through a dedicated state if needed.
            // Phase 1: VC shows a generic alert in the catch path; VM stays in current state.
        }
    }
}
```

- [ ] **Step 4: Run tests — expect green**

```bash
xcodebuild -project FridgeChef.xcodeproj -scheme FridgeChef \
  -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:FridgeChefTests/RecipeBatchVMTests 2>&1 | tail -10
```

Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add FridgeChef/Features/RecipeBatch/ViewModel/RecipeBatchVM.swift \
        FridgeChefTests/Features/RecipeBatchVMTests.swift
git commit -m "feat(cookbook): RecipeBatchVM deleteRecipe with cascade-aware state"
```

---

## Task 13: `RecipesVM` filter + deleteBatch + tests

**Files:**
- Modify: `FridgeChef/Features/Recipes/ViewModel/RecipesVM.swift`
- Modify: `FridgeChefTests/Features/RecipesVMTests.swift`

### 13a — Failing tests first

- [ ] **Step 1: Append 2 new tests to `RecipesVMTests`**

Rewrite `FridgeChefTests/Features/RecipesVMTests.swift`:

```swift
import XCTest
import Combine
@testable import FridgeChef

@MainActor
final class RecipesVMTests: XCTestCase {

    private var store: StubRecipeStore!
    private var vm: RecipesVM!

    override func setUp() {
        super.setUp()
        store = StubRecipeStore()
        vm = RecipesVM(store: store, calendar: .current, now: { Date(timeIntervalSince1970: 1747584840) })
    }

    func test_load_emptyStore_emitsEmptyGroups() async {
        await vm.load()
        XCTAssertEqual(vm.groups, [])
        XCTAssertEqual(vm.visibleGroups, [])
    }

    func test_load_groupsBatchesByRelativeDate() async {
        let now = Date(timeIntervalSince1970: 1747584840)
        let today = now.addingTimeInterval(-3600)
        let yesterday = now.addingTimeInterval(-90_000)
        let lastWeek = now.addingTimeInterval(-3 * 86_400)
        store.batches = [
            makeBatch(date: today),
            makeBatch(date: yesterday),
            makeBatch(date: lastWeek),
        ]
        await vm.load()
        let titles = vm.groups.map(\.title)
        XCTAssertEqual(titles.first, "TODAY")
        XCTAssertTrue(titles.contains("YESTERDAY"))
        XCTAssertTrue(titles.contains("THIS WEEK"))
    }

    func test_reload_onNotification() async {
        store.batches = [makeBatch(date: Date(timeIntervalSince1970: 1747584000))]
        await vm.load()
        XCTAssertEqual(vm.groups.flatMap(\.items).count, 1)

        store.batches = []
        NotificationCenter.default.post(name: .recipesDidChange, object: nil)
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(vm.groups, [])
    }

    func test_filterFavorites_dropsBatchesWithoutFavorites_andTrimsRecipes() async {
        let r1 = makeRecipe(fav: false, title: "A")
        let r2 = makeRecipe(fav: true,  title: "B")
        let r3 = makeRecipe(fav: false, title: "C")
        let withFav = RecipeBatch(id: UUID(), createdAt: Date(timeIntervalSince1970: 1747584000),
                                  inputIngredients: [], inputImageThumbnailJPEG: nil,
                                  recipes: [r1, r2], source: .ai)
        let withoutFav = RecipeBatch(id: UUID(), createdAt: Date(timeIntervalSince1970: 1747570000),
                                     inputIngredients: [], inputImageThumbnailJPEG: nil,
                                     recipes: [r3], source: .ai)
        store.batches = [withFav, withoutFav]
        await vm.load()

        vm.filter = .favorites
        try? await Task.sleep(nanoseconds: 100_000_000)

        let allRecipes = vm.visibleGroups.flatMap { $0.items.flatMap(\.recipes) }
        XCTAssertEqual(allRecipes.count, 1)
        XCTAssertEqual(allRecipes.first?.title, "B")
    }

    func test_filterAll_visibleEqualsGroups() async {
        store.batches = [
            RecipeBatch(id: UUID(), createdAt: Date(timeIntervalSince1970: 1747584000),
                        inputIngredients: [], inputImageThumbnailJPEG: nil,
                        recipes: [makeRecipe(fav: false, title: "A"),
                                  makeRecipe(fav: true,  title: "B")],
                        source: .ai)
        ]
        await vm.load()
        vm.filter = .all
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(vm.visibleGroups, vm.groups)
    }

    func test_deleteBatch_callsStore_andReloads() async {
        let b = makeBatch(date: Date(timeIntervalSince1970: 1747584000))
        store.batches = [b]
        await vm.load()

        await vm.deleteBatch(id: b.id)

        XCTAssertEqual(store.deleteBatchCalls, [b.id])
    }

    // MARK: - helpers
    private func makeRecipe(fav: Bool, title: String) -> Recipe {
        Recipe(id: UUID(), title: title, description: "",
               ingredients: ["a"], steps: ["s"], estimatedTime: "5 min",
               isFavorite: fav, updatedAt: nil)
    }
    private func makeBatch(date: Date) -> RecipeBatch {
        RecipeBatch(id: UUID(), createdAt: date,
                    inputIngredients: ["x"],
                    inputImageThumbnailJPEG: nil,
                    recipes: [],
                    source: .ai)
    }
}
```

- [ ] **Step 2: Run — expect compile error (`filter`, `visibleGroups`, `deleteBatch` undefined)**

```bash
xcodebuild -project FridgeChef.xcodeproj -scheme FridgeChef \
  -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:FridgeChefTests/RecipesVMTests 2>&1 | grep -E "error:" | head -10
```

### 13b — Implement the VM changes

- [ ] **Step 3: Rewrite `RecipesVM.swift`**

Rewrite `FridgeChef/Features/Recipes/ViewModel/RecipesVM.swift`:

```swift
import Foundation
import Combine

@MainActor
final class RecipesVM {

    enum Filter: Equatable { case all, favorites }

    struct Group: Equatable {
        let title: String
        let items: [RecipeBatch]
    }

    @Published private(set) var groups: [Group] = []
    @Published var filter: Filter = .all
    @Published private(set) var visibleGroups: [Group] = []

    let store: RecipeStoreProtocol
    private let calendar: Calendar
    private let now: () -> Date
    private var notificationToken: NSObjectProtocol?
    private var cancellables = Set<AnyCancellable>()

    init(store: RecipeStoreProtocol,
         calendar: Calendar = .current,
         now: @escaping () -> Date = Date.init) {
        self.store = store
        self.calendar = calendar
        self.now = now
        notificationToken = NotificationCenter.default.addObserver(
            forName: .recipesDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            Task { await self?.load() }
        }
        Publishers.CombineLatest($groups, $filter)
            .map { groups, filter in Self.apply(filter: filter, to: groups) }
            .receive(on: DispatchQueue.main)
            .assign(to: &$visibleGroups)
    }

    deinit { if let t = notificationToken { NotificationCenter.default.removeObserver(t) } }

    func load() async {
        let batches = (try? await store.allBatches()) ?? []
        groups = Self.group(batches: batches, calendar: calendar, now: now())
    }

    func deleteBatch(id: UUID) async {
        do {
            try await store.delete(batchId: id)
            // load() will run via the .recipesDidChange notification.
        } catch {
            // Phase 1: silently ignore — VC also pops a generic alert via its own catch path if needed.
        }
    }

    static func apply(filter: Filter, to groups: [Group]) -> [Group] {
        switch filter {
        case .all: return groups
        case .favorites:
            return groups.compactMap { g in
                let trimmed: [RecipeBatch] = g.items.compactMap { batch in
                    let favs = batch.recipes.filter(\.isFavorite)
                    guard !favs.isEmpty else { return nil }
                    return RecipeBatch(id: batch.id,
                                       createdAt: batch.createdAt,
                                       inputIngredients: batch.inputIngredients,
                                       inputImageThumbnailJPEG: batch.inputImageThumbnailJPEG,
                                       recipes: favs,
                                       source: batch.source)
                }
                guard !trimmed.isEmpty else { return nil }
                return Group(title: g.title, items: trimmed)
            }
        }
    }

    static func group(batches: [RecipeBatch], calendar: Calendar, now: Date) -> [Group] {
        guard !batches.isEmpty else { return [] }
        let startOfToday = calendar.startOfDay(for: now)
        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday)!
        let startOfWeek = calendar.date(byAdding: .day, value: -7, to: startOfToday)!

        var buckets: [String: [RecipeBatch]] = [:]
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM yyyy"

        for batch in batches {
            let key: String
            if batch.createdAt >= startOfToday { key = "TODAY" }
            else if batch.createdAt >= startOfYesterday { key = "YESTERDAY" }
            else if batch.createdAt >= startOfWeek { key = "THIS WEEK" }
            else { key = monthFormatter.string(from: batch.createdAt).uppercased() }
            buckets[key, default: []].append(batch)
        }

        let ordering = ["TODAY", "YESTERDAY", "THIS WEEK"]
        var groups: [Group] = []
        for key in ordering where buckets[key] != nil {
            groups.append(Group(title: key, items: buckets[key]!))
        }
        let months = buckets.keys.filter { !ordering.contains($0) }
        let monthsSorted = months.sorted { lhs, rhs in
            (buckets[lhs]?.first?.createdAt ?? .distantPast) > (buckets[rhs]?.first?.createdAt ?? .distantPast)
        }
        for m in monthsSorted { groups.append(Group(title: m, items: buckets[m]!)) }
        return groups
    }
}
```

- [ ] **Step 4: Run tests — expect green**

```bash
xcodebuild -project FridgeChef.xcodeproj -scheme FridgeChef \
  -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:FridgeChefTests/RecipesVMTests 2>&1 | tail -10
```

Expected: 6 tests pass.

- [ ] **Step 5: Commit**

```bash
git add FridgeChef/Features/Recipes/ViewModel/RecipesVM.swift \
        FridgeChefTests/Features/RecipesVMTests.swift
git commit -m "feat(cookbook): RecipesVM filter + deleteBatch + visibleGroups"
```

---

## Task 14: `CreateEditRecipeVC` (the new screen)

**Files:**
- Create: `FridgeChef/Features/CreateEditRecipe/View/CreateEditRecipeVC.swift`

No new unit tests — VCs are not unit-tested in this codebase (covered by the VM and smoke test).

- [ ] **Step 1: Implement the VC**

Create `FridgeChef/Features/CreateEditRecipe/View/CreateEditRecipeVC.swift`:

```swift
import UIKit
import Combine

final class CreateEditRecipeVC: UIViewController {

    private let vm: CreateEditRecipeVM
    private var cancellables = Set<AnyCancellable>()

    private let scrollView = UIScrollView()
    private let formStack = UIStackView()

    private let titleField = UITextField()
    private let descriptionView = UITextView()
    private let ingredientsStack = UIStackView()
    private let stepsStack = UIStackView()
    private let timeField = UITextField()
    private let addIngredientButton = UIButton(type: .system)
    private let addStepButton = UIButton(type: .system)

    private lazy var saveButton: UIBarButtonItem = {
        let b = UIBarButtonItem(title: "Save", style: .done, target: self, action: #selector(saveTapped))
        b.accessibilityIdentifier = "create.save.button"
        return b
    }()

    init(vm: CreateEditRecipeVM) {
        self.vm = vm
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .paper
        switch vm.mode {
        case .new: title = "New Recipe"
        case .edit: title = "Edit Recipe"
        }
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel,
                                                           target: self, action: #selector(cancelTapped))
        navigationItem.rightBarButtonItem = saveButton

        setupScroll()
        buildForm()
        bind()
    }

    // MARK: - layout

    private func setupScroll() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        formStack.axis = .vertical
        formStack.spacing = Spacing.s16
        formStack.layoutMargins = UIEdgeInsets(top: Spacing.s24, left: Spacing.s24,
                                               bottom: Spacing.s24, right: Spacing.s24)
        formStack.isLayoutMarginsRelativeArrangement = true
        formStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(formStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            formStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            formStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            formStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            formStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            formStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }

    private func buildForm() {
        // Title
        titleField.font = Typography.fraunces(28, weight: .bold)
        titleField.textColor = .ink
        titleField.placeholder = "Recipe title"
        titleField.accessibilityIdentifier = "create.title.field"
        titleField.accessibilityLabel = "Recipe title"
        titleField.borderStyle = .none
        titleField.addTarget(self, action: #selector(titleChanged), for: .editingChanged)
        formStack.addArrangedSubview(titleField)
        formStack.addArrangedSubview(makeRule())

        // Description
        formStack.addArrangedSubview(makeSectionHeader("Description"))
        descriptionView.font = Typography.dmSans(16)
        descriptionView.textColor = .ink
        descriptionView.backgroundColor = .clear
        descriptionView.isScrollEnabled = false
        descriptionView.accessibilityIdentifier = "create.description.field"
        descriptionView.accessibilityLabel = "Description"
        descriptionView.delegate = self
        descriptionView.heightAnchor.constraint(greaterThanOrEqualToConstant: 80).isActive = true
        formStack.addArrangedSubview(descriptionView)
        formStack.addArrangedSubview(makeRule())

        // Ingredients
        formStack.addArrangedSubview(makeSectionHeader("Ingredients"))
        ingredientsStack.axis = .vertical
        ingredientsStack.spacing = Spacing.s8
        formStack.addArrangedSubview(ingredientsStack)
        addIngredientButton.setTitle("+ Add ingredient", for: .normal)
        addIngredientButton.tintColor = .sage
        addIngredientButton.accessibilityIdentifier = "create.ingredient.add"
        addIngredientButton.addTarget(self, action: #selector(addIngredientTapped), for: .touchUpInside)
        formStack.addArrangedSubview(addIngredientButton)
        formStack.addArrangedSubview(makeRule())

        // Steps
        formStack.addArrangedSubview(makeSectionHeader("Steps"))
        stepsStack.axis = .vertical
        stepsStack.spacing = Spacing.s8
        formStack.addArrangedSubview(stepsStack)
        addStepButton.setTitle("+ Add step", for: .normal)
        addStepButton.tintColor = .sage
        addStepButton.accessibilityIdentifier = "create.step.add"
        addStepButton.addTarget(self, action: #selector(addStepTapped), for: .touchUpInside)
        formStack.addArrangedSubview(addStepButton)
        formStack.addArrangedSubview(makeRule())

        // Estimated time
        formStack.addArrangedSubview(makeSectionHeader("Estimated time"))
        timeField.font = Typography.dmSans(16)
        timeField.textColor = .ink
        timeField.placeholder = "30 min"
        timeField.accessibilityIdentifier = "create.time.field"
        timeField.accessibilityLabel = "Estimated time"
        timeField.borderStyle = .none
        timeField.addTarget(self, action: #selector(timeChanged), for: .editingChanged)
        formStack.addArrangedSubview(timeField)

        // Initial values + rows
        titleField.text = vm.title
        descriptionView.text = vm.descriptionText
        timeField.text = vm.estimatedTime
        rebuildIngredientRows()
        rebuildStepRows()
    }

    // MARK: - dynamic rows

    private func rebuildIngredientRows() {
        ingredientsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (idx, text) in vm.ingredients.enumerated() {
            ingredientsStack.addArrangedSubview(makeRow(text: text,
                                                       fieldId: "create.ingredient.row.\(idx).field",
                                                       removeId: "create.ingredient.row.\(idx).remove",
                                                       axLabel: "Ingredient \(idx + 1)",
                                                       index: idx,
                                                       isStep: false,
                                                       canRemove: vm.ingredients.count > 1))
        }
    }

    private func rebuildStepRows() {
        stepsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (idx, text) in vm.steps.enumerated() {
            stepsStack.addArrangedSubview(makeRow(text: text,
                                                  fieldId: "create.step.row.\(idx).field",
                                                  removeId: "create.step.row.\(idx).remove",
                                                  axLabel: "Step \(idx + 1)",
                                                  index: idx,
                                                  isStep: true,
                                                  canRemove: vm.steps.count > 1))
        }
    }

    private func makeRow(text: String,
                         fieldId: String,
                         removeId: String,
                         axLabel: String,
                         index: Int,
                         isStep: Bool,
                         canRemove: Bool) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = Spacing.s8

        let field = UITextField()
        field.font = Typography.dmSans(16)
        field.textColor = .ink
        field.borderStyle = .roundedRect
        field.text = text
        field.accessibilityIdentifier = fieldId
        field.accessibilityLabel = axLabel
        field.tag = index
        field.addTarget(self,
                        action: isStep ? #selector(stepFieldChanged(_:)) : #selector(ingredientFieldChanged(_:)),
                        for: .editingChanged)
        row.addArrangedSubview(field)

        let minus = UIButton(type: .system)
        minus.setImage(UIImage(systemName: "minus.circle.fill"), for: .normal)
        minus.tintColor = .terracotta
        minus.accessibilityIdentifier = removeId
        minus.accessibilityLabel = "Remove \(axLabel.lowercased())"
        minus.tag = index
        minus.isEnabled = canRemove
        minus.alpha = canRemove ? 1.0 : 0.3
        minus.addTarget(self,
                        action: isStep ? #selector(removeStepRowTapped(_:)) : #selector(removeIngredientRowTapped(_:)),
                        for: .touchUpInside)
        minus.widthAnchor.constraint(equalToConstant: 28).isActive = true
        row.addArrangedSubview(minus)
        return row
    }

    // MARK: - field actions

    @objc private func titleChanged() { vm.title = titleField.text ?? "" }
    @objc private func timeChanged() { vm.estimatedTime = timeField.text ?? "" }

    @objc private func ingredientFieldChanged(_ sender: UITextField) {
        var arr = vm.ingredients
        guard arr.indices.contains(sender.tag) else { return }
        arr[sender.tag] = sender.text ?? ""
        vm.ingredients = arr
    }
    @objc private func stepFieldChanged(_ sender: UITextField) {
        var arr = vm.steps
        guard arr.indices.contains(sender.tag) else { return }
        arr[sender.tag] = sender.text ?? ""
        vm.steps = arr
    }

    @objc private func addIngredientTapped() {
        vm.addIngredientRow()
        rebuildIngredientRows()
    }
    @objc private func removeIngredientRowTapped(_ sender: UIButton) {
        vm.removeIngredientRow(at: sender.tag)
        rebuildIngredientRows()
    }
    @objc private func addStepTapped() {
        vm.addStepRow()
        rebuildStepRows()
    }
    @objc private func removeStepRowTapped(_ sender: UIButton) {
        vm.removeStepRow(at: sender.tag)
        rebuildStepRows()
    }

    // MARK: - nav

    @objc private func cancelTapped() {
        guard vm.hasUnsavedChanges else {
            navigationController?.popViewController(animated: true); return
        }
        let alert = UIAlertController(title: "Discard changes?", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Keep editing", style: .cancel))
        alert.addAction(UIAlertAction(title: "Discard", style: .destructive) { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }

    @objc private func saveTapped() {
        Task { await vm.save() }
    }

    // MARK: - bind

    private func bind() {
        vm.$isValid
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.saveButton.isEnabled = $0 }
            .store(in: &cancellables)

        vm.$saveState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in self?.handle(state: state) }
            .store(in: &cancellables)
    }

    private func handle(state: CreateEditRecipeVM.SaveState) {
        switch state {
        case .idle:
            break
        case .saving:
            saveButton.isEnabled = false
        case .saved:
            navigationController?.popViewController(animated: true)
        case .error(let msg):
            let alert = UIAlertController(title: "Couldn't save",
                                          message: msg, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            saveButton.isEnabled = vm.isValid
        }
    }

    // MARK: - small helpers

    private func makeSectionHeader(_ text: String) -> UIView {
        let l = UILabel()
        l.text = text
        l.font = Typography.fraunces(20, weight: .bold)
        l.textColor = .ink
        return l
    }

    private func makeRule() -> UIView {
        let v = UIView()
        v.backgroundColor = .rule
        v.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return v
    }
}

extension CreateEditRecipeVC: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        vm.descriptionText = textView.text ?? ""
    }
}
```

- [ ] **Step 2: Regenerate project and build**

```bash
xcodegen generate
xcodebuild -project FridgeChef.xcodeproj -scheme FridgeChef \
  -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add FridgeChef/Features/CreateEditRecipe/View/CreateEditRecipeVC.swift
git commit -m "feat(cookbook): CreateEditRecipeVC form screen"
```

---

## Task 15: `RecipeDetailVC` — heart + Edit nav buttons, rebind on change

**Files:**
- Modify: `FridgeChef/Features/RecipeDetail/View/RecipeDetailVC.swift`

- [ ] **Step 1: Rewrite `RecipeDetailVC.swift`**

Rewrite `FridgeChef/Features/RecipeDetail/View/RecipeDetailVC.swift`:

```swift
import UIKit
import Combine

final class RecipeDetailVC: UIViewController {

    private let vm: RecipeDetailVM
    private let contentStack = UIStackView()
    private var cancellables = Set<AnyCancellable>()
    private lazy var heartButton: UIBarButtonItem = {
        let b = UIBarButtonItem(image: UIImage(systemName: "heart"),
                                style: .plain, target: self,
                                action: #selector(heartTapped))
        b.tintColor = .terracotta
        b.accessibilityIdentifier = "detail.favorite.button"
        return b
    }()
    private lazy var editButton: UIBarButtonItem = {
        let b = UIBarButtonItem(title: "Edit", style: .plain,
                                target: self, action: #selector(editTapped))
        b.accessibilityIdentifier = "detail.edit.button"
        return b
    }()

    init(vm: RecipeDetailVM) {
        self.vm = vm
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .paper
        navigationItem.rightBarButtonItems = [heartButton, editButton]
        setupLayout()
        bind()
    }

    private func setupLayout() {
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)

        contentStack.axis = .vertical
        contentStack.spacing = Spacing.s16
        contentStack.layoutMargins = .init(top: Spacing.s24, left: Spacing.s24,
                                           bottom: Spacing.s24, right: Spacing.s24)
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            contentStack.topAnchor.constraint(equalTo: scroll.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scroll.widthAnchor),
        ])
    }

    private func bind() {
        vm.$recipe
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.rebuildContent(with: $0) }
            .store(in: &cancellables)

        vm.$isFavorite
            .receive(on: DispatchQueue.main)
            .sink { [weak self] fav in
                self?.heartButton.image = UIImage(systemName: fav ? "heart.fill" : "heart")
                self?.heartButton.accessibilityLabel = fav ? "Unfavorite" : "Favorite"
            }
            .store(in: &cancellables)

        vm.$lastError
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] msg in
                let alert = UIAlertController(title: "Couldn't save favorite",
                                              message: msg, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                    self?.vm.clearError()
                })
                self?.present(alert, animated: true)
            }
            .store(in: &cancellables)
    }

    private func rebuildContent(with recipe: Recipe) {
        for v in contentStack.arrangedSubviews {
            contentStack.removeArrangedSubview(v)
            v.removeFromSuperview()
        }
        let title = UILabel()
        title.text = recipe.title
        title.font = Typography.fraunces(32, weight: .bold)
        title.textColor = .ink
        title.numberOfLines = 0
        contentStack.addArrangedSubview(title)

        let time = UILabel()
        time.text = recipe.estimatedTime.uppercased()
        time.font = Typography.dmSans(13, weight: .medium)
        time.textColor = .sage
        contentStack.addArrangedSubview(time)

        contentStack.addArrangedSubview(makeRule())
        contentStack.addArrangedSubview(makeSectionHeader("Ingredients"))
        for ing in recipe.ingredients {
            contentStack.addArrangedSubview(makeBullet("• \(ing)"))
        }
        contentStack.addArrangedSubview(makeRule())
        contentStack.addArrangedSubview(makeSectionHeader("Steps"))
        for (idx, step) in recipe.steps.enumerated() {
            contentStack.addArrangedSubview(makeBullet("\(idx + 1). \(step)"))
        }
    }

    // MARK: - actions

    @objc private func heartTapped() {
        Task { await vm.toggleFavorite() }
    }
    @objc private func editTapped() {
        let editVM = CreateEditRecipeVM(
            mode: .edit(existing: vm.recipe, batchId: vm.batchId),
            store: storeFromVM()
        )
        navigationController?.pushViewController(CreateEditRecipeVC(vm: editVM), animated: true)
    }

    private func storeFromVM() -> RecipeStoreProtocol {
        // RecipeDetailVM owns the store privately; expose via Mirror is overkill.
        // The detail VC was constructed by RecipeBatchVC which knows the store, so we
        // route the edit-VM construction through the VM itself via a small helper.
        return vm.makeStoreReference()
    }

    private func makeSectionHeader(_ text: String) -> UIView {
        let l = UILabel(); l.text = text
        l.font = Typography.fraunces(22, weight: .bold); l.textColor = .ink; return l
    }
    private func makeBullet(_ text: String) -> UIView {
        let l = UILabel(); l.text = text
        l.font = Typography.dmSans(16); l.textColor = .ink; l.numberOfLines = 0; return l
    }
    private func makeRule() -> UIView {
        let v = UIView(); v.backgroundColor = .rule
        v.heightAnchor.constraint(equalToConstant: 1).isActive = true; return v
    }
}
```

- [ ] **Step 2: Expose the store on `RecipeDetailVM` for the Edit button**

Add this method to `RecipeDetailVM` (inside the class body in `RecipeDetailVM.swift`):

```swift
func makeStoreReference() -> RecipeStoreProtocol { store }
```

(Alternatively: make `store` `internal` directly. `makeStoreReference()` keeps the original `private` and isolates the leak to one method.)

- [ ] **Step 3: Build**

```bash
xcodebuild -project FridgeChef.xcodeproj -scheme FridgeChef \
  -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add FridgeChef/Features/RecipeDetail/View/RecipeDetailVC.swift \
        FridgeChef/Features/RecipeDetail/ViewModel/RecipeDetailVM.swift
git commit -m "feat(cookbook): RecipeDetailVC heart + Edit nav buttons, live rebind"
```

---

## Task 16: `RecipeBatchVC` updates + `RecipeBatchCardCell` heart overlay

**Files:**
- Modify: `FridgeChef/Features/RecipeBatch/View/RecipeBatchVC.swift`
- Modify: `FridgeChef/Features/RecipeBatch/View/RecipeBatchCardCell.swift`

- [ ] **Step 1: Add heart overlay to `RecipeBatchCardCell`**

Rewrite `FridgeChef/Features/RecipeBatch/View/RecipeBatchCardCell.swift`:

```swift
import UIKit

final class RecipeBatchCardCell: UICollectionViewCell {
    static let reuseID = "RecipeBatchCardCell"

    private let titleLabel = UILabel()
    private let descLabel = UILabel()
    private let badges = UILabel()
    private let timeLabel = UILabel()
    private let heart = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .paper2
        contentView.layer.cornerRadius = 12
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = UIColor.rule.cgColor

        titleLabel.font = Typography.fraunces(20, weight: .bold)
        titleLabel.textColor = .ink
        descLabel.font = Typography.dmSans(14)
        descLabel.textColor = .inkSoft
        descLabel.numberOfLines = 2
        badges.font = Typography.dmSans(12, weight: .medium)
        badges.textColor = .terracotta
        badges.numberOfLines = 1
        timeLabel.font = Typography.dmSans(12, weight: .medium)
        timeLabel.textColor = .sage

        let stack = UIStackView(arrangedSubviews: [titleLabel, descLabel, badges, timeLabel])
        stack.axis = .vertical
        stack.spacing = Spacing.s4
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Spacing.s16),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Spacing.s16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Spacing.s16),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Spacing.s16),
        ])

        heart.image = UIImage(systemName: "heart.fill",
                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold))
        heart.tintColor = .terracotta
        heart.translatesAutoresizingMaskIntoConstraints = false
        heart.isHidden = true
        contentView.addSubview(heart)
        NSLayoutConstraint.activate([
            heart.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Spacing.s8),
            heart.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Spacing.s8),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(with recipe: Recipe) {
        titleLabel.text = recipe.title
        descLabel.text = recipe.description
        let first = Array(recipe.ingredients.prefix(3))
        let overflow = recipe.ingredients.count - first.count
        var b = first.joined(separator: " · ")
        if overflow > 0 { b += " · +\(overflow)" }
        badges.text = b
        timeLabel.text = recipe.estimatedTime
        heart.isHidden = !recipe.isFavorite
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        contentView.layer.borderColor = UIColor.rule.cgColor
    }
}
```

- [ ] **Step 2: Rewrite `RecipeBatchVC.swift` — bind to `batchState`, push detail with `store`, swipe-delete**

Rewrite `FridgeChef/Features/RecipeBatch/View/RecipeBatchVC.swift`:

```swift
import UIKit
import Combine

final class RecipeBatchVC: UIViewController, UICollectionViewDelegate {

    private let vm: RecipeBatchVM
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Int, Recipe>!
    private let headerLabel = UILabel()
    private var cancellables = Set<AnyCancellable>()

    init(vm: RecipeBatchVM) {
        self.vm = vm
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .paper

        let layout = UICollectionViewCompositionalLayout { [weak self] _, env in
            var config = UICollectionLayoutListConfiguration(appearance: .plain)
            config.backgroundColor = .clear
            config.showsSeparators = false
            config.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
                guard let self else { return nil }
                let recipe = self.vm.recipes[indexPath.item]
                let action = UIContextualAction(style: .destructive, title: "Delete") { _, _, done in
                    self.confirmDelete(recipe: recipe, completion: done)
                }
                return UISwipeActionsConfiguration(actions: [action])
            }
            let section = NSCollectionLayoutSection.list(using: config, layoutEnvironment: env)
            section.interGroupSpacing = Spacing.s12
            section.contentInsets = .init(top: Spacing.s32, leading: Spacing.s16,
                                          bottom: Spacing.s16, trailing: Spacing.s16)
            return section
        }

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.register(RecipeBatchCardCell.self,
                                forCellWithReuseIdentifier: RecipeBatchCardCell.reuseID)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])

        headerLabel.font = Typography.dmSans(12, weight: .medium)
        headerLabel.textColor = .inkSoft
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerLabel)
        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Spacing.s8),
            headerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Spacing.s16),
        ])

        dataSource = UICollectionViewDiffableDataSource<Int, Recipe>(collectionView: collectionView) { cv, ip, recipe in
            let cell = cv.dequeueReusableCell(withReuseIdentifier: RecipeBatchCardCell.reuseID, for: ip) as! RecipeBatchCardCell
            cell.configure(with: recipe)
            return cell
        }

        bind()
    }

    private func bind() {
        vm.$batchState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in self?.render(state: state) }
            .store(in: &cancellables)
    }

    private func render(state: RecipeBatchVM.BatchState) {
        switch state {
        case .loaded(let batch):
            title = "\(batch.recipes.count) recipes"
            headerLabel.text = vm.headerDateString
            var snap = NSDiffableDataSourceSnapshot<Int, Recipe>()
            snap.appendSections([0])
            snap.appendItems(batch.recipes)
            dataSource.apply(snap, animatingDifferences: true)
        case .gone:
            navigationController?.popViewController(animated: true)
        }
    }

    private func confirmDelete(recipe: Recipe, completion: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: "Delete this recipe?",
                                      message: recipe.title,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completion(false) })
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            guard let self else { completion(false); return }
            Task {
                await self.vm.deleteRecipe(id: recipe.id)
                completion(true)
            }
        })
        present(alert, animated: true)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard vm.recipes.indices.contains(indexPath.item) else { return }
        let recipe = vm.recipes[indexPath.item]
        let detailVM = RecipeDetailVM(recipe: recipe, batchId: vm.initialBatchId, store: vm.store)
        navigationController?.pushViewController(RecipeDetailVC(vm: detailVM), animated: true)
    }
}
```

- [ ] **Step 3: Build + manual smoke**

```bash
xcodebuild -project FridgeChef.xcodeproj -scheme FridgeChef \
  -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add FridgeChef/Features/RecipeBatch/View/RecipeBatchVC.swift \
        FridgeChef/Features/RecipeBatch/View/RecipeBatchCardCell.swift
git commit -m "feat(cookbook): RecipeBatch heart overlay + swipe-delete with cascade"
```

---

## Task 17: `RecipesVC` updates — `+` button, segmented control, swipe-delete, batch heart

**Files:**
- Modify: `FridgeChef/Features/Recipes/View/RecipesVC.swift`
- Modify: `FridgeChef/Features/Recipes/View/RecipesBatchCell.swift`

- [ ] **Step 1: Update `RecipesBatchCell` to show a heart icon when any recipe is favorited**

Rewrite `FridgeChef/Features/Recipes/View/RecipesBatchCell.swift`:

```swift
import UIKit

final class RecipesBatchCell: UICollectionViewListCell {
    static let reuseID = "RecipesBatchCell"

    func configure(with batch: RecipeBatch) {
        var content = UIListContentConfiguration.subtitleCell()
        let timeFmt = DateFormatter(); timeFmt.dateFormat = "h:mm a"
        content.text = "\(timeFmt.string(from: batch.createdAt)) · \(batch.recipes.count) recipes"
        content.textProperties.font = Typography.dmSans(16, weight: .medium)
        content.textProperties.color = .ink

        let hasFavorite = batch.recipes.contains(where: \.isFavorite)
        if hasFavorite {
            content.image = UIImage(systemName: "heart.fill",
                                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .semibold))
            content.imageProperties.tintColor = .terracotta
            content.imageToTextPadding = Spacing.s8
        }

        content.secondaryText = batch.inputIngredients.isEmpty
            ? (batch.source == .user ? "Your recipe" : "")
            : batch.inputIngredients.joined(separator: ", ")
        content.secondaryTextProperties.font = Typography.dmSans(13)
        content.secondaryTextProperties.color = .inkSoft
        contentConfiguration = content

        var bg = UIBackgroundConfiguration.listGroupedCell()
        bg.backgroundColor = .paper2
        backgroundConfiguration = bg
    }
}
```

- [ ] **Step 2: Update `RecipesVC` — `+` button, segmented control, swipe-delete, bind to `visibleGroups`, push with store**

Rewrite `FridgeChef/Features/Recipes/View/RecipesVC.swift`:

```swift
import UIKit
import Combine

final class RecipesVC: UIViewController, UICollectionViewDelegate {

    private let vm: RecipesVM
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<String, RecipeBatch>!
    private let segmented = UISegmentedControl(items: ["All", "Favorites"])
    private var cancellables = Set<AnyCancellable>()

    init(vm: RecipesVM) {
        self.vm = vm
        super.init(nibName: nil, bundle: nil)
        title = "Recipes"
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .paper
        navigationController?.navigationBar.prefersLargeTitles = true

        let plus = UIBarButtonItem(barButtonSystemItem: .add, target: self,
                                   action: #selector(createTapped))
        plus.accessibilityIdentifier = "recipes.create.button"
        plus.accessibilityLabel = "Create new recipe"
        navigationItem.rightBarButtonItem = plus

        setupSegmented()
        setupCollectionView()
        bind()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Task { await vm.load() }
    }

    private func setupSegmented() {
        segmented.translatesAutoresizingMaskIntoConstraints = false
        segmented.selectedSegmentIndex = 0
        segmented.accessibilityIdentifier = "recipes.filter.segmented"
        segmented.accessibilityLabel = "Filter recipes"
        segmented.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        view.addSubview(segmented)
        NSLayoutConstraint.activate([
            segmented.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Spacing.s8),
            segmented.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Spacing.s16),
            segmented.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Spacing.s16),
        ])
    }

    private func setupCollectionView() {
        var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        config.backgroundColor = .clear
        config.headerMode = .supplementary
        config.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
            guard let self,
                  let batch = self.batch(at: indexPath) else { return nil }
            let action = UIContextualAction(style: .destructive, title: "Delete") { _, _, done in
                self.confirmDeleteBatch(batch: batch, completion: done)
            }
            return UISwipeActionsConfiguration(actions: [action])
        }
        let layout = UICollectionViewCompositionalLayout.list(using: config)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.register(RecipesBatchCell.self, forCellWithReuseIdentifier: RecipesBatchCell.reuseID)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: segmented.bottomAnchor, constant: Spacing.s8),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])

        let headerReg = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] header, _, indexPath in
            guard let title = self?.dataSource.snapshot().sectionIdentifiers[indexPath.section] else { return }
            var content = header.defaultContentConfiguration()
            content.text = title
            content.textProperties.font = Typography.dmSans(12, weight: .medium)
            content.textProperties.color = .inkSoft
            header.contentConfiguration = content
        }

        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { cv, ip, batch in
            let cell = cv.dequeueReusableCell(withReuseIdentifier: RecipesBatchCell.reuseID, for: ip) as! RecipesBatchCell
            cell.configure(with: batch)
            return cell
        }
        dataSource.supplementaryViewProvider = { cv, _, ip in
            cv.dequeueConfiguredReusableSupplementary(using: headerReg, for: ip)
        }
    }

    private func bind() {
        vm.$visibleGroups
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.render(groups: $0) }
            .store(in: &cancellables)
    }

    private func render(groups: [RecipesVM.Group]) {
        if groups.isEmpty {
            var config = UIContentUnavailableConfiguration.empty()
            config.text = vm.filter == .favorites ? "No favorites yet" : "No recipes yet"
            config.secondaryText = vm.filter == .favorites
                ? "Tap the heart on a recipe to favorite it."
                : "Tap + to add one, or generate from Home."
            contentUnavailableConfiguration = config
            return
        }
        contentUnavailableConfiguration = nil
        var snap = NSDiffableDataSourceSnapshot<String, RecipeBatch>()
        for g in groups {
            snap.appendSections([g.title])
            snap.appendItems(g.items, toSection: g.title)
        }
        dataSource.apply(snap, animatingDifferences: true)
    }

    private func batch(at indexPath: IndexPath) -> RecipeBatch? {
        let snap = dataSource.snapshot()
        guard snap.sectionIdentifiers.indices.contains(indexPath.section) else { return nil }
        let sectionID = snap.sectionIdentifiers[indexPath.section]
        let items = snap.itemIdentifiers(inSection: sectionID)
        guard items.indices.contains(indexPath.item) else { return nil }
        return items[indexPath.item]
    }

    @objc private func segmentChanged() {
        vm.filter = segmented.selectedSegmentIndex == 0 ? .all : .favorites
    }

    @objc private func createTapped() {
        let createVM = CreateEditRecipeVM(mode: .new, store: vm.store)
        navigationController?.pushViewController(CreateEditRecipeVC(vm: createVM), animated: true)
    }

    private func confirmDeleteBatch(batch: RecipeBatch, completion: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: "Delete this batch?",
                                      message: "All \(batch.recipes.count) recipes will be removed.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completion(false) })
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            Task {
                await self?.vm.deleteBatch(id: batch.id)
                completion(true)
            }
        })
        present(alert, animated: true)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let batch = batch(at: indexPath) else { return }
        let batchVM = RecipeBatchVM(batch: batch, store: vm.store)
        navigationController?.pushViewController(RecipeBatchVC(vm: batchVM), animated: true)
    }
}
```

- [ ] **Step 3: Build**

```bash
xcodebuild -project FridgeChef.xcodeproj -scheme FridgeChef \
  -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add FridgeChef/Features/Recipes/View/RecipesVC.swift \
        FridgeChef/Features/Recipes/View/RecipesBatchCell.swift
git commit -m "feat(cookbook): RecipesVC + button, filter segmented, swipe-delete"
```

---

## Task 18: Smoke test + full test sweep

**Files:**
- Modify: `FridgeChefUITests/SmokeTests.swift`

- [ ] **Step 1: Append the new smoke test**

Append to `FridgeChefUITests/SmokeTests.swift`, inside the `SmokeTests` class:

```swift
func test_recipes_create_button_opensForm() {
    let app = launch()
    app.tabBars.buttons["Recipes"].tap()

    let createButton = app.navigationBars["Recipes"].buttons["recipes.create.button"]
    XCTAssertTrue(createButton.waitForExistence(timeout: 3))
    createButton.tap()

    XCTAssertTrue(app.textFields["create.title.field"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["create.save.button"].exists)
}
```

- [ ] **Step 2: Run the unit-test target as a whole**

```bash
xcodebuild -project FridgeChef.xcodeproj -scheme FridgeChef \
  -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:FridgeChefTests 2>&1 | tail -30
```

Expected: 66 unit tests pass (52 prior + 14 new across VM + Store; if the count is slightly different verify against the spec, but every previously-passing test must still pass).

- [ ] **Step 3: Run the smoke target**

```bash
xcodebuild -project FridgeChef.xcodeproj -scheme FridgeChef \
  -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:FridgeChefUITests 2>&1 | tail -20
```

Expected: 4 XCUITests pass (3 existing + 1 new).

- [ ] **Step 4: Commit**

```bash
git add FridgeChefUITests/SmokeTests.swift
git commit -m "test(cookbook): smoke test for Recipes + button → create form"
```

---

## Task 19: Manual verification on simulator

No file edits — just visual verification.

- [ ] **Step 1: Launch the app**

```bash
xcodebuild -project FridgeChef.xcodeproj -scheme FridgeChef \
  -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
xcrun simctl install booted ~/Library/Developer/Xcode/DerivedData/FridgeChef-*/Build/Products/Debug-iphonesimulator/FridgeChef.app
xcrun simctl launch booted com.baha.fridgechef
```

- [ ] **Step 2: Verify each user flow**

Walk through manually in the simulator:

1. **Recipes tab → +** → Create form appears. Title "Pancakes", add 2 ingredients, 1 step, save. Pop happens. Back in Recipes — see the new batch with "Your recipe" subtitle.
2. **Tap the new batch** → batch view shows one recipe card with no heart overlay. Tap the recipe → detail. Tap heart → fills. Pop back → card now shows a heart overlay top-right.
3. **Detail → Edit** → form prefilled. Change title, save. Back on detail screen, new title shows without a re-push.
4. **Recipes tab, Favorites segment** → only batches with ≥1 favorite. Others hidden.
5. **Swipe-delete a recipe** in batch view → confirmation alert → delete. If it was the last recipe, the VC pops back to Recipes and the batch is gone.
6. **Swipe-delete a batch** in Recipes → confirmation alert → delete. Batch is gone.

- [ ] **Step 3: If any flow misbehaves, fix and commit the fix**

Append a follow-up commit named, e.g., `fix(cookbook): <symptom> <fix>`.

---

## Task 20: Push branch + open PR

- [ ] **Step 1: Push the branch**

```bash
git push -u origin feat/cookbook-phase1
```

- [ ] **Step 2: Open the stacked PR**

Target branch: `feat/catalog-redesign` (if v1.1 not yet merged) or `feat/v1` (if it has).

```bash
gh pr create --base feat/catalog-redesign --title "Cookbook Phase 1: create, edit, favorite, delete" --body "$(cat <<'EOF'
## Summary
- Adds **create / edit / favorite / delete** for recipes — the first chunk of a personal cookbook
- Core Data v2 lightweight migration: `source` on batch, `isFavorite` + `updatedAt` on recipe
- New `CreateEditRecipeVC` screen, new `+` and filter on Recipes tab, heart on detail, swipe-delete in two places
- Test count 52 → 69 (66 unit + 3 smoke before; the smoke +1 lands here)

## Test plan
- [ ] All XCTest targets pass on iPhone 16 sim
- [ ] All smoke tests pass
- [ ] Manual walkthrough: create / edit / favorite / filter / swipe-delete recipe / swipe-delete batch / cascade on last recipe
- [ ] Existing AI generation flows still work (Home tab → Breakfast / From my fridge / Surprise / text)

Closes the Phase 1 scope in `docs/superpowers/specs/2026-05-19-fridgechef-cookbook-phase1-design.md`.
EOF
)"
```

---

## Self-Review Notes

**Spec coverage:**
- §2.1 schema → Tasks 6 + 7
- §2.2 value types → Tasks 2 + 3 + call-site fixups in 4 + 5
- §2.3 user-recipe storage = batch-of-one with source = .user → enforced in `CreateEditRecipeVM.save()` (Task 10)
- §3 RecipeStore API + cascade rule → Task 8
- §4.1 CreateEditRecipeVC layout/IDs → Task 14
- §4.2 RecipesVC + button, segmented, swipe-delete → Task 17
- §4.3 RecipeBatchVC heart overlay + swipe-delete → Task 16
- §4.4 RecipeDetailVC heart + Edit, live rebind → Tasks 11 + 15
- §5 VMs → Tasks 10 (CreateEdit), 11 (Detail), 12 (Batch), 13 (Recipes)
- §6 flows → enforced through binding paths in 14, 15, 16, 17
- §7 error table → CreateEditVM .error alert (14); detail revert + alert (11+15); delete confirm + alert (16+17); discard-changes alert (14)
- §8 tests → all itemized, 14 new + adjusted existing
- §8.3 smoke +1 → Task 18
- §9 accessibility IDs → set verbatim in 14, 15, 16, 17
- §10 branching → Task 1
- §11 out-of-scope → not implemented (correct)

**Placeholder scan:** no TBDs, no "add validation", no "handle edge cases" without code, no "similar to Task N".

**Type consistency:**
- `Mode.edit(existing:batchId:)` — labeled the same way in spec, VM, and the VC `editTapped` action
- `BatchState.loaded(RecipeBatch)` / `.gone` — same in VM, VC, and test
- `RecipeSource.ai` / `.user` — same everywhere
- `RecipeStoreError.notFound` — same in store + stubs + tests
- `RecipeStoreProtocol` order (`update`, `setFavorite`, `delete(recipeId:)`, `delete(batchId:)`) matches across protocol, store impl, stub, UITestStubStore, tests
