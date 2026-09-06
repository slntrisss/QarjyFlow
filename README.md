# QarjyFlow

A native iOS personal finance app, built incrementally from the supplied FinFlow screen reference. QarjyFlow is the working name; branding is not final.

## Current milestone: local ledger and persisted monthly planning

The running app now has **Home**, **Activity**, and **Plan** tabs. Categories live under **Home → Settings → Categories** and remain directly available from the transaction editor. Home shows recorded income, expenses, and net cash flow for the current calendar month. Activity supports adding, editing, deleting, searching, and filtering income/expense transactions. Create categories from Settings or the transaction editor with a name, income/expense type, icon, and color. Tap to edit; swipe or long-press to delete. The editor uses large icon tiles and explicit color swatches. There is no artificial category-count limit, and no categories are inserted automatically.

Categories are saved using SwiftData on the device. There is no bank connection, login, network request, or app-level cloud sync (`cloudKitDatabase: .none`). Normal device backups are a separate OS concern: disabling app sync does not imply exclusion from device backup. Export/restore remains a future feature; local persistence alone is not a backup strategy.

The original Home dashboard remains available in Xcode previews only; its demo figures are never mixed with saved data. **Account balances, transfers, and investment tracking are not implemented yet.** Plan stores one local plan for the current month, including expected-income sources, custom sections, fixed or percentage allocations, and expense-category references. It compares expected income with recorded Activity income and shows Planned, Spent, and Remaining for category-linked allocations. Expenses without an allocation are reported as Unplanned spending. Categories used by transactions or plans cannot be deleted or switched between income and expense because their historical references must remain valid.

### Categories, amounts, and transfers

A category is a classification, not a balance. A transaction records an actual amount and date; a monthly Plan allocation sets an intended amount for an expense category or future purpose. Enter actual amounts in **Activity → +** and planned amounts in **Plan → Add**. The category editor intentionally has no amount field.

The ledger distinguishes income and expenses now; transfers and investment purchases remain separate future flows:

- Income: salary received or investment dividends received.
- Expense: groceries, shopping, or investment fees.
- Transfer: moving money between your own cash, savings, or brokerage accounts. This does not create income or expense.
- Investment purchase: exchanging brokerage cash for an asset; track separately from everyday spending when asset tracking is implemented.

Accounts here mean local bookkeeping records, not connected bank accounts. Do not use an expense category to represent a savings transfer just because transfer entry is not implemented. Budget reservations for savings also need to stay separate from actual transfers to avoid double-counting.

### Editor interaction and concurrency

The add button has a 44-point minimum hit region. Icon/color options use larger tiles with selection indicators and accessible names, following [Apple's button guidance](https://developer.apple.com/design/human-interface-guidelines/buttons). Each picker has an interactive preview. `AmountTextField` also has a preview showing its formatted display and underlying draft value.

Views and observable ViewModels stay on `MainActor`; production database work does not. Both asynchronous store adapters share one `LedgerDatabase` actor. Its container is opened off the UI executor, and its synchronous repository operations serialize validation, reads, and saves without suspending mid-operation. This protects category references even when transaction creation and category deletion arrive concurrently. A ledger snapshot reads categories and transactions together.

Only immutable `Sendable` values cross the persistence boundary. SwiftData contexts and records never reach views. The project no longer infers `MainActor` for every type; UI state explicitly declares its isolation. In Java terms, `await` yields while the database worker runs, then the ViewModel resumes on the UI executor to publish results. It is not a blocking `.get()`.

Editors await successful saves before dismissing and prevent repeat submissions. Failed saves retain edits. Refresh revision checks prevent a late response from overwriting a newer mutation. Preview-only adapters use isolated in-memory repositories on the main actor for immediately available Canvas fixtures; the live composition never uses them. No `@unchecked Sendable` or concurrency-check suppression was added. A separate complete-concurrency diagnostic pass on Xcode 16.3 still reports SDK key-path `Sendable` warnings in SwiftData predicates and sorting. Those remain visible; this is not a claim of a warning-free Swift 6 language-mode build.

### Category behavior

- Stable UUID identity survives renaming; no record is identified by its display name.
- Names are trimmed, required, limited to 60 characters, and cannot contain control characters internally.
- Duplicate names within the same income/expense type are rejected. Comparison ignores case, accents, and repeated whitespace.
- Editing uses a value draft. Cancel changes nothing; Save validates and explicitly persists before dismissing.
- Failed saves roll back and discard the dedicated category context so stale failed edits cannot appear on later reads. Loading failure never resets or silently replaces the database.
- Deleting an unused category requires confirmation; deleting a used category is rejected.

### Transaction behavior and storage upgrade

- KZT only, with amounts saved as positive `Int64` tiyn (1 ₸ = 100 tiyn). Income/expense type supplies the direction; negative input is not accepted.
- The amount field inserts space grouping while typing (`1000` → `1 000`). It accepts a dot or comma and at most two fractional digits, preserving partial decimal input and the caret during middle edits. Pasted space-grouped amounts are supported; ambiguous punctuation, negative signs, excess precision, and oversized amounts are rejected rather than silently rewritten. The draft retains ungrouped text, and the tiyn parser never uses `Double` or rounds input.
- Amount, matching category, and date are required. Future calendar days are rejected; merchant/source and note are optional.
- Transactions reference stable category UUIDs. Store operations validate the references and prevent deletion/type changes of used categories. This is an application-enforced reference, not a SwiftData cascading relationship. All writes must go through these stores.
- Each transaction operation uses a fresh, non-autosaving context, explicitly saves, and discards failed edits. Category operations also refresh their context to see transaction writes from the other store.
- The database schema adds `TransactionRecord` without changing `CategoryRecord`. A disk migration test creates the original category-only schema, opens it with the expanded schema, and verifies that the existing category ID/name survive and new transactions persist. Do not reset or delete the real store to upgrade it.
- A shared `TransactionsViewModel` updates Home and Activity immediately after successful mutations. Returning from category management refreshes names and newly added categories without discarding the transaction draft.
- Monthly net means recorded income minus recorded expenses, not a bank balance, savings figure, or safe-to-spend amount. The month uses the device's current calendar/time zone, with an exclusive next-month boundary.
- Home does not display zero totals after an initial load failure. A failed refresh preserves the last successful snapshot and shows a warning.

## Run

1. Open `QarjyFlow.xcodeproj` in Xcode (installed here: 16.3).
2. Select the QarjyFlow scheme and an iPhone simulator running iOS 18 or later. Install an iOS simulator runtime in Xcode Settings if none is available.
3. Press **Cmd+R**. Create an expense category in **Home → Settings → Categories → +**. Then open **Activity → +**, enter an amount, choose that category, and save.
4. Tap an Activity row to edit; swipe or long-press to delete with confirmation. Home totals update immediately. Use an income category to record salary.
5. For previews, open `ContentView.swift` and enable the Canvas.

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

`CategoriesViewModel` owns the category list, filtering, load errors, and user actions. It receives a `CategoryStore` through initialization. `SwiftDataCategoryStore` forwards asynchronous operations to the shared database actor; its `CategoryRepository` performs synchronous SwiftData work within that actor. It returns immutable `CategoryItem` values instead of exposing persistence objects to the UI. Financial rules belong in domain types/services; storage belongs behind a persistence boundary. Views render state and forward actions. Small visual components do not each need a ViewModel. This is a project decision, not a SwiftUI requirement.

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
    Persistence/     CategoryStore, SwiftDataCategoryStore, CategoryRepository, CategoryRecord
    Views/           CategoriesView, CategoryEditorView, Components/
    PreviewData/     Isolated in-memory category stores
  Features/Transactions/
    Models/          TransactionItem, TransactionDraft, TransactionSummary
    ViewModels/      TransactionsViewModel
    Persistence/     TransactionStore, SwiftDataTransactionStore, TransactionRepository, TransactionRecord
    Views/           ActivityView, TransactionEditorView, Components/
    PreviewData/     Isolated in-memory ledger fixtures
  Features/Settings/
    Views/           SettingsView and Categories navigation
  Features/Plan/
    Models/          Allocation rule, allocation, group (prototype only)
    ViewModels/      PlanViewModel
    Views/           Overview, allocation editor, interactive host, Components/
    PreviewData/     Fictional income and allocations
  App/               Shared store composition, async startup and failure handling
  Shared/
    Design/          Shared ThemeColor palette
    Persistence/     AppDatabase, LedgerDatabase actor, LedgerSnapshot
    UI/              MoneySummaryCard, CardStyle, AmountTextField
    Money/           Exact positive amount parsing and input grouping
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

## Review monthly Plan

Open the **Plan** tab or a named preview in `Features/Plan/Views/PlanView.swift`. On first use, create the current month's empty plan; sample values are confined to previews. Expected income supports multiple editable sources and never creates Activity transactions. Add fixed-amount or percentage allocations for active expense categories or standalone future purposes. The sliders toolbar button opens **Plan Sections**, where defaults can be renamed, styled, reordered, deleted, or extended. Deleting an allocation or a whole section releases its planned amount to Unallocated and never deletes an Activity transaction.

The fictional August plan expects 800,000 ₸ and initially allocates 770,000 ₸ across Needs, Future, Lifestyle, and Free. Tap Rent to edit its fixed amount, or Investments to edit 30% of expected income. Applying an edit updates only the in-memory sample. Expected-income sources and section customization behave the same way. Restarting the app resets both. No sample categories or transactions enter the on-disk database.

Prototype assumptions (not finalized persistence rules): Free is an explicit allocation separate from Unallocated; over-allocation is shown with a warning; percentages accept up to two decimals and round the result to the nearest tiyn, with half values rounded up. Future contribution tracking is explicitly unavailable. Actual spending, month navigation/copying, adding allocations, and budget moves are not wired up yet. Expected-income editing is available in the prototype and remains separate from received-income transactions.

## Development roadmap

The Plan tab's imported product context, proposed scope, and unresolved rules are captured in [Plan tab specification](docs/plan-tab-spec.md), based on the ChatGPT conversation **Plan Personal Finance App**. Read this before implementing Plans; the intended feature includes more than expense limits.

1. **Foundation / design review:** Home prototype and category details (current). Review on iPhone, including large text and dark mode.
2. **First usable slice:** categories, income/expense CRUD, local storage, Activity, and recorded Home totals are implemented. Next review the flow on-device, then decide monthly budget behavior.
3. **Planning:** month navigation and copying, allocation templates, category detail drill-down, and budget moves. Preserve historical months when editing a plan.
4. **Analysis:** categories, merchants, trends, calendar, monthly summary. Calculate from one ledger, not independent screen totals.
5. **Extended finance:** accounts, transfers, savings goals, net worth, and free-to-spend rules after accounting semantics are agreed.
6. **Release preparation:** accessibility, localization, backup/export, privacy decisions, migrations, icon, device testing, and TestFlight.

Each milestone should be small enough to explain, run, and verify before moving forward. Screenshots are design inputs, not instructions to execute or a complete product specification.

## Decisions before real transactions

- Agreed: manual entry and on-device storage, without bank integrations, login, or app cloud sync.
- Current first version: KZT and English. Other currencies and localization remain future decisions.
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

Verification on 2026-09-02: **32 tests passed** and all iOS source/previews type-checked. A full simulator build was attempted and blocked because Xcode reports that iOS 18.4 is not installed. The suite also covers concurrent deletion/transaction creation, duplicate-creation races, stale refreshes, and prototype fixed/percentage calculations, customizable-section operations, allocation moves, allocation deletion, and cascading section deletion with correct Unallocated totals. The test suite includes transaction CRUD, amount parsing, monthly boundaries, category protections, adding categories after transactions exist, category-only store migration, and transaction save/load failures, in addition to the original category tests. The category tests cover CRUD, stable identity, validation, archived-name conflicts, search/filter updates, isolated in-memory stores, disk-container reopening, and rollback after a rejected save. The failure-path test intentionally opens a read-only store, so its permission-error logs are expected. These tests verify the actual SwiftData store on macOS, not an iOS app relaunch. All iOS source and preview macros have also been type-checked against the iOS 18.4 SDK. A full iOS build and interactive visual QA remain pending the Xcode/runtime mismatch.

Manual checks once a compatible simulator is available:

1. Create expense and income categories. Add an expense of 12.56 ₸ and an income of 100 ₸ dated this month; confirm Home net is 87.44 ₸.
2. Edit a transaction, cancel, and confirm no change. Save an edit and confirm Home updates.
3. Add another category after transactions exist, then assign it to an existing transaction.
4. Attempt to delete or change the type of a used category and confirm the explanation.
5. Restart the app and confirm categories and transactions survive. Existing installations should upgrade without clearing data.
6. Delete a transaction with confirmation and verify both totals and persistent history update.
7. Check large text, dark mode, keyboard entry, sheet navigation, and VoiceOver on-device. Previews include empty, populated, and editor states.
8. Create the current Plan, add expected income and an allocation, then restart and confirm both restore. Delete the allocation and confirm its amount returns to Unallocated without affecting Activity.

## Git

Git was already initialized on `main` with an initial commit. `.gitignore` excludes build products, user-specific Xcode files, and common credential files. Ignore rules do not untrack files already committed.

```sh
git status
git diff
git add .gitignore README.md QarjyFlow QarjyFlow.xcodeproj/project.pbxproj
git commit -m "Add initial Home screen prototype and development guide"
```

A remote repository is separate from local Git. Choose its destination and visibility before publishing. Never commit real financial exports, API tokens, or signing credentials.
