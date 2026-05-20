# FridgeChef iOS — v1 design

**Date:** 2026-05-18
**Status:** Awaiting user approval
**Companion projects:**
- `../youtube_pdf_reporter` — source of the `OPENAI_API_KEY` (`.env` file)
- `../personal-finance-tracker-ios` — Spend·book v1, the iOS conventions reference

## Summary

Native iOS app (UIKit) that turns a list of ingredients — typed as chips or extracted from a fridge photo — into 3 recipe suggestions via a single GPT-4o Vision call. Every generated batch is persisted to Core Data and visible in a Recipes history tab. Light/dark theme follows the iOS system setting by default with a manual override in Settings.

## Decisions

| Area | Decision |
|---|---|
| App name | FridgeChef |
| Bundle ID | `com.baha.fridgechef` |
| Folder | `~/Desktop/llm-ai-projects/recipe-ingredients-ios/` |
| Min iOS | 17.0 |
| Language | Swift 5.10+ |
| UI framework | UIKit (no SwiftUI in v1) |
| Architecture | MVVM + Combine + diffable data sources (per-feature folders) |
| Dependencies | None. Stdlib + Core Data only. |
| Backend | None — direct OpenAI calls from device |
| OpenAI model | `gpt-4o` (Vision capable) |
| OpenAI output | Structured (`response_format: json_schema`) — guaranteed valid JSON |
| Persistence | Core Data (RecipeBatchEntity → RecipeEntity, cascade delete) |
| Tabs | Home, Recipes, Settings (3 tabs) |
| Theme | Follow iOS system; 3-state picker in Settings (System / Light / Dark) |
| Photo source | Camera + Photo library (action sheet) |
| API key | Run Script Phase reads `~/Desktop/llm-ai-projects/youtube_pdf_reporter/.env` and injects `OPENAI_API_KEY` into the built `Info.plist` |
| Visual design | Port Spend·book — Fraunces + DM Sans, paper/ink/sage/terracotta — add dark variants |
| Build system | Single Xcode project, single app target. No SPM packages. |
| MCP for iteration | `XcodeBuildMCP` registered in `.mcp.json` for project-scoped use |

## v1 scope

**In scope:**
- Home tab: chip-based ingredient input + camera/library photo flow → "Suggest recipes" → push RecipeBatch
- RecipeBatch screen: 3 recipe cards from one generation; pushed from Home or from a saved batch in Recipes
- RecipeDetail screen: full recipe (title, time, ingredients, steps)
- Recipes tab: history of all generated batches, grouped by relative date (Today / Yesterday / This Week / older months)
- Settings tab: theme picker, OpenAI key status (read-only), model label, "Clear all recipes" destructive action, version info
- Light + dark theme with system follow

**Out of scope (defer to v2+):**
- Favoriting / starring recipes
- Editing saved recipes
- Share sheet on recipe detail
- Crash reporting (Sentry etc.)
- iPad bespoke layout, Mac Catalyst
- Dietary filters (vegetarian, gluten-free, allergens)
- Cooking timer / step-by-step mode
- Backend proxy for the OpenAI key
- iCloud sync of recipe history
- Multi-language

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  FridgeChef (UIKit, MVVM + Combine, iOS 17+)                │
│                                                             │
│  HomeVC ◀▶ HomeVM ─────────────────────┐                    │
│  RecipeBatchVC ◀▶ RecipeBatchVM ◀──────┘                    │
│         ▲                  │                                │
│         │  (push from)     ▼                                │
│  RecipesVC ◀▶ RecipesVM   RecipeDetailVC ◀▶ RecipeDetailVM  │
│  SettingsVC ◀▶ SettingsVM                                   │
│                                                             │
│         ▼ VMs depend on (via protocols)                     │
│  OpenAIClientProtocol  ──▶ URLSession + async/await         │
│  RecipeStoreProtocol   ──▶ Core Data (RecipeBatchEntity)    │
│  ThemeManager          ──▶ UserDefaults + window override   │
│  APIKeyProvider        ──▶ Bundle.main Info.plist           │
│  DesignSystem (Colors/Typography/Spacing)                   │
└────────────────────────┼────────────────────────────────────┘
                         │ HTTPS, Bearer <OPENAI_API_KEY>
              ┌──────────▼──────────┐
              │ api.openai.com      │
              │ /v1/chat/completions│
              │ model: gpt-4o       │
              │ response_format:    │
              │   json_schema       │
              └─────────────────────┘
```

**Key principles** (carried from Spend·book v1):
- Thin `UIViewController` binds to a `@Published`-driven `ViewModel` via Combine
- Lists use `UICollectionViewDiffableDataSource`
- All networking is `async/await` on `URLSession`, called from `Task {}` inside the VM
- Each VM stores its in-flight `Task` and cancels on deinit / before starting a new request
- No third-party deps, no SPM packages, no CocoaPods

## Data flow

### App launch
```
AppDelegate ─► SceneDelegate ─► ThemeManager.apply()
                              └► RootTabBarController
                                  ├─ NavController → HomeVC
                                  ├─ NavController → RecipesVC
                                  └─ NavController → SettingsVC
```
On launch, `APIKeyProvider.get()` is *not* called eagerly — the first OpenAI call triggers it. Settings shows the key status separately by calling `try? APIKeyProvider.get()` and rendering ✓ or ⚠.

### Generate from chips
```
HomeVC: user types chips, taps "Suggest recipes"
  → HomeVM.generate()
    → state = .loading
    → Task { OpenAIClient.suggestRecipes(ingredients: chips) }
      → POST /v1/chat/completions with structured-output schema
      → decoded { recipes: [Recipe] }
    → RecipeBatch built (id, createdAt, inputIngredients, recipes)
    → RecipeStore.save(batch)
    → state = .loaded(batch)
  → HomeVC sink: push RecipeBatchVC(batch)
```

### Generate from photo
```
HomeVC: user taps 📷 → action sheet
  → "Take photo" → UIImagePickerController(.camera)
  → "Choose from library" → PHPickerViewController
  → on pick: HomeVM.generate(image: UIImage)
    → resize image to ≤1024px longest side, JPEG-encode quality 0.7
    → state = .loading
    → Task { OpenAIClient.suggestRecipes(imageJPEG: data) }
    → (same path as above; batch has inputImageThumbnailJPEG set)
```

### Open a saved batch
```
RecipesVC: user taps a row
  → push RecipeBatchVC(batch:)
  → RecipeBatchVM.state = .loaded(batch)  // no network call
```

### Recipe detail
```
RecipeBatchVC: user taps a card
  → push RecipeDetailVC(recipe:)
```

### Clear history
```
SettingsVC: user taps "Clear all recipes" → UIAlertController confirm
  → SettingsVM.clearAll()
    → RecipeStore.deleteAll()
  → NotificationCenter.default.post(.recipesDidChange)
    → RecipesVC reloads (immediately if visible, else on next viewWillAppear)
```

### Error handling
- Network/decoding errors → VM state `.error(message)` → VC shows `UIContentUnavailableView` with "Try again"
- `OpenAIError.unauthorized` → message: "API key invalid. Check Settings."
- `OpenAIError.rateLimited` → "Too many requests. Try again in a moment."
- `OpenAIError.missingAPIKey` → "Build broken: rebuild from Xcode."
- Each VM cancels its `Task` on deinit and before starting a new one

## Networking

### OpenAIClient

```swift
protocol OpenAIClientProtocol {
    func suggestRecipes(ingredients: [String]) async throws -> [Recipe]
    func suggestRecipes(imageJPEG: Data) async throws -> [Recipe]
}

struct OpenAIClient: OpenAIClientProtocol {
    let apiKey: String
    let session: URLSession
    let model = "gpt-4o"
    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    func suggestRecipes(ingredients: [String]) async throws -> [Recipe] { … }
    func suggestRecipes(imageJPEG: Data) async throws -> [Recipe] { … }
}
```

### Structured output (force valid JSON)

Every request includes:
```json
"response_format": {
  "type": "json_schema",
  "json_schema": {
    "name": "recipes_response",
    "strict": true,
    "schema": {
      "type": "object",
      "additionalProperties": false,
      "required": ["recipes"],
      "properties": {
        "recipes": {
          "type": "array",
          "minItems": 3,
          "maxItems": 3,
          "items": {
            "type": "object",
            "additionalProperties": false,
            "required": ["title", "description", "ingredients", "steps", "estimatedTime"],
            "properties": {
              "title": { "type": "string" },
              "description": { "type": "string" },
              "ingredients": { "type": "array", "items": { "type": "string" } },
              "steps": { "type": "array", "items": { "type": "string" } },
              "estimatedTime": { "type": "string" }
            }
          }
        }
      }
    }
  }
}
```

Response payload `choices[0].message.content` is a JSON string matching the schema. Decode into `RecipesResponse` (struct with `let recipes: [Recipe]`).

### Errors

```swift
enum OpenAIError: Error, LocalizedError {
    case missingAPIKey
    case unauthorized            // 401
    case rateLimited             // 429
    case server(Int)             // 5xx
    case invalidResponse         // non-JSON or unexpected shape
    case decoding(Error)
    case network(URLError)
    case noRecipesReturned       // 200 but empty array (rare with structured output)
}
```

### Models

```swift
struct Recipe: Codable, Hashable, Identifiable {
    let id: UUID                  // generated locally; not from API
    let title: String
    let description: String
    let ingredients: [String]
    let steps: [String]
    let estimatedTime: String
}

struct RecipeBatch: Identifiable, Hashable {
    let id: UUID
    let createdAt: Date
    let inputIngredients: [String]
    let inputImageThumbnailJPEG: Data?   // optional; nil for text-only input
    let recipes: [Recipe]                 // ordered 0..2
}
```

Chips on the Home screen are `[String]` directly — no wrapper type (a chip's identity *is* its lowercased text; duplicates are prevented at add time).

## Key bootstrap (build script)

### Why this approach

The user explicitly chose: "Read from `…/youtube_pdf_reporter/.env` at build time" (over Keychain Setup sheet or hand-edited xcconfig). Trade-offs documented in conversation:
- ✅ Zero manual steps for personal dev use
- ✅ Key never enters git
- ❌ Only works on a machine with the YouTube PDF .env at that exact path
- ❌ Build fails loudly if `.env` is missing (intentional)

### `scripts/inject-openai-key.sh`

Added to the FridgeChef target as a Run Script Phase that fires *after* "Copy Bundle Resources":

```bash
#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="$HOME/Desktop/llm-ai-projects/youtube_pdf_reporter/.env"
INFO_PLIST="$BUILT_PRODUCTS_DIR/$INFOPLIST_PATH"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "error: $ENV_FILE not found — cannot inject OPENAI_API_KEY" >&2
  exit 1
fi

KEY=$(grep -E '^OPENAI_API_KEY=' "$ENV_FILE" | head -1 | cut -d'=' -f2- | tr -d '"'"'")

if [[ -z "$KEY" ]]; then
  echo "error: OPENAI_API_KEY missing or empty in $ENV_FILE" >&2
  exit 1
fi

/usr/libexec/PlistBuddy -c "Delete :OPENAI_API_KEY" "$INFO_PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :OPENAI_API_KEY string $KEY" "$INFO_PLIST"

echo "✓ injected OPENAI_API_KEY"
```

### `APIKeyProvider.swift`

```swift
struct APIKeyProvider {
    static func get() throws -> String {
        guard let k = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String,
              !k.isEmpty else { throw OpenAIError.missingAPIKey }
        return k
    }
}
```

## Core Data schema

Single `.xcdatamodeld` with two entities. JSON-encoded string columns are used for `[String]` fields (vs Transformable) so the SQLite store is debuggable with the `sqlite3` CLI.

### RecipeBatchEntity

| Attribute | Type | Notes |
|---|---|---|
| `id` | UUID | primary key, indexed |
| `createdAt` | Date | indexed; sort key for Recipes tab |
| `inputIngredientsJSON` | String | JSON-encoded `[String]` |
| `inputImageThumbnailJPEG` | Binary Data, optional, allows external storage | resized ≤1024px, quality 0.7; nil for text-only batches |
| `recipes` | → `RecipeEntity` (to-many, ordered, cascade) | inverse: `batch` |

### RecipeEntity

| Attribute | Type | Notes |
|---|---|---|
| `id` | UUID | indexed |
| `title` | String | |
| `recipeDescription` | String | `description` is reserved on NSObject |
| `ingredientsJSON` | String | JSON-encoded `[String]` |
| `stepsJSON` | String | JSON-encoded `[String]` |
| `estimatedTime` | String | model returns it as a string ("30 min") |
| `order` | Int16 | 0, 1, 2 — display position within batch |
| `batch` | → `RecipeBatchEntity` | inverse |

### RecipeStore (protocol VMs depend on)

```swift
protocol RecipeStoreProtocol {
    func save(_ batch: RecipeBatch) async throws
    func allBatches() async throws -> [RecipeBatch]   // newest first
    func batch(id: UUID) async throws -> RecipeBatch?
    func deleteAll() async throws
}
```

Backed by `NSPersistentContainer` writing to the app sandbox. No iCloud sync in v1. All Core Data work runs on a background context; VMs only ever receive plain `RecipeBatch` / `Recipe` structs.

## Screens

### 1. Home (Tab 1)

```
┌─────────────────────────────────┐
│ FridgeChef                  [📷]│
├─────────────────────────────────┤
│ INGREDIENTS                     │
│ ┌───────┐┌──────┐┌───────────┐  │
│ │tomato×││basil×││olive oil ×│  │
│ └───────┘└──────┘└───────────┘  │
│ ┌─────────────────────┐ ┌───┐   │
│ │ Add an ingredient…  │ │Add│   │
│ └─────────────────────┘ └───┘   │
│            (empty space)        │
│ ┌─────────────────────────────┐ │
│ │      Suggest recipes →      │ │
│ └─────────────────────────────┘ │
└─────────────────────────────────┘
```
- Chips use the `butter` token (warm highlight). Tapping the `×` removes.
- 📷 button presents `UIAlertController(.actionSheet)`: Take photo / Choose from library / Cancel.
- "Suggest recipes" button is disabled until ≥1 chip exists.
- During generation: full-screen blocking overlay (semi-transparent `ink`) with Fraunces spinner and "Reading your kitchen…".
- Empty state: chip area shows a single helper string "Add ingredients or tap 📷 to start".

### 2. RecipeBatch (push from Home or Recipes)

```
┌─────────────────────────────────┐
│ ← Back        3 recipes         │
├─────────────────────────────────┤
│ MAY 18 · 2:14 PM                │
│ ┌─────────────────────────────┐ │
│ │ Tomato Basil Pasta          │ │
│ │ A light summer dish…        │ │
│ │ 🍅 tomato · 🌿 basil · +2   │ │
│ │ 30 min                      │ │
│ └─────────────────────────────┘ │
│ ┌─────────────────────────────┐ │
│ │ Caprese Salad               │ │
│ └─────────────────────────────┘ │
│ ┌─────────────────────────────┐ │
│ │ Bruschetta                  │ │
│ └─────────────────────────────┘ │
└─────────────────────────────────┘
```
- `UICollectionView` with compositional list layout, no section headers besides the date strip.
- Cards use the `paper2` surface token with a hairline `rule` border.
- "Ingredient badges" inside each card show up to 3 ingredients + "+N" overflow.
- Tap a card → push `RecipeDetailVC(recipe:)`.

### 3. RecipeDetail (push from RecipeBatch)

```
┌─────────────────────────────────┐
│ ← Back                          │
├─────────────────────────────────┤
│ Tomato Basil Pasta              │
│ 30 min                          │
│ ───────────────────────         │
│ Ingredients                     │
│ • 2 cups tomato                 │
│ • 1 bunch basil                 │
│ • …                             │
│ ───────────────────────         │
│ Steps                           │
│ 1. Bring water to boil          │
│ 2. …                            │
└─────────────────────────────────┘
```
- `UIScrollView` with vertically stacked sections.
- No save / share buttons in v1 (deferred).

### 4. Recipes (Tab 2)

```
┌─────────────────────────────────┐
│ Recipes                         │
├─────────────────────────────────┤
│ TODAY                           │
│   2:14 PM · 3 recipes           │
│   tomato, basil, olive oil      │
│ ───────────────────────         │
│ YESTERDAY                       │
│   8:30 PM · 3 recipes           │
│   chicken, rice, broccoli       │
└─────────────────────────────────┘
```
- `UICollectionView` with list appearance.
- Sections: Today, Yesterday, This Week, then grouped by month (e.g., "April 2026").
- Each row: time + recipe count + comma-joined input ingredients (truncated).
- Tap row → push `RecipeBatchVC(batch:)`.
- Empty state: `UIContentUnavailableView` — "No recipes yet. Head to Home to generate some."
- Pull-to-refresh: no-op (data is local), but enables the gesture for consistency.

### 5. Settings (Tab 3)

```
┌─────────────────────────────────┐
│ Settings                        │
├─────────────────────────────────┤
│ APPEARANCE                      │
│ Theme         [System | L | D]  │
│                                 │
│ API                             │
│ OpenAI key    ✓ injected        │
│ Model         gpt-4o            │
│                                 │
│ DATA                            │
│ Clear all recipes               │
│                                 │
│ ABOUT                           │
│ Version       1.0 (1)           │
└─────────────────────────────────┘
```
- `UITableView` `.insetGrouped`.
- Theme row: `UISegmentedControl` with three states wired to `ThemeManager`.
- Key status row: `try? APIKeyProvider.get()` — green ✓ if present, terracotta ⚠ if `missingAPIKey`.
- "Clear all recipes": destructive (terracotta text), confirms via `UIAlertController` before calling `RecipeStore.deleteAll()`.
- Version: `Bundle.main.infoDictionary` reads.

## Theme system

```swift
final class ThemeManager {
    static let shared = ThemeManager()
    enum Style: Int { case system = 0, light = 1, dark = 2 }
    private let key = "userInterfaceStyle"

    var current: Style {
        get { Style(rawValue: UserDefaults.standard.integer(forKey: key)) ?? .system }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key); apply() }
    }

    func apply() {
        let style: UIUserInterfaceStyle = switch current {
            case .system: .unspecified
            case .light: .light
            case .dark: .dark
        }
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.windows }
            .flatMap { $0 }
            .forEach { $0.overrideUserInterfaceStyle = style }
    }
}
```

`SceneDelegate.scene(_:willConnectTo:options:)` calls `ThemeManager.shared.apply()` after building the window. Settings VM mutates `ThemeManager.shared.current`, which triggers `apply()` and updates all windows immediately.

`Colors.swift` defines tokens as `UIColor` dynamic providers — every color is light/dark-aware automatically:

```swift
extension UIColor {
    static let paper = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 28/255, green: 26/255, blue: 22/255, alpha: 1)
            : UIColor(red: 245/255, green: 241/255, blue: 232/255, alpha: 1)
    }
    // ink, inkSoft, rule, paper2, sage, terracotta, butter — same pattern
}
```

## Testing strategy

### Targets

- `FridgeChefTests` (XCTest, fast, no host app required)
- `FridgeChefUITests` (XCUITest) — **one** happy-path smoke test per tab (3 total). Uses a launch argument (`--ui-test-stub`) that `SceneDelegate` checks via `ProcessInfo.processInfo.arguments`; when present, the dependency factory hands VMs a `StubOpenAIClient` (returns canned recipes synchronously) and a `StubRecipeStore` (in-memory only) instead of the real impls.

### Coverage matrix

| Layer | Tested? | How |
|---|---|---|
| `OpenAIClient` request building | ✅ XCTest with `URLProtocol` stub | URL, method, headers (Authorization, Content-Type), body shape (model, messages, response_format) |
| `OpenAIClient` response decoding | ✅ XCTest | structured-output JSON → `[Recipe]` |
| `OpenAIError` mapping by status code | ✅ XCTest | 401→unauthorized, 429→rateLimited, 5xx→server, malformed→invalidResponse |
| `APIKeyProvider` | ✅ XCTest with custom Bundle | missing key throws `.missingAPIKey`, present key returns |
| `RecipeStore` save/load round-trip | ✅ XCTest with in-memory `NSPersistentContainer` | save → allBatches() returns the same batch decoded equally |
| `RecipeStore.deleteAll` | ✅ XCTest | cascade-deletes recipes too |
| `ThemeManager` | ✅ XCTest | UserDefaults persistence, enum round-trip, Style → UIUserInterfaceStyle mapping |
| `HomeVM` | ✅ XCTest, stubs injected | chip add/remove, generate from text, generate from image, error states, cancellation on new request |
| `RecipeBatchVM` | ✅ XCTest | state init from batch |
| `RecipeDetailVM` | ✅ XCTest | trivial — included for symmetry |
| `RecipesVM` | ✅ XCTest, stub RecipeStore | grouping by relative date, deletion notification → reload |
| `SettingsVM` | ✅ XCTest | theme set, clear-all confirmation flow, key status read |
| ViewControllers, cells, custom views | ❌ no unit tests | verify by running the app + manual screenshot |
| End-to-end happy paths | ⚠️ XCUITest smoke | one per tab — add chip → generate → see batch → see in Recipes |

### Per-feature TDD cycles

Every feature in the plan follows red → green → refactor:
1. Write the failing tests for that feature's VM (or service)
2. Implement just enough code to pass
3. Refactor if the design is unclear
4. Build the VC + Views — no unit tests; manual screenshot verification
5. (Once `XcodeBuildMCP` loads) drive the simulator to verify visual flow
6. Commit feature, move to next

### Manual smoke checklist (before tagging a build)

1. Fresh install → Home shows empty chip area + helper text
2. Type 3 ingredients → "Suggest recipes" enables
3. Tap "Suggest" → spinner → push to RecipeBatch with 3 cards
4. Tap a card → RecipeDetail renders correctly
5. Back, back → Home still has chips
6. Tap 📷 → action sheet → choose from library → photo picked → spinner → 3 cards
7. Recipes tab → shows both batches under Today
8. Tap a batch → opens RecipeBatchVC
9. Settings → toggle theme System / Light / Dark → all screens update immediately
10. Settings → Clear all recipes → confirm → Recipes tab is empty
11. Kill app, relaunch → Recipes still empty, theme choice preserved

## File layout

```
recipe-ingredients-ios/
├── README.md
├── .gitignore
├── .mcp.json                                ← XcodeBuildMCP for this project
├── scripts/
│   └── inject-openai-key.sh                 ← Run Script Phase
├── docs/superpowers/specs/2026-05-18-fridgechef-ios-v1-design.md
├── FridgeChef.xcodeproj/
└── FridgeChef/
    ├── App/
    │   ├── AppDelegate.swift
    │   ├── SceneDelegate.swift
    │   ├── RootTabBarController.swift
    │   └── Info.plist
    ├── Features/
    │   ├── Home/
    │   │   ├── View/
    │   │   │   ├── HomeVC.swift
    │   │   │   ├── IngredientChipView.swift
    │   │   │   ├── PhotoSourceActionSheet.swift
    │   │   │   └── RecipeCardCell.swift
    │   │   └── ViewModel/
    │   │       └── HomeVM.swift
    │   ├── RecipeBatch/
    │   │   ├── View/
    │   │   │   ├── RecipeBatchVC.swift
    │   │   │   └── RecipeBatchCardCell.swift
    │   │   └── ViewModel/
    │   │       └── RecipeBatchVM.swift
    │   ├── RecipeDetail/
    │   │   ├── View/
    │   │   │   └── RecipeDetailVC.swift
    │   │   └── ViewModel/
    │   │       └── RecipeDetailVM.swift
    │   ├── Recipes/
    │   │   ├── View/
    │   │   │   ├── RecipesVC.swift
    │   │   │   └── RecipesBatchCell.swift
    │   │   └── ViewModel/
    │   │       └── RecipesVM.swift
    │   └── Settings/
    │       ├── View/
    │       │   └── SettingsVC.swift
    │       └── ViewModel/
    │           └── SettingsVM.swift
    ├── SharedModels/
    │   ├── Recipe.swift
    │   └── RecipeBatch.swift
    ├── Services/
    │   ├── Networking/
    │   │   ├── OpenAIClient.swift
    │   │   ├── OpenAIError.swift
    │   │   ├── APIKeyProvider.swift
    │   │   └── Prompts.swift                ← system + vision prompts as String constants
    │   ├── Persistence/
    │   │   ├── CoreDataStack.swift
    │   │   ├── RecipeStore.swift
    │   │   ├── RecipeBatchEntity+ext.swift
    │   │   ├── RecipeEntity+ext.swift
    │   │   └── FridgeChef.xcdatamodeld
    │   └── Theme/
    │       └── ThemeManager.swift
    ├── DesignSystem/
    │   ├── Colors.swift
    │   ├── Typography.swift
    │   ├── Spacing.swift
    │   └── Fonts/
    │       ├── Fraunces-Regular.ttf
    │       ├── Fraunces-Bold.ttf
    │       ├── DMSans-Regular.ttf
    │       └── DMSans-Medium.ttf
    └── Resources/
        └── Assets.xcassets
FridgeChefTests/
├── Features/
│   ├── HomeVMTests.swift
│   ├── RecipeBatchVMTests.swift
│   ├── RecipeDetailVMTests.swift
│   ├── RecipesVMTests.swift
│   └── SettingsVMTests.swift
├── Services/
│   ├── OpenAIClientTests.swift
│   ├── APIKeyProviderTests.swift
│   ├── RecipeStoreTests.swift
│   └── ThemeManagerTests.swift
└── Stubs/
    ├── StubOpenAIClient.swift
    └── StubRecipeStore.swift
FridgeChefUITests/
└── SmokeTests.swift                          ← one happy-path test per tab
```

## Build settings

- Min deployment: iOS 17.0
- Swift 5.10+ (Xcode 16+)
- Bundle ID: `com.baha.fridgechef`
- Custom fonts (`Fraunces-Regular`, `Fraunces-Bold`, `DMSans-Regular`, `DMSans-Medium`) registered via `UIAppFonts` in `Info.plist`
- Info.plist additions:
  - `NSCameraUsageDescription` — "FridgeChef needs the camera to photograph your ingredients."
  - `NSPhotoLibraryUsageDescription` — "FridgeChef needs photo access to read images of your ingredients."
  - `OPENAI_API_KEY` — empty placeholder string in source; populated by Run Script Phase
- Run Script Phase: `bash scripts/inject-openai-key.sh` — placed after "Copy Bundle Resources"
- `.mcp.json` at project root: registers `XcodeBuildMCP` for this project's Claude Code sessions

## Design system (port from Spend·book + dark variants)

| Token | Light | Dark | Use |
|---|---|---|---|
| `paper` | `#f5f1e8` | `#1c1a16` | Window background |
| `paper2` | `#efe9dc` | `#26231e` | Card / row surface |
| `ink` | `#2c2a26` | `#f0ece4` | Primary text |
| `inkSoft` | `#6b6862` | `#a8a39a` | Secondary text |
| `rule` | `#ddd7ca` | `#3a3631` | Hairline separators |
| `sage` | `#87a878` | `#a3c594` | Primary accent (Suggest button, success, focus) |
| `terracotta` | `#c97b5c` | `#e09275` | Destructive / warning / time pills |
| `butter` | `#f0e4b8` | `#3e3823` | Chip highlight |

Dark values are first-pass — tweak after `/design-review` on the live simulator.

**Typography:**
- Display: Fraunces (Regular, Bold) — large titles, dollar amounts, recipe titles
- Body: DM Sans (Regular, Medium) — everything else
- Bundle `.ttf` files in `DesignSystem/Fonts/`, register via `UIAppFonts`

**Spacing scale:** 4 / 8 / 12 / 16 / 24 / 32 / 48 pt — exposed as `Spacing.s4` through `Spacing.s48`.

## Implementation plan phases

The detailed phased plan is generated by `writing-plans`. High-level order:

1. **Scaffold** — create Xcode project, full folder structure, `.mcp.json`, register fonts, wire Run Script Phase, empty tab bar with 3 placeholder tabs builds and launches on simulator
2. **DesignSystem** — Colors (light + dark dynamic providers), Typography, Spacing, ThemeManager (TDD on ThemeManager)
3. **Networking + key bootstrap** — APIKeyProvider, OpenAIClient (both image + text variants), OpenAIError, structured-output decoder, Prompts. TDD throughout
4. **Persistence** — CoreDataStack, RecipeStore + entity extensions. TDD
5. **Home feature** — HomeVM (chip add/remove, image flow, suggest), HomeVC, IngredientChipView, PhotoSourceActionSheet. VM-TDD; VC manual
6. **RecipeBatch feature** — VM + VC + cards, push from Home, save on appear
7. **RecipeDetail feature** — VM + VC
8. **Recipes feature** — VM + VC, grouped sections, tap-to-open
9. **Settings feature** — VM + VC, theme picker, clear-data, key status
10. **UI smoke tests** — 3 XCUITest happy paths (one per tab)
11. **Visual polish** — `/design-review` on the running simulator in light + dark, fix anything off

## Open questions / known unknowns

- **Image size limit at OpenAI** — GPT-4o accepts images up to 20MB base64-encoded. We resize to ≤1024px first which keeps JPEG well under 1MB. No issue expected.
- **`response_format: json_schema` model coverage** — verified available on `gpt-4o` (2024-08-06 and later snapshots). Confirm `gpt-4o` alias points to a snapshot that supports it at build time; if not, pin to `gpt-4o-2024-08-06`.
- **Font licensing** — Fraunces (SIL OFL) and DM Sans (SIL OFL) are both free to bundle. Carried over from Spend·book.
- **iPad** — runs in compatibility mode. No bespoke iPad layout in v1.
- **Telemetry / crash reporting** — none in v1. Sentry candidate for v2.
- **API cost** — at ~$5/1M input tokens for gpt-4o, each text-only generate is ~$0.001; each image generate is ~$0.005. Negligible for personal use.
