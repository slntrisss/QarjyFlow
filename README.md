# QarjyFlow

A native iOS personal finance app, built incrementally from the supplied FinFlow screen reference. QarjyFlow is the working name; branding is not final.

## Current milestone: local category management

The running app now has a Home getting-started screen and a **Categories** tab. Create categories with a name, income/expense type, icon, and color. Tap to edit; swipe or long-press to archive, restore, or delete. The editor uses large icon tiles and explicit color swatches (rather than tint-dependent native menu labels). Search and the Active/Archived selector help manage larger lists. There is no artificial category-count limit, and no categories are inserted automatically.

Categories are saved using SwiftData on the device. There is no bank connection, login, network request, or app-level cloud sync (`cloudKitDatabase: .none`). Normal device backups are a separate OS concern: disabling app sync does not imply exclusion from device backup. Export/restore remains a future feature; local persistence alone is not a backup strategy.

The original Home dashboard is available through **Home → View Sample Dashboard** and its previews. Its demo figures are never mixed with saved categories. **Transaction entry, balances, and budgets are not implemented yet.** Every category is therefore currently unused. Before transactions/budgets are introduced, deletion must check references (and used categories must be archived or reassigned rather than deleted).

### Categories, amounts, and transfers

A category is a classification, not a balance. A transaction records an actual amount and date; a monthly budget sets a planned amount for a category. Neither transaction entry nor budget editing is implemented yet, so the category editor intentionally has no amount field.

The next ledger should distinguish:

- Income: salary received or investment dividends received.
- Expense: groceries, shopping, or investment fees.
- Transfer: moving money between your own cash, savings, or brokerage accounts. This does not create income or expense.
- Investment purchase: exchanging brokerage cash for an asset; track separately from everyday spending when asset tracking is implemented.

Accounts here mean local bookkeeping records, not connected bank accounts. Do not use an expense category to represent a savings transfer just because transfer entry is not implemented. Budget reservations for savings also need to stay separate from actual transfers to avoid double-counting.

### Editor interaction and concurrency

The add button has a 44-point minimum hit region. Icon/color options use larger tiles with selection indicators and accessible names, following [Apple's button guidance](https://developer.apple.com/design/human-interface-guidelines/buttons). Each picker has an interactive preview.

`CategoryEditorView` and its save callback explicitly use `@MainActor`. Its initial draft is created with `if let` instead of passing `CategoryDraft.init` into `Optional.map`, avoiding the reported isolated-initializer function-reference warning. The available Xcode 16.3 compiler type-checks the updated views/previews. A separate strict-concurrency-only warning remains in generated SwiftData predicate code; no unsafe Sendable conformance or concurrency-check suppression was added.

### Category behavior

- Stable UUID identity survives renaming; no record is identified by its display name.
- Names are trimmed, required, limited to 60 characters, and cannot contain control characters internally.
- Duplicate names within the same income/expense type are rejected, including archived categories. Comparison ignores case, accents, and repeated whitespace.
- Editing uses a value draft. Cancel changes nothing; Save validates and explicitly persists before dismissing.
- Failed saves roll back and discard the dedicated category context so stale failed edits cannot appear on later reads. Loading failure never resets or silently replaces the database.
- Archive/restore preserves the record and its ID. Delete requires confirmation.

## Run

1. Open `QarjyFlow.xcodeproj` in Xcode (installed here: 16.3).
2. Select the QarjyFlow scheme and an iPhone simulator running iOS 18 or later. Install an iOS simulator runtime in Xcode Settings if none is available.
3. Press **Cmd+R**. Open **Categories**, tap **+**, enter a name, and save. Tap a row to edit. Swipe or long-press it for archive/delete actions.
4. For previews, open `ContentView.swift` and enable the Canvas.

The currently installed simulator runtime is iOS 26.5, while this Xcode is 16.3 with the iOS 18.4 SDK. Install the matching iOS 18.4 runtime or use a compatible newer Xcode before simulator testing.

The project targets iOS 18+, iPhone and iPad. Simulator builds do not need an Apple developer membership. A real device requires configuring Signing & Capabilities with your Apple account and an appropriate bundle identifier.

This Mac currently selects standalone Command Line Tools. Override that for one build without changing system settings:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project QarjyFlow.xcodeproj -scheme QarjyFlow -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/QarjyFlowDerivedData CODE_SIGNING_ALLOWED=NO build
```

## Inspect components in Xcode

Every view has a named `#Preview` at the bottom of its own file, including a demonstration of the `CardStyle` modifier. Sample category values live in `Features/Home/PreviewData/CategorySnapshot+Demo.swift`; the full screen uses `HomeSnapshot.demo`. These are deterministic fixtures, not random values or live financial data.

Open a view file and show Xcode's Canvas using **Editor → Canvas**. Choose a named preview to inspect that component independently. Navigation previews wrap the component in `NavigationStack`, so category links can open detail screens in interactive previews. A standalone row or chart only renders content; it intentionally has no tap action.

Start with `HomeView.swift` for the overall layout, then open its section types to inspect their previews. For example: `HomeView` → `SpendingCategorySection` → `SpendingDonutChart` or `CategorySpendingRow`. `HomeSummarySection` uses `MoneySummaryCard`, while `.cardStyle()` supplies the shared container appearance.

Additional variants cover dark Home, larger summary text, and category details within/over budget. Preview compilation is separate from rendering: a compatible installed iOS simulator runtime is still needed to run the Canvas.

## Architecture, in Java terms

Our direction is **feature-oriented organization, with MVVM for stateful screens and composition for UI**. Category management now implements MVVM. The original Home design preview remains a View + immutable presentation snapshot; it does not need a ViewModel just to forward constants.

`CategoriesViewModel` owns the category list, filtering, load errors, and user actions. It receives a `CategoryStore` through initialization. `SwiftDataCategoryStore` owns a dedicated context and returns immutable `CategoryItem` values instead of exposing persistence objects to the UI. Financial rules belong in domain types/services; storage belongs behind a persistence boundary. Views render state and forward actions. Small visual components do not each need a ViewModel. This is a project decision, not a SwiftUI requirement.

Current organization:

```text
QarjyFlow/
  Features/Home/
    Models/          HomeSnapshot, CategorySnapshot
    PreviewData/     HomeSnapshot+Demo (also feeds the prototype app)
    Views/           HomeView, CategoryDetailView
      Components/    Home sections, category row, spending chart
  Features/Categories/
    Models/          CategoryItem, CategoryDraft, kind/color/error types
    ViewModels/      CategoriesViewModel
    Persistence/     CategoryStore, SwiftDataCategoryStore, CategoryRecord
    Views/           CategoriesView, CategoryEditorView, Components/
    PreviewData/     Isolated in-memory category stores
  App/               Database startup and failure handling
  Shared/
    Persistence/     AppDatabase (local-only configuration)
    UI/              MoneySummaryCard, CardStyle
    Formatting/      Decimal+Tenge
```

Conventions:

- One primary type per file; a small, tightly coupled helper or extension may live with its owner. Swift does not require Java-style file naming, but we adopt it for discoverability.
- Organize by feature first. Promote components to `Shared` when their responsibility is independent of a feature; do not turn it into a miscellaneous folder.
- Extract cohesive sections and repeated visual patterns, not every `Text` or `HStack`. `HomeView` composes the screen; section views own layout details.
- Use explicit value inputs for visual components. Keep navigation in the screen/feature sections, not in the reusable row or money card.
- Prefer a single source of truth: totals and budget alerts are derived from the snapshot, not stored independently.
- Add abstractions for real responsibilities and test seams, not to maximize layers or protocol counts.

Swift structs are value types, not exactly Java records. They can have mutable properties, initializers, methods, and computed properties. Our snapshot structs use `let` fields and serve a record-like role. SwiftUI views are also structs, but describe UI rather than representing DTOs. See [Swift's value/reference types guide](https://www.swift.org/documentation/articles/value-and-reference-types.html).

| Swift / iOS | Closest Java backend concept |
| --- | --- |
| `QarjyFlowApp` | Application entry point / composition root |
| SwiftUI `View` | Declarative presentation, not a REST controller |
| `HomeSnapshot` struct | Immutable response DTO / record |
| `Decimal` | `BigDecimal` for money |
| `CategoriesViewModel` | Screen state and application actions |
| `CategoryRecord` / SwiftData | Persisted entity / ORM-like local persistence |

`Features/Home` owns the Home presentation and sample snapshot. Keep calculations out of view layout. Add domain services, persistence, and protocols when actual behavior requires them; no generic repository framework yet. `Double` is used only at the chart/progress display boundary, never for ledger arithmetic.

SwiftUI describes the interface from state; observed state changes cause relevant views to update. See [Apple's model-data guide](https://developer.apple.com/documentation/SwiftUI/Managing-model-data-in-your-app).

## Development roadmap

1. **Foundation / design review:** Home prototype and category details (current). Review on iPhone, including large text and dark mode.
2. **First usable slice:** category management and local persistence are implemented. Next: manually add, list, edit, and delete expense/income transactions; persist locally; derive Home totals from those records. Test validation, totals, date boundaries, and persistence.
3. **Planning:** income onboarding, allocation templates, editable monthly budgets, over-budget states. Preserve historical months when editing a plan.
4. **Analysis:** categories, merchants, trends, calendar, monthly summary. Calculate from one ledger, not independent screen totals.
5. **Extended finance:** accounts, transfers, savings goals, net worth, and free-to-spend rules after accounting semantics are agreed.
6. **Release preparation:** accessibility, localization, backup/export, privacy decisions, migrations, icon, device testing, and TestFlight.

Each milestone should be small enough to explain, run, and verify before moving forward. Screenshots are design inputs, not instructions to execute or a complete product specification.

## Decisions before real transactions

- Agreed: manual entry and on-device storage, without bank integrations, login, or app cloud sync.
- KZT only initially? Display language: English, Russian, or Kazakh?
- Does saving mean a transfer to another owned account or a budget reservation? Transfers must not count as income or expenses.
- Does monthly income mean planned income or money actually received? Keep those concepts separate.
- What is “available”: unallocated budget, cash balance, or safe-to-spend after commitments?
- Which iPhone/iOS versions must be supported?

## Verification

`Package.swift` is a small test harness that compiles the same category models, ViewModel, and SwiftData store on macOS. It is not a second app and adds no external dependencies. Open `QarjyFlow.xcodeproj` to work on the iOS UI.

On this Mac/Xcode installation, run:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer SDKROOT=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX15.4.sdk MACOSX_DEPLOYMENT_TARGET=15.0 /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift test --scratch-path /tmp/QarjyFlowCategoryTests -Xswiftc -target -Xswiftc arm64-apple-macosx15.0
```

All 8 tests passed. The tests cover CRUD, stable identity, validation, archived-name conflicts, search/filter updates, isolated in-memory stores, disk-container reopening, and rollback after a rejected save. The failure-path test intentionally opens a read-only store, so its permission-error logs are expected. These tests verify the actual SwiftData store on macOS, not an iOS app relaunch. All iOS source and preview macros have also been type-checked against the iOS 18.4 SDK. A full iOS build and interactive visual QA remain pending the Xcode/runtime mismatch.

Manual checks once a compatible simulator is available:

1. Add an expense category with a custom name/icon/color and confirm it appears.
2. Edit it, cancel, and confirm the original is unchanged; then edit and save.
3. Try a duplicate name and confirm the editor stays open with a clear error.
4. Archive it, select Archived, and restore it.
5. Restart the app and confirm the category survives.
6. Delete with confirmation and verify it remains deleted after restarting.
7. Check large text, dark mode, and VoiceOver labels in Canvas/on-device.

## Git

Git was already initialized on `main` with an initial commit. `.gitignore` excludes build products, user-specific Xcode files, and common credential files. Ignore rules do not untrack files already committed.

```sh
git status
git diff
git add .gitignore README.md QarjyFlow QarjyFlow.xcodeproj/project.pbxproj
git commit -m "Add initial Home screen prototype and development guide"
```

A remote repository is separate from local Git. Choose its destination and visibility before publishing. Never commit real financial exports, API tokens, or signing credentials.
