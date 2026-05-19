---
title: FridgeChef — Home → Catalog Redesign (v1.1)
tags: [fridgechef, ios, design, catalog, ui]
created: 2026-05-18
updated: 2026-05-18
status: approved
supersedes: docs/superpowers/specs/2026-05-18-fridgechef-ios-v1-design.md (Home only)
---

## Summary

Replace the chips-based Home tab with a "Recipe Catalog" layout inspired by a reference screenshot the user shared. Top text input takes a dish name and returns 3 variations; a 2×2 grid of category cards (Breakfast / Lunch / Dinner / From my fridge) generates 3 fresh recipes per tap; a central sparkle button generates a random-meal + random-style surprise. Each card carries a "Today: <recipe>" subtitle backed by a once-per-day GPT-4o call cached in `UserDefaults`. Outline SF Symbols throughout. Recipes tab + Settings tab stay unchanged.

## Why

User feedback after v1: chips-based input felt clunky for "I just want recipe ideas" use. The reference screenshot showed a cleaner, browse-style catalog with meal-type shortcuts and a magic "surprise me" button. The redesign keeps the GPT-4o backend and Core Data history intact — only the Home tab is reshaped.

## Scope (this spec)

- **In scope:** New Home tab (now: "Catalog" internally, "Home" as the tab label), new `DailyPicksService`, three new `OpenAIClient` methods, deletion of `Features/Home/`, tab-bar icon swap to outline SF Symbols, accessibility IDs, tests.
- **Out of scope (deferred):** Per-meal recipe filtering on the Recipes tab; user-pinnable "Today's pick"; widget/Live Activity; localization beyond English; image thumbnails on cards; haptic on magic button (could be added later as a polish PR).

## Visible layout

Single scrollable screen, MVVM + Combine + diffable collection view (same architecture as v1).

```
┌────────────────────────────────────────┐
│  How to cook…                       ⏎  │  ← UITextField (catalog.input)
│  Enter the name of any dish            │  ← helper label
│                                        │
│  Recipe Catalog                        │  ← Fraunces72pt-Bold 28pt section header
│                                        │
│  ┌──────────────┐  ┌──────────────┐   │
│  │ Breakfast    │  │ Lunch        │   │  ← CategoryCardCell
│  │ ideas        │  │ ideas        │   │     (catalog.card.breakfast/.lunch)
│  │              │  │              │   │
│  │ Today:       │  │ Today:       │   │  ← "Today's pick" subtitle (DM Sans 14pt)
│  │ Avocado toast│  │ Pesto pasta  │   │
│  └──────────────┘  └──────────────┘   │
│  ┌──────────────┐  ┌──────────────┐   │
│  │ Dinner       │  │ From my      │   │  (catalog.card.dinner/.fridge)
│  │ ideas        │  │ fridge       │   │
│  │              │  │              │   │
│  │ Today:       │  │ Snap a photo │   │  ← fridge card has static helper, not AI title
│  │ Miso salmon  │  │              │   │
│  └──────────────┘  └──────────────┘   │
│                                        │
│              ✦                         │  ← UIButton with SF "sparkles" 36pt
│  Can't decide what to cook?            │     (catalog.magic)
│  Just press the button                 │
└────────────────────────────────────────┘

Bottom tab bar (outline SF Symbols):
   Home: house          Recipes: square.grid.2x2          Settings: slider.horizontal.3
```

### Interaction map

| Trigger | VM call | Service call | Result |
|---|---|---|---|
| Text input submit | `generateForDish(name)` | `OpenAIClient.dishVariations(name:)` | Save batch, push `RecipeBatchVC` |
| Tap Breakfast card | `generateForMeal(.breakfast)` | `OpenAIClient.recipesForMeal(.breakfast, style: nil)` | Save batch, push |
| Tap Lunch card | `generateForMeal(.lunch)` | `OpenAIClient.recipesForMeal(.lunch, style: nil)` | Save batch, push |
| Tap Dinner card | `generateForMeal(.dinner)` | `OpenAIClient.recipesForMeal(.dinner, style: nil)` | Save batch, push |
| Tap "From my fridge" card | `openPhotoPicker()` | (PHPicker → `OpenAIClient.recipesFromImage(data:)` — existing) | Save batch, push |
| Tap magic ✦ | `generateRandom()` | `OpenAIClient.recipesForMeal(randomMeal, style: randomStyle)` | Save batch, push |
| App foreground / first launch | `refreshDailyPicksIfStale()` | `OpenAIClient.dailyPicks()` (only if stale) | Update card subtitles via Combine publisher |

All five user-facing paths converge on `RecipeBatchVC` and `RecipeStore.save(batch:)` — no change to either.

## Components

### New files

```
FridgeChef/Features/Catalog/
├── View/
│   ├── CatalogVC.swift              # screen controller — scroll view + input + collection + magic
│   ├── CategoryCardCell.swift       # one cell: label + "Today: <title>" subtitle
│   └── CatalogSectionHeader.swift   # "Recipe Catalog" header view
└── ViewModel/
    └── CatalogVM.swift              # @Published dailyPicks, isLoading, errorMessage

FridgeChef/Services/DailyPicks/
├── DailyPicksService.swift          # protocol + LiveDailyPicksService
└── DailyPicks.swift                 # struct DailyPicks: Codable { breakfast/lunch/dinner: String? }

FridgeChef/Services/Networking/
└── (additions to OpenAIClient.swift + OpenAIClientLive.swift)
```

### Deleted files

```
FridgeChef/Features/Home/             # entire folder (≈600 lines)
├── View/HomeVC.swift
├── View/ChipCell.swift
├── View/ChipsCollectionView.swift
└── ViewModel/HomeVM.swift

FridgeChefTests/Features/Home/
└── HomeVMTests.swift                 # 9 chip tests removed
```

### Modified files

| File | Change |
|---|---|
| `App/AppCoordinator.swift` (and/or `SceneDelegate.swift` — wherever the `UITabBarController` is wired) | Replace `HomeVC()` with `CatalogVC(vm:)`; swap tab bar icons to outline variants (`house`, `square.grid.2x2`, `slider.horizontal.3`) |
| `App/Dependencies.swift` | Add `DailyPicksService` factory; inject into `CatalogVM` |
| `Services/Networking/OpenAIClient.swift` | Add 3 new methods (see API below) + new request/response types |
| `Services/Networking/OpenAIClientLive.swift` | Implement 3 new methods |
| `FridgeChefUITests/SmokeTests.swift` | Update `testHomeShowsCoreElements` to assert new IDs (`catalog.input`, `catalog.card.breakfast`, `catalog.magic`) |

## API contracts

### `OpenAIClient` (additions)

```swift
protocol OpenAIClient {
    // existing — unchanged:
    func recipes(fromIngredients ingredients: [String]) async throws -> [Recipe]
    func recipes(fromImage data: Data) async throws -> [Recipe]

    // new:
    func dishVariations(name: String) async throws -> [Recipe]
    func recipes(forMeal meal: MealType, style: RecipeStyle?) async throws -> [Recipe]
    func dailyPicks() async throws -> DailyPicks
}

enum MealType: String, Codable, CaseIterable {
    case breakfast, lunch, dinner
}

enum RecipeStyle: String, CaseIterable {
    case quick, comfort, healthy, fancy, onePot, vegetarian
}
```

All three new methods use `response_format: { type: "json_schema", schema: ... }` so GPT-4o returns guaranteed-valid JSON. The first two reuse the existing `Recipe` schema. `dailyPicks()` uses a smaller schema:

```jsonc
{
  "type": "object",
  "properties": {
    "breakfast": { "type": "string" },
    "lunch":     { "type": "string" },
    "dinner":    { "type": "string" }
  },
  "required": ["breakfast", "lunch", "dinner"]
}
```

(The fridge card does **not** get a daily pick — its subtitle is the static text "Snap a photo".)

### `DailyPicksService`

```swift
struct DailyPicks: Codable, Equatable {
    var breakfast: String?
    var lunch: String?
    var dinner: String?
    var savedAt: Date
}

protocol DailyPicksService {
    /// Latest cached picks. Nil if no fetch has ever succeeded.
    var current: DailyPicks? { get }

    /// Publisher fires whenever `current` changes.
    var publisher: AnyPublisher<DailyPicks?, Never> { get }

    /// Fetch fresh picks if cache is stale or absent. No-op if fresh.
    func refreshIfStale() async
}

final class LiveDailyPicksService: DailyPicksService {
    init(client: OpenAIClient, defaults: UserDefaults = .standard)
}
```

**Staleness rule:** `current == nil` OR `Calendar.current.startOfDay(for: savedAt) != Calendar.current.startOfDay(for: Date())`. (Refreshes once per calendar day — so it picks up at midnight, not 24h after last fetch.)

**Storage:** JSON-encoded `DailyPicks` in `UserDefaults.standard` under key `"DailyPicksService.cache"`. Tiny payload (~120 bytes), no Core Data needed.

**Failure mode:** On `refreshIfStale()` network failure, keep last cached value and log to `os_log`. Never throw — daily picks must not block UI.

## Data flow walkthroughs

### Path 1: text input submit

1. User types "ramen" in `catalog.input` → presses return
2. `CatalogVC.textFieldShouldReturn` → `vm.generateForDish("ramen")`
3. VM sets `isLoading = true` → publishes → VC shows blurred overlay (reuse current `LoadingOverlay`)
4. VM awaits `client.dishVariations(name: "ramen")` → `[Recipe]`
5. VM calls `store.save(batch: RecipeBatch(prompt: "ramen", recipes: ..., source: .dishName))`
6. VM publishes `pushedBatch = batch.id` → VC observes via Combine → pushes `RecipeBatchVC(batchID: batch.id)`
7. VM sets `isLoading = false`

### Path 2: tap card "From my fridge"

1. Tap → `vm.openPhotoPicker()` → VM publishes `presentPicker = true`
2. VC presents `PHPickerViewController` (reuse existing setup)
3. On image pick → `vm.generateFromImage(data: Data)` → identical to existing camera flow

### Path 3: app foreground

1. `CatalogVC.viewDidAppear` → `vm.refreshDailyPicksIfStale()`. Fires every time the Home tab is shown (including tab switches and post-background returns). Cheap because `refreshIfStale` is a no-op when the cache is for today.
2. VM calls `service.refreshIfStale()` (fire-and-forget `Task`)
3. If stale: service makes one `client.dailyPicks()` call, decodes, saves to defaults, publishes new value
4. VM subscribes to `service.publisher` in init → re-renders cards reactively
5. While fetching: cards show last-known cache (or "Loading…" if first-ever launch)

## Error handling

| Failure | Behavior |
|---|---|
| OpenAI call fails on user action (text/cards/magic/fridge) | Show top-of-screen `ErrorBanner` ("Couldn't reach OpenAI — try again."), revert `isLoading`. Reuses existing `ErrorBanner` from v1. |
| OpenAI call fails on daily-picks refresh | Silent. Keep cached value, log to Console. Cards continue showing stale picks. |
| GPT-4o returns malformed JSON | `URLSession`/`JSONDecoder` throws → caught by VM → treated as network failure (banner). |
| GPT-4o returns empty recipes array | Existing `RecipeBatchVC` empty state handles it (already covered in v1). |
| `PHPickerViewController` cancelled | No-op, dismiss picker, no error shown. |

## Theming

- All four cards use `Color.surface` (paper/ink dynamic) with 12pt corner radius
- Card label: `Typography.title` (Fraunces72pt-Bold, 20pt), `Color.ink`
- "Today: …" subtitle: `Typography.body` (DM Sans, 14pt), `Color.inkMuted`
- Section header: `Typography.display` (Fraunces72pt-Bold, 28pt)
- Magic button: 56pt circle, `Color.terracotta` background, white SF "sparkles" symbol 24pt
- Magic helper text: `Typography.caption` (DM Sans, 13pt), `Color.inkMuted`, centered

All colors use existing dynamic UIColor providers from `DesignSystem/Colors.swift` — no new tokens needed.

## Accessibility

- `catalog.input` — UITextField with `accessibilityLabel = "Dish name"`, `accessibilityHint = "Enter the name of any dish to generate three variations"`
- `catalog.card.breakfast` / `.lunch` / `.dinner` / `.fridge` — each card has `accessibilityLabel = "<title>. Today: <pick>."` (e.g. "Breakfast ideas. Today: Avocado toast.")
- `catalog.magic` — `accessibilityLabel = "Surprise me"`, `accessibilityHint = "Generate three random recipes"`
- `catalog.header` — header text is just `accessibilityElement = false` (the header is decorative; cards have semantic labels)
- All text scales with Dynamic Type (Fraunces + DM Sans set up with `UIFontMetrics` in v1)

## Tests (target: 12 new — net +3 over current 46)

### Unit tests

| File | Cases | Coverage |
|---|---|---|
| `CatalogVMTests` | 5 | (1) `generateForDish` happy path; (2) `generateForMeal(.lunch)` happy path; (3) `generateRandom` selects a meal + style and calls client; (4) `refreshDailyPicksIfStale` triggers service call when stale; (5) error path sets `errorMessage` |
| `DailyPicksServiceTests` | 4 | (1) first launch (no cache → fetch); (2) fresh cache (skip fetch); (3) stale cache (refetch); (4) failure (keep stale value, no throw) |
| `OpenAIClientTests` (additions) | 3 | (1) `dishVariations` request shape + decode; (2) `recipesForMeal` request shape (includes meal + style) + decode; (3) `dailyPicks` request shape + decode |

### UI test updates

- `SmokeTests.testHomeShowsCoreElements` updated: assert presence of `catalog.input`, `catalog.card.breakfast`, `catalog.card.fridge`, `catalog.magic`. (Keep existing assertion style — "elements present" not "full flow", same rationale as v1.)

### Net effect

46 tests today → ~49 after this PR. 9 `HomeVMTests` deleted, 12 new added.

## Migration / behavior changes for existing users

- v1 users who had chip-based ingredient input lose that workflow. There is no migration UI — the chips concept is removed.
- Past recipe batches in Core Data are untouched (Recipes tab still shows them all).
- `RecipeBatch.source` enum gains new cases: `.dishName`, `.meal(MealType)`, `.random`. Existing values (`.ingredients`, `.image`) stay. No Core Data migration needed because `source` is stored as a string and unknown values decode to `.unknown` on read (graceful).

## Risks & mitigations

| Risk | Mitigation |
|---|---|
| Daily-picks call adds a per-day API cost | Cache aggressively (calendar-day key, not 24h timer); use `gpt-4o-mini` for the daily-picks call (3 short strings, <$0.0005/day per user). User-action calls (text/cards/magic/fridge) keep using `gpt-4o` for quality. |
| Reference screenshot is Russian — direct translation could feel awkward | English copy chosen by intent: "Recipe Catalog" / "Breakfast ideas" / "From my fridge" / "Can't decide what to cook? Just press the button" — short, native-feeling |
| Removing chips removes a power-user feature | v2 could add a chips-mode toggle in Settings if requested; for now, ingredient-based generation moves to "From my fridge" (photo) only |
| Magic button feels gimmicky if it always picks the same style early | Pseudo-random with `SystemRandomNumberGenerator`; uniform over 3 meals × 6 styles = 18 combinations |
| `square.grid.2x2` outline symbol may not visually distinguish "Recipes" enough from the Home tab if Home also has a card grid | Test on real device; if confused, switch Recipes icon to `clock.arrow.circlepath` (history connotation) |

## Open questions (none blocking)

None. Design is fully specified.

## Related

- v1 design: `docs/superpowers/specs/2026-05-18-fridgechef-ios-v1-design.md`
- v1 session recap: `~/Desktop/llm-ai-projects/wiki/sessions/2026-05-18-fridgechef-ios-v1-build.md`
- v1 PR: https://github.com/ZeekrBaha/fridgechef-ios/pull/1
