# FridgeChef

> Type a dish, pick a meal idea, or snap your fridge — get 3 recipes you can actually cook.

iOS app with a recipe catalog Home tab: a text field for any dish name, four idea cards (Breakfast / Lunch / Dinner / **From my fridge**), and a magic surprise-me button. Each path returns 3 GPT-4o recipes that persist to a local Core Data history. The fridge-photo path uses GPT-4o Vision to read what's in the picture. UIKit + MVVM + Core Data, iOS 17+, zero third-party Swift dependencies.

<p align="center">
  <img src="docs/screenshots/01-home-light.jpg" alt="FridgeChef Recipe Catalog (light)" width="260" />
  &nbsp;
  <img src="docs/screenshots/04-recipe-batch.jpg" alt="3 recipes returned by GPT-4o" width="260" />
  &nbsp;
  <img src="docs/screenshots/10-home-dark.jpg" alt="FridgeChef Recipe Catalog (dark)" width="260" />
</p>

<p align="center"><sub>Pick a meal idea, type a dish, or snap your fridge — 3 real recipes in ~10 seconds.</sub></p>

---

## Features

- **Recipe Catalog Home** — five entry points on a single screen:
  - text field → type any dish name, get 3 variations
  - **Breakfast / Lunch / Dinner** idea cards → 3 recipes for that meal
  - **From my fridge** card → snap or pick a photo, GPT-4o Vision reads it and suggests recipes
  - **Magic** button → a totally random surprise dish
- **Today's pick on every meal card** — a separate `gpt-4o-mini` daily call seeds each card with a fresh dish title once per calendar day (cached in `UserDefaults`, no spinner on subsequent launches)
- **Structured outputs** — uses OpenAI's `response_format: json_schema` so the model returns valid JSON every time, no string parsing
- **Recipe history** — every generated batch persists to Core Data, browsable in a Recipes tab grouped by relative date (Today / Yesterday / This Week / by month)
- **Recipe detail** — full recipe view with ingredients and numbered steps
- **Theme** — Follow System / Light / Dark, persisted in `UserDefaults`
- **Single-key bootstrap** — no setup screen; OpenAI key is read at build time from a sibling project's `.env` and baked into the built `Info.plist`

## Walkthrough

Real end-to-end run captured from the iOS Simulator. The fridge-photo path uses an Unsplash produce shot injected into the simulator's Photos library via `xcrun simctl addmedia`; GPT-4o Vision identifies the visible vegetables and returns three runnable recipes (in the captured run: Colorful Garden Salad, Zucchini & Broccoli Stir-Fry, Butternut Squash Soup).

### Input photo (used by the "From my fridge" card)

<p align="center">
  <img src="docs/screenshots/00-input-photo.jpg" alt="Produce fridge photo sent to GPT-4o Vision" width="520" />
</p>
<p align="center"><sub>Photo by <a href="https://unsplash.com/photos/photo-1542838132-92c53300491e">Unsplash</a> · free to use, no attribution required (credit shown anyway).</sub></p>

### Recipe Catalog Home

| Light | Dark | What's on screen |
|---|---|---|
| <img src="docs/screenshots/01-home-light.jpg" width="220" /> | <img src="docs/screenshots/10-home-dark.jpg" width="220" /> | Text field ("How to cook…") + 2×2 grid: Breakfast / Lunch / Dinner / From my fridge. Each meal card shows "Today: …" — a fresh daily pick from `gpt-4o-mini`. The fridge card prompts "Snap a photo". Below: a circular magic surprise-me button. |

### After picking a path

| Step | Screenshot | What's happening |
|---|---|---|
| Loading | <img src="docs/screenshots/03-home-loading.jpg" width="200" /> | Inlined overlay with a spinner while GPT-4o responds |
| Recipe batch | <img src="docs/screenshots/04-recipe-batch.jpg" width="200" /> | GPT-4o returned 3 cards |
| Recipe detail | <img src="docs/screenshots/05-recipe-detail.jpg" width="200" /> | Tap a card → full ingredients + numbered steps |
| Recipes history | <img src="docs/screenshots/06-recipes-history.jpg" width="200" /> | Recipes tab — batch grouped under TODAY |
| Settings | <img src="docs/screenshots/07-settings.jpg" width="200" /> | Theme picker, key status (✓ injected), model, version |

### Dark mode

System tokens swap automatically via `UIColor` dynamic providers — no per-screen dark layouts.

| Settings (Dark) | RecipeBatch (Dark) | Home (Dark) |
|---|---|---|
| <img src="docs/screenshots/08-settings-dark.jpg" width="220" /> | <img src="docs/screenshots/09-recipe-batch-dark.jpg" width="220" /> | <img src="docs/screenshots/10-home-dark.jpg" width="220" /> |

> **"Where did the picture-attachment feature go?"** Still here — it's now the **From my fridge** card (bottom-right of the 2×2 grid). Tapping it opens the photo picker exactly like before; the image is sent to GPT-4o Vision via the same `suggestRecipes(imageJPEG:)` path. Nothing about the vision flow was removed in the catalog redesign.

## Architecture

```mermaid
graph TB
    subgraph "FridgeChef (UIKit, MVVM + Combine, iOS 17+)"
        CatalogVC[CatalogVC] <--> CatalogVM[CatalogVM]
        RecipeBatchVC[RecipeBatchVC] <--> RecipeBatchVM[RecipeBatchVM]
        RecipeDetailVC[RecipeDetailVC] <--> RecipeDetailVM[RecipeDetailVM]
        RecipesVC[RecipesVC] <--> RecipesVM[RecipesVM]
        SettingsVC[SettingsVC] <--> SettingsVM[SettingsVM]

        CatalogVM --> OpenAIClient
        CatalogVM --> RecipeStore
        CatalogVM --> DailyPicksService
        DailyPicksService --> OpenAIClient
        RecipeBatchVM --> RecipeStore
        RecipesVM --> RecipeStore
        SettingsVM --> ThemeManager
        SettingsVM --> RecipeStore
        SettingsVM --> APIKeyProvider

        CatalogVC -. push .-> RecipeBatchVC
        RecipesVC -. push .-> RecipeBatchVC
        RecipeBatchVC -. push .-> RecipeDetailVC

        OpenAIClient[OpenAIClient<br/>protocol<br/>dish / meal / image / surprise / dailyPicks]
        RecipeStore[RecipeStore<br/>protocol]
        DailyPicksService[DailyPicksService<br/>UserDefaults cache,<br/>per-calendar-day]
        ThemeManager[ThemeManager<br/>UserDefaults]
        APIKeyProvider[APIKeyProvider<br/>Info.plist]
    end

    OpenAIClient --> OpenAI[api.openai.com<br/>gpt-4o + gpt-4o-mini<br/>+ json_schema]
    RecipeStore --> CoreData[(Core Data<br/>RecipeBatchEntity<br/>→ RecipeEntity)]
    APIKeyProvider --> BuildScript[Run Script Phase<br/>inject-openai-key.sh<br/>reads ../youtube_pdf_reporter/.env]
```

### Data flow — tap a meal idea card

```mermaid
sequenceDiagram
    actor User
    participant CatalogVC
    participant CatalogVM
    participant OpenAIClient
    participant RecipeStore
    participant RecipeBatchVC

    User->>CatalogVC: tap "Breakfast ideas" card
    CatalogVC->>CatalogVM: generateForMeal(.breakfast)
    CatalogVM->>CatalogVM: state = .loading
    CatalogVM->>OpenAIClient: suggestRecipes(forMeal: .breakfast, style: nil)
    OpenAIClient->>OpenAIClient: POST /v1/chat/completions<br/>json_schema response_format
    OpenAIClient-->>CatalogVM: [Recipe] x3
    CatalogVM->>RecipeStore: save(batch)
    CatalogVM->>CatalogVM: state = .loaded(batch)
    CatalogVC->>RecipeBatchVC: push (via Combine sink)
    RecipeBatchVC->>User: 3 cards
```

The other entry points work the same way, just calling different `OpenAIClient` methods:
- text field → `suggestRecipes(dishName:)`
- **From my fridge** → `suggestRecipes(imageJPEG:)` (GPT-4o Vision, same call as v1)
- magic button → `suggestRecipes(forMeal:style:)` with a random `MealType` + `RecipeStyle`

`DailyPicksService` runs once on app launch and caches three dish titles per calendar day via `gpt-4o-mini`; the meal cards render those as "Today: …" subtitles.

### Key principles

- Each `ViewController` is a thin shell that binds to a `@Published`-driven `ViewModel` via Combine.
- All networking is `async/await` on `URLSession`, called from `Task {}` inside the VM.
- Every VM stores its in-flight `Task` and cancels it on `deinit` or before starting a new request.
- ViewModels depend on **protocols** (`OpenAIClientProtocol`, `RecipeStoreProtocol`) — concrete implementations are injected via `Dependencies` so they can be stubbed in tests.
- The only persistence layer is Core Data. `RecipeStore` exposes plain Swift structs; the `NSManagedObject` layer is invisible above it.
- Light/dark theme uses `UIColor` dynamic providers — every token has both variants and switches automatically with `overrideUserInterfaceStyle`.

## Tech stack

| Layer | Choice |
|---|---|
| UI | UIKit (no SwiftUI) |
| Architecture | MVVM + Combine + diffable data sources |
| Concurrency | `async/await` + `Task` |
| Networking | `URLSession` direct to `api.openai.com` |
| Persistence | Core Data (in-app sandbox; no iCloud) |
| Min iOS | 17.0 |
| Swift | 5.10+ |
| Project generator | [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `project.yml` is the source of truth |
| Third-party Swift deps | **None** |
| Fonts | Fraunces (display) + DM Sans (body), bundled `.ttf` |
| Tests | XCTest (unit) + XCUITest (smoke) |

## Project structure

```
recipe-ingredients-ios/
├── README.md
├── project.yml                              ← XcodeGen source of truth
├── scripts/inject-openai-key.sh             ← Run Script Phase
├── docs/
│   ├── superpowers/
│   │   ├── specs/2026-05-18-fridgechef-ios-v1-design.md
│   │   └── plans/2026-05-18-fridgechef-ios-v1.md
│   └── screenshots/
└── FridgeChef/
    ├── App/                                 ← AppDelegate, SceneDelegate, RootTabBar, Dependencies
    ├── Features/                            ← one folder per screen, each with View/ + ViewModel/
    │   ├── Catalog/                         ← Home tab (replaces v1 Home/)
    │   ├── RecipeBatch/
    │   ├── RecipeDetail/
    │   ├── Recipes/
    │   └── Settings/
    ├── SharedModels/                        ← Recipe, RecipeBatch, MealType, RecipeStyle, DailyPicks, Notifications
    ├── Services/
    │   ├── Networking/                      ← OpenAIClient, OpenAIError, APIKeyProvider, Prompts
    │   ├── Persistence/                     ← CoreDataStack, RecipeStore, .xcdatamodeld, entity extensions
    │   ├── DailyPicks/                      ← DailyPicksService (UserDefaults cache, calendar-day staleness)
    │   └── Theme/                           ← ThemeManager
    ├── DesignSystem/                        ← Colors, Typography, Spacing, Fonts/
    └── Resources/
FridgeChefTests/
├── Features/                                ← VM tests
├── Services/                                ← OpenAIClient, RecipeStore, APIKeyProvider, ThemeManager
└── Stubs/                                   ← StubOpenAIClient, StubRecipeStore, StubURLProtocol
FridgeChefUITests/
└── SmokeTests.swift                         ← 3 happy-path XCUITest
```

## Design system

Ported from [Spend·book](../personal-finance-tracker-ios) with dark-mode variants.

| Token | Light | Dark | Use |
|---|---|---|---|
| `paper` | `#f5f1e8` | `#1c1a16` | Window background |
| `paper2` | `#efe9dc` | `#26231e` | Card / row surface |
| `ink` | `#2c2a26` | `#f0ece4` | Primary text |
| `inkSoft` | `#6b6862` | `#a8a39a` | Secondary text |
| `rule` | `#ddd7ca` | `#3a3631` | Hairline separators |
| `sage` | `#87a878` | `#a3c594` | Primary accent (Suggest button) |
| `terracotta` | `#c97b5c` | `#e09275` | Destructive / warning |
| `butter` | `#f0e4b8` | `#3e3823` | Chip highlight |

**Typography:** Fraunces 72pt (Regular, Bold) for display, DM Sans (Regular, Medium) for body. Both SIL OFL licensed.

**Spacing scale:** `Spacing.s4` … `Spacing.s48` (4 / 8 / 12 / 16 / 24 / 32 / 48 pt).

## Build + run

### Prerequisites

- Xcode 16+
- Homebrew (for XcodeGen)
- An `OPENAI_API_KEY` line in `~/Desktop/llm-ai-projects/youtube_pdf_reporter/.env`

### From clone to running app

```bash
brew install xcodegen          # one-time, ~10 MB
xcodegen generate              # creates FridgeChef.xcodeproj from project.yml

xcodebuild -project FridgeChef.xcodeproj \
  -scheme FridgeChef \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build

APP_PATH=$(xcodebuild -project FridgeChef.xcodeproj -scheme FridgeChef -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/^ *BUILT_PRODUCTS_DIR/ {print $2}' | head -1)

xcrun simctl install booted "$APP_PATH/FridgeChef.app"
xcrun simctl launch booted com.baha.fridgechef
```

The Run Script Phase reads the `.env` file at build time and bakes `OPENAI_API_KEY` into the built `Info.plist`. The key never enters git.

### Why the build script approach

| Approach | Trade-off |
|---|---|
| **Build script reads sibling repo's .env** (chosen) | Zero manual steps; only works on this laptop |
| Setup sheet → Keychain on first launch | Portable; requires user to paste key |
| Hardcoded in source | Don't |
| Tiny proxy backend | Safest; adds infra |

## Testing

```bash
xcodebuild -project FridgeChef.xcodeproj -scheme FridgeChef \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test
```

| Layer | Tool | Tests |
|---|---|---|
| ViewModels | XCTest | CatalogVM + RecipeBatchVM + RecipeDetailVM + RecipesVM + SettingsVM |
| OpenAIClient | XCTest with `URLProtocol` stub | request shape + response decode + 4xx/5xx mapping for ingredients / image / dishName / forMeal / dailyPicks variants |
| DailyPicksService | XCTest | calendar-day cache hit/miss, silent error path, publisher emits on refresh |
| RecipeStore | XCTest with in-memory `NSPersistentContainer` | save / load / byId / deleteAll / ordering |
| APIKeyProvider | XCTest with custom `Bundle` | present / missing / empty |
| ThemeManager | XCTest with custom `UserDefaults` | default / light / dark / style mapping |
| UI smoke | XCUITest with launch-arg stub injection | 3 (one per tab — catalog cards present, recipes empty state, theme toggle) |

**Total:** 49 unit tests + 3 UI smoke = **52 tests.**

The end-to-end catalog → generate → push flow is exercised by `CatalogVMTests` + `RecipeBatchVMTests` rather than XCUITest, because keyboard timing and navigation animations make the XCUITest version flaky in simulator.

### Pre-commit secret-scan hook

A `.git/hooks/pre-commit` script blocks any commit whose staged diff contains an OpenAI / Anthropic / AWS / GitHub PAT / Google API key pattern. Bypass with `git commit --no-verify` if you ever need to. Hooks aren't versioned by git — re-install on fresh clones.

## What's deferred to v2

- Favoriting / starring individual recipes
- Editing saved recipes
- Share sheet on recipe detail
- Crash reporting (Sentry SDK)
- iPad bespoke layout, Mac Catalyst
- Dietary filters (vegetarian, gluten-free, allergens)
- Cooking timer / step-by-step mode
- Backend proxy for the OpenAI key
- iCloud sync of recipe history
- Multi-language

## Design + plan docs

**v1 (chip-based Home → 3 recipes)**

- 📐 **[v1 Design spec](docs/superpowers/specs/2026-05-18-fridgechef-ios-v1-design.md)** — the full architectural decisions, screen mocks, error handling, testing strategy
- 🛠 **[v1 Implementation plan](docs/superpowers/plans/2026-05-18-fridgechef-ios-v1.md)** — 11 phases, 56 tasks, every task with code blocks and exact commands

**v1.1 (Recipe Catalog Home redesign)**

- 📐 **[Catalog redesign spec](docs/superpowers/specs/2026-05-18-fridgechef-catalog-redesign-design.md)** — five entry points, DailyPicksService, new OpenAIClient methods
- 🛠 **[Catalog redesign plan](docs/superpowers/plans/2026-05-18-fridgechef-catalog-redesign.md)** — 10 TDD phases, ~40 tasks, replaces the v1 Home tab

## License

Personal project — no license. Don't redistribute the bundled `OPENAI_API_KEY` if you fork.
