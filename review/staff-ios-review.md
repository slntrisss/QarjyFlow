# QarjyFlow — Staff iOS Production Readiness Review

**Reviewer role:** Senior Staff iOS Engineer (approval gate for production)
**Date:** 2026-09-06
**Scope reviewed:** entire repository at branch `main` (working tree, including uncommitted changes)
**Build target:** iOS 18.0+, iPhone + iPad, SwiftUI, SwiftData, Swift language mode 5, `SWIFT_APPROACHABLE_CONCURRENCY = YES`

---

## 0. Fixes Applied (2026-09-06, follow-up pass)

Per direction from the app owner: fix Critical/High/Medium now, **defer** the App Store
privacy manifest (ID‑2) and the Swift‑6 / strict‑concurrency migration (ID‑3, ID‑11)
until after the MVP is usable. All changes below are verified against the SPM test
harness (**41 tests pass**, up from 38). SwiftUI‑layer edits could not be compiled here
(no iOS 18.4 runtime installed) and are marked ⚠︎ — build in Xcode to confirm.

| ID | Status | Change |
|---|---|---|
| ID‑1 | ✅ Fixed | `AppDatabase.swift`: added `LedgerSchemaV1: VersionedSchema` + `LedgerMigrationPlan: SchemaMigrationPlan`; container now opens with the migration plan. Category‑only→full upgrade test still passes. |
| ID‑4 | ✅ Partial | `PlanViewModel` no longer references `PlanPreviewData` (production must pass a real store; previews/tests pass an explicit `initialPlan`). Tests + Plan previews updated. **Not done:** `#if DEBUG`‑gating the fixture files — needs every referencing `#Preview` wrapped too; do it in Xcode. TODO note left in `CategoryPreviewData.swift`. |
| ID‑5 | ✅ Fixed | New `Shared/Diagnostics/AppLog.swift` (`os.Logger` per feature). Real error now logged before the generic user string in: `AppRootView` DB‑open, all three repository save‑failure paths, `CategoriesViewModel` / `TransactionsViewModel` / `PlanViewModel` load & mutation catches. |
| ID‑7 / ID‑15 | ✅ Fixed | New `Shared/Money/MoneyFormatting.swift` with one cached `NumberFormatter` and space grouping (matches the input field). `Decimal.tenge` now delegates to it. Tests added. |
| ID‑8 | ✅ Fixed | `PlanAllocationRecord.sortOrder` added; `PlanRepository` assigns it on sync and sorts by it in `materialize`. New round‑trip + reorder test. |
| ID‑9 | ✅ Mitigated ⚠︎ | `TransactionsViewModel.load(minInterval:)` coalesces reloads; `ContentView` tab‑switch and scene‑activation triggers now pass `minInterval: 2` (pull‑to‑refresh and initial `.task` still force a load). Full "one refresh owner" redesign still recommended. |
| ID‑10 | ✅ Fixed | `PlanRepository`: `fetch(month:)` / `save` / all `synchronize*` / `materialize` now use `#Predicate` filters on `monthKey` / `planID` + `fetchLimit`, instead of fetching every row and filtering in memory. |
| ID‑12 | ✅ Partial | `TransactionsViewModel` now keeps a `[UUID: CategoryItem]` map; `category(for:)` and search are O(1) per lookup instead of a linear scan per transaction. Full memoization of the filtered array and the `CategoriesViewModel` equivalent still open. |
| ID‑16 | ✅ Fixed | `TransactionDateFilter`: `.last7Days` off‑by‑one fixed (7 inclusive days); `.lastMonth` → `.last30Days` ("Last 30 days"); added `.allTime`, now the default so history isn't hidden on first open. Tests updated. |
| ID‑17 | ✅ Fixed ⚠︎ | `MoneySummaryCard`: `.fixedSize()` → `.lineLimit(1).minimumScaleFactor(0.6)`. |
| ID‑21 | ↩︎ Kept | `moveGroups` hand math is actually correct and `Array.move(fromOffsets:toOffset:)` ships with SwiftUI (unavailable in this non‑UI type). Clarified with a comment; no behavior change. |
| ID‑22 | ✅ Fixed | `TransactionDraft.validate` now measures trimmed merchant/note length, matching what the store persists. |
| ID‑2, ID‑3, ID‑11 | ⏸ Deferred | Per owner's instruction, until the MVP is ready. |
| ID‑6 | ⏸ Deferred | Bounded/paged fetches need the view layer reworked and an Xcode build to verify; ID‑9 mitigation reduces the churn in the meantime. |
| ID‑13 | ⏸ Deferred | Deleting the `Features/Home` prototype is safe but touches `project.pbxproj` + `Package.swift`; do it in Xcode (select files → Delete) — 2 minutes, much safer there. |
| ID‑18, ID‑19, ID‑20, ID‑23 | ⏸ Open | SwiftUI/UIKit‑layer or config; unchanged this pass. |

**New/changed files this pass:** `Shared/Persistence/AppDatabase.swift`, `Shared/Money/MoneyFormatting.swift` (new), `Shared/Formatting/Decimal+Tenge.swift`, `Shared/Diagnostics/AppLog.swift` (new), `Shared/UI/MoneySummaryCard.swift`, `ContentView.swift`, `App/AppRootView.swift`, `Features/Transactions/Models/TransactionDateFilter.swift`, `Features/Transactions/Models/TransactionDraft.swift`, `Features/Transactions/ViewModels/TransactionsViewModel.swift`, `Features/Transactions/Persistence/TransactionRepository.swift`, `Features/Categories/ViewModels/CategoriesViewModel.swift`, `Features/Categories/Persistence/CategoryRepository.swift`, `Features/Plan/ViewModels/PlanViewModel.swift`, `Features/Plan/Persistence/PlanRepository.swift`, `Features/Plan/Persistence/PlanAllocationRecord.swift`, `Features/Plan/Views/PlanGroupsView.swift`, `Features/Plan/Views/PlannedIncomeSourcesView.swift`, plus tests (`PlanPersistenceTests`, `PlanPreviewTests`, `TransactionTests`, `MoneyFormattingTests` new).

> `Shared/Diagnostics/` and `Shared/Money/MoneyFormatting.swift` are picked up automatically by both the SPM target (directory‑based) and the Xcode app target (the project uses `PBXFileSystemSynchronizedRootGroup`), so no `project.pbxproj` edit was needed.

---

## 1. Executive Summary

QarjyFlow is a local‑only personal finance app (manual entry, no network, no accounts, no cloud sync). It has three tabs — **Home** (recorded monthly totals + recent transactions), **Activity** (transaction CRUD with search/filter), and **Plan** (a persisted monthly plan: expected income, customizable sections, fixed/percentage allocations). Categories are shared across features and live under Settings. Persistence is SwiftData behind a single serial `actor` (`LedgerDatabase`) with immutable `Sendable` value types crossing the boundary.

**Overall assessment: NOT production‑ready, but the foundation is above average for AI‑generated code.** The core architectural instincts are sound — feature‑oriented folders, MVVM for stateful screens, a real persistence boundary, exact integer money math, an actor‑isolated database, immutable DTOs, and unusually thorough test coverage of the non‑UI core. This is materially better than the typical "generated app."

However, the app is not shippable as‑is. The blocking gaps are **operational and safety‑net gaps**, not visible‑feature gaps:

1. **No SwiftData schema versioning / migration plan.** The first non‑additive model change after release is a data‑loss incident.
2. **No privacy manifest (`PrivacyInfo.xcprivacy`).** App Store submission will be rejected; required‑reason APIs (SwiftData/file‑timestamp) are undeclared.
3. **Strict concurrency checking is off.** The entire custom isolation design — which the README leans on heavily — is unverified by the compiler. The README itself admits this.
4. **Production code depends on preview/sample fixtures.** `PlanViewModel` imports `PlanPreviewData`; none of the `*PreviewData` / `Preview*Store` types are `#if DEBUG`. Fabricated financial numbers are one `nil` away from a user's screen, and `fatalError` paths compile into release.
5. **No logging or diagnostics.** Every `catch` discards the real error. Field failures (store open, save) are undiagnosable.

Secondary but important: unbounded full‑table fetches on every tab switch and every app foreground, a `NumberFormatter` allocated per amount render, non‑deterministic plan‑allocation ordering, and ~12 files of dead "Home prototype" code shipping alongside the real Home.

**Recommended gate decision:** block release. Green‑light a hardening milestone (roadmap in §16) covering migration, privacy manifest, strict concurrency, debug‑gating fixtures, logging, and bounded fetches before any TestFlight beyond internal.

---

## 2. Overall Architecture

### 2.1 What the architecture is

| Layer | Implementation | Assessment |
|---|---|---|
| Composition root | `QarjyFlowApp` → `AppRootView` → `AppStores.live()` | Good. Async DB open, explicit failure UI, no silent reset. |
| Concurrency boundary | `actor LedgerDatabase` wrapping 3 repositories; container opened on `Task.detached` | Good design intent; not compiler‑verified (§7). |
| Persistence | SwiftData `@Model` records; per‑operation non‑autosaving `ModelContext`; manual `save()`/`rollback()` | Defensible for the isolation goals; missing migration/relationships/bounded fetches (§10). |
| Store protocols | `CategoryStore` / `TransactionStore` / `PlanStore` (`Sendable`, `async`) | Good — clean seam for previews/tests. |
| DTOs | `CategoryItem`, `TransactionItem`, `MonthlyPlan`, `LedgerSnapshot` — immutable `Sendable` structs | Good. Records never escape the actor. |
| View models | `@MainActor @Observable` classes; `CategoriesViewModel`, `TransactionsViewModel`, `PlanViewModel` | Modern Observation usage; inconsistent error models; some scope creep (§3, §11). |
| Views | SwiftUI, feature folders, one primary type per file, `#Preview` per view | Good discipline; heavy `.tint(.green)` repetition; dead prototype layer. |
| Money | `Int64` minor units (tiyn) in storage; `Decimal` for arithmetic; custom exact string parser | Very good. No `Double` in the ledger path. |

### 2.2 Is it appropriate? Will it scale?

**For the current milestone: appropriate.** For "a real application," it will scale *architecturally* (the seams are in the right places) but not *operationally* without the changes below. The three things that will break first as real usage grows:

- **Data volume.** Every `load()` fetches the entire transaction table into memory and holds it for the app's lifetime in `TransactionsViewModel.transactions`. Home shows 5 rows; Activity defaults to a 7‑day window. Nothing bounds the fetch. At a few thousand transactions this is visible jank on every tab switch; at tens of thousands it is a memory and launch problem.
- **Reactivity plumbing.** There is no `@Query` and no store‑level change signal. Every mutation requires a manual `load()`, and there are already **four** reload triggers wired in `ContentView` alone (`.task`, `.onChange(selection)`, `.onChange(scenePhase)`, plus per‑screen `.refreshable` / `.onDisappear`). Each new feature adds more of this by hand.
- **Schema evolution.** No `VersionedSchema` / `SchemaMigrationPlan`. Lightweight automatic migration only covers additive changes.

### 2.3 Recommended architectural improvements (high level)

1. Add a **`VersionedSchema` + `SchemaMigrationPlan`** now, while there is exactly one schema version to name.
2. Introduce a **bounded read API** (`fetchTransactions(in dateRange:, limit:)`, `recentTransactions(limit:)`) and stop loading the whole table.
3. Give the persistence layer a **change notification** (an `AsyncStream` from the actor, or a monotonic revision token) so view models refresh without `ContentView` orchestrating reloads.
4. **Split `TransactionsViewModel`** into shared ledger data vs. per‑screen filter/search state.
5. **Gate every `*PreviewData` / `Preview*Store` type behind `#if DEBUG`** and remove `PlanPreviewData` from `PlanViewModel`.
6. **Delete or quarantine the `Features/Home` prototype** (§ID‑13).
7. Turn on `SWIFT_STRICT_CONCURRENCY = complete`, fix the fallout, then move to Swift 6 language mode.

---

## 3. Project Strengths

These are real and worth preserving through any refactor:

- **Money is handled correctly.** `Int64` tiyn in storage, `Decimal` arithmetic, a bespoke exact parser (`AmountInputParsing` / `AmountInputFormatting`) that never touches `Double` and never rounds user input. Percentage rounding uses `NSDecimalRound`. Monthly boundaries are exclusive and calendar/time‑zone aware. This is the hardest part of a finance app and it is done well, with tests.
- **Genuine persistence boundary.** SwiftData `@Model` objects never reach a view. Only immutable `Sendable` values cross `LedgerDatabase`. `LedgerSnapshot` reads categories + transactions with no suspension between them, so a concurrent delete cannot split the snapshot.
- **Application‑enforced referential integrity.** Categories referenced by a transaction or a plan allocation cannot be deleted or switched between income/expense. Archived‑category rules are thought through. Covered by concurrent‑race tests.
- **Modern SwiftUI/Observation.** `@Observable` + `@State`/`@Bindable`, no legacy `ObservableObject`/`@Published`, correct one‑way data flow (views render state, forward actions).
- **Failure handling in the data‑open path.** `AppRootView` never silently replaces a broken store with an empty one; it shows a non‑destructive retry screen. `HomeLedgerView` keeps the last good snapshot on a failed refresh.
- **Test coverage of the core.** CRUD, validation, stable identity, archived‑name reactivation, disk‑container reopen, rollback on rejected save, concurrent delete/create races, duplicate‑create races, stale‑refresh guard, month boundaries, migration from a category‑only schema, plan round‑trips, percentage rebasing. This is far more than generated code usually ships with.
- **Accessibility is not an afterthought.** 44‑pt targets, `accessibilityLabel`/`Identifier`, `accessibilityElement(children: .combine)`, Dynamic Type and dark‑mode previews, chart has a text alternative.
- **No networking, no third‑party SDKs, no secrets, `cloudKitDatabase: .none`.** The security surface is genuinely small and intentional.

---

## 4. Critical Issues

> Severity legend: **Critical** = blocks release / risks data loss or store rejection. **High** = must fix before public beta. **Medium** = fix before 1.0 / will hurt at scale. **Low** = cleanup / polish.

### ID‑1 — No SwiftData schema versioning or migration plan
- **File:** `QarjyFlow/Shared/Persistence/AppDatabase.swift`
- **Type:** `enum AppDatabase`
- **Severity:** Critical
- **Explanation:** The schema is a bare `Schema([...])` with `ModelContainer(for:configurations:)`. There is no `VersionedSchema`, no `SchemaMigrationPlan`, no migration stages. The only migration proven by tests (`testExistingCategoryOnlyDatabaseUpgradesAndTransactionsPersist`) is SwiftData's *lightweight automatic* migration, which only handles purely additive changes (new models, new optional properties).
- **Why it matters:** The first time anyone renames a property, changes a type, adds a `@Relationship`, changes a uniqueness constraint, or splits an entity after release, SwiftData will fail to open the store or silently drop data. For a finance app, that is a corruption/loss incident with no recovery path (there is no export yet).
- **Recommended fix:** Introduce `enum LedgerSchemaV1: VersionedSchema` now (models + `versionIdentifier`), a `LedgerMigrationPlan: SchemaMigrationPlan` with `[LedgerSchemaV1.self]`, and open the container with the plan. Establishes the pattern while there is only one version. Add a test that opens a V1 store with the migration plan. Ship an export/backup path (roadmap milestone) before the first schema change.

### ID‑2 — Missing privacy manifest and required‑reason API declarations
- **File:** project (no `PrivacyInfo.xcprivacy`), `QarjyFlow.xcodeproj/project.pbxproj`
- **Type:** app target resources / Info.plist generation
- **Severity:** Critical (App Store rejection)
- **Explanation:** There is no `PrivacyInfo.xcprivacy`. Apple requires one for App Store submission, including `NSPrivacyCollectedDataTypes` (here: none) and `NSPrivacyAccessedAPITypes` with reason codes for "required reason" APIs. SwiftData/CoreData and file‑timestamp APIs used transitively fall under this.
- **Why it matters:** Submission is blocked at upload/review. Also a good‑hygiene item: the app genuinely collects nothing off‑device and the manifest should say so explicitly.
- **Recommended fix:** Add `PrivacyInfo.xcprivacy` to the app target: `NSPrivacyTracking = false`, empty `NSPrivacyTrackingDomains`, empty `NSPrivacyCollectedDataTypes`, and `NSPrivacyAccessedAPITypes` entries for file timestamp (`C617.1` / `3B52.1` as applicable) and user‑defaults if introduced later. Verify with Xcode's "Generate Privacy Report" on the built archive.

### ID‑3 — Strict concurrency checking is disabled; the isolation design is unverified
- **File:** `QarjyFlow.xcodeproj/project.pbxproj` (`SWIFT_VERSION = 5.0`, no `SWIFT_STRICT_CONCURRENCY`), README "Editor interaction and concurrency"
- **Type:** build configuration (both Debug and Release)
- **Severity:** Critical (for a finance app relying on a custom concurrency model)
- **Explanation:** The project builds in Swift 5 language mode with `SWIFT_APPROACHABLE_CONCURRENCY = YES` but **without** `SWIFT_STRICT_CONCURRENCY = complete` and without Swift 6 mode. The README describes an elaborate actor/isolation contract ("only immutable Sendable values cross the boundary", "contexts never reach views", "repositories never shared across executors") and then concedes it is "not a claim of a warning‑free Swift 6 language‑mode build." So the contract is enforced by comments and discipline, not the compiler.
- **Why it matters:** `CategoryRepository` / `TransactionRepository` / `PlanRepository` are non‑`Sendable`, non‑isolated `final class`es holding `ModelContext`. Nothing stops a future change from returning a `CategoryRecord` or capturing a context in an escaping closure. In a money app, a data race in the save path is a corruption bug that ships silently.
- **Recommended fix:** Set `SWIFT_STRICT_CONCURRENCY = complete` for both configs. Fix the diagnostics (expect: repositories need explicit isolation or `Sendable` reasoning; the known SwiftData SDK key‑path `Sendable` warnings in predicates/sort can be isolated and tracked). Once clean, adopt `SWIFT_VERSION = 6.0`. Treat the SPM check target the same way.

### ID‑4 — Production code depends on preview/sample fixtures; fixtures are not `#if DEBUG`
- **File:** `QarjyFlow/Features/Plan/ViewModels/PlanViewModel.swift:20`; `QarjyFlow/Features/*/PreviewData/*` (all files); `QarjyFlow/Features/Home/PreviewData/*`
- **Type:** `PlanViewModel`, `PlanPreviewData`, `CategoryPreviewData`, `TransactionPreviewData`, `PreviewCategoryStore`, `PreviewTransactionStore`, `PreviewPlanStore`
- **Severity:** Critical
- **Explanation:** `PlanViewModel.init` contains `let initial = initialPlan ?? (store == nil ? PlanPreviewData.plan : nil)` — a *shipping* view model references fabricated data (`700 000` salary, fictional allocations). None of the `*PreviewData` enums or `Preview*Store` classes are wrapped in `#if DEBUG`, so they compile into the Release binary. `TransactionPreviewData` / `CategoryPreviewData` contain `fatalError(...)` paths. `#Preview` macro bodies are stripped in Release, but these standalone types are not.
- **Why it matters:** (a) A construction path with `store == nil` renders invented financial figures to a real user. (b) Release binary carries sample‑data code and reachable `fatalError`s. (c) It couples the domain layer to test scaffolding — a design inversion.
- **Recommended fix:** Wrap every `PreviewData` / `Preview*Store` file in `#if DEBUG … #endif`. Remove the `store == nil` / `PlanPreviewData.plan` fallback from `PlanViewModel`; require a store in production and inject a fixture only from previews/tests. Consider a separate `QarjyFlowPreviewSupport` module or a `Fixtures` group excluded from the Release build phase.

### ID‑5 — No logging or error diagnostics anywhere in the app
- **File:** `QarjyFlow/App/AppRootView.swift:39`; every view model `catch` block; `CategoryRepository.commit()`, `TransactionRepository.commit()`, `PlanRepository.save()`
- **Type:** cross‑cutting
- **Severity:** Critical (for production supportability)
- **Explanation:** There is no `os.Logger`, no signposts, no crash‑reporting hook. Every `catch` throws away the underlying `Error` and substitutes a hard‑coded user string (`"Could not load your categories. Please try again."`). `AppRootView.openDatabase()` does `catch { failedToOpen = true }` — the actual `ModelContainer` failure reason is lost.
- **Why it matters:** When a user reports "it won't open" or "my transaction didn't save," there is nothing to look at — no console breadcrumb, no way to tell a disk‑full error from a migration failure from a permissions error. You cannot operate a data‑bearing app this way.
- **Recommended fix:** Add a small `AppLogger` (`Logger(subsystem:category:)` per feature). Log the real error at `.error` in every `catch` before mapping to a user string, with a category and a stable message. Keep the user‑facing copy. Add `os_signpost`/`Logger` around DB open and save. Decide on a crash reporter (MetricKit at minimum — no SDK, first‑party) before public beta.

---

## 5. High Priority Issues

### ID‑6 — Unbounded full‑table fetches on every load; whole ledger held for app lifetime
- **File:** `QarjyFlow/Features/Transactions/Persistence/TransactionRepository.swift:12`; `QarjyFlow/Shared/Persistence/LedgerDatabase.swift:26`; `QarjyFlow/Features/Transactions/ViewModels/TransactionsViewModel.swift`
- **Type:** `TransactionRepository.fetchAll()`, `LedgerDatabase.fetchSnapshot()`, `TransactionsViewModel`
- **Severity:** High
- **Explanation:** `fetchAll()` issues `FetchDescriptor<TransactionRecord>(sortBy: [date desc])` with no `fetchLimit` and no predicate. `fetchSnapshot()` loads *all* categories + *all* transactions. `TransactionsViewModel.transactions` then holds the entire array for the lifetime of the app (the VM is created once in `ContentView.init`). Home needs 5 rows; Activity defaults to a 7‑day window.
- **Why it matters:** Memory and CPU grow linearly with history. Every tab switch / foreground / pull‑to‑refresh re‑serializes the whole table on the actor and re‑publishes a full array to Observation. At 2–5k transactions this is perceptible; at 10k+ it is a launch‑time and memory problem. This is the single biggest scalability defect.
- **Recommended fix:** Add bounded reads to the actor: `recentTransactions(limit:)` for Home, `transactions(in: DateInterval, categoryID:, kind:, limit:, cursor:)` for Activity driven by the active filter. Move filtering/search into the fetch predicate where possible. Keep the in‑memory array scoped to what a screen shows. For monthly totals, compute with an aggregate fetch (`fetchCount` + summed predicate windows) rather than materializing rows.

### ID‑7 — `NumberFormatter` allocated on every amount render
- **File:** `QarjyFlow/Shared/Formatting/Decimal+Tenge.swift`
- **Type:** `extension Decimal { var tenge: String }`
- **Severity:** High
- **Explanation:** `tenge` constructs a fresh `NumberFormatter` (a relatively expensive object) on every call. It is called from `TransactionRow`, `MoneySummaryCard`, `PlanAllocationRow`, `PlanGroupSection`, `PlanAllocationSummary`, `PlanIncomeCard`, `CategoryDetailView`, chart backgrounds — i.e. several times per row, re‑evaluated on every SwiftUI body pass and during scrolling.
- **Why it matters:** Formatter creation dominates row layout cost; visible scroll hitching on lists of any length. Pure waste — the formatter is configuration‑identical every time.
- **Recommended fix:** Use a cached `static let` formatter (or `Decimal.FormatStyle.Currency` / a single shared `NumberFormatter`) behind the extension. Also see ID‑15 (separator inconsistency) — fix both together by introducing one `MoneyFormatter` type with a cached formatter and a single grouping convention.

### ID‑8 — Plan allocations have no stable sort order; UI reorders after save/reload
- **File:** `QarjyFlow/Features/Plan/Persistence/PlanAllocationRecord.swift`; `QarjyFlow/Features/Plan/Persistence/PlanRepository.swift:120` (`materialize`)
- **Type:** `PlanAllocationRecord`, `PlanRepository.materialize`
- **Severity:** High (correctness/UX)
- **Explanation:** `PlanGroupRecord` has `sortOrder`; `PlannedIncomeRecord` is sorted by name in `materialize`. `PlanAllocationRecord` has **no** `sortOrder`, and `materialize` returns allocations in raw `context.fetch(...)` order (undefined). `PlanViewModel.allocations` and every `PlanGroupSection` `ForEach` therefore render in a non‑deterministic order that can change on each save/reload. `testMonthlyPlanRoundTripsThroughActorStore` only passes because its fixtures use 0–1 allocations; `PlanPreviewData` never round‑trips through SwiftData.
- **Why it matters:** Users see allocation rows jump around after editing anything. Equality‑based tests give false confidence.
- **Recommended fix:** Add `sortOrder: Int` to `PlanAllocationRecord`, assign it in `synchronizeAllocations` (preserve incoming order; append new at the end), and sort by it in `materialize`. Add a multi‑allocation round‑trip + ordering test that goes through `LedgerDatabase`.

### ID‑9 — Redundant and racy reload triggers in `ContentView`
- **File:** `QarjyFlow/ContentView.swift:40-42`
- **Type:** `ContentView`
- **Severity:** High
- **Explanation:** Three triggers all call `model.load()`: `.task { await model.load() }`, `.onChange(of: selection) { Task { await model.load() } }`, `.onChange(of: scenePhase) { if .active … Task { await model.load() } }`. On cold launch `.task` and the initial `.active` transition both fire, so ≥2 concurrent `load()`s race (the `revision` guard prevents corruption but not the duplicate work). Every tab tap triggers a full ledger reload (see ID‑6). `HomeLedgerView` and `ActivityView` additionally expose `.refreshable`.
- **Why it matters:** Wasted work scales with ID‑6's fetch size; visible fl\icker/`ProgressView` churn; unnecessary actor contention; hard to reason about "when does data refresh."
- **Recommended fix:** Pick one refresh owner. Load per‑screen `onAppear`/`.task(id:)` for the screen that needs data, not globally on the `TabView`. Debounce scene‑phase reloads (skip if a load ran in the last N seconds). Better: a store change signal (§2.3) so screens observe rather than poll.

### ID‑10 — Plan persistence uses manual foreign keys with no cascade, no predicate, no index
- **File:** `QarjyFlow/Features/Plan/Persistence/PlanRepository.swift` (`fetch`, `save`, `synchronizeIncome/Groups/Allocations`, `materialize`); `MonthlyPlanRecord`, `PlanGroupRecord`, `PlanAllocationRecord`, `PlannedIncomeRecord`
- **Type:** `PlanRepository` + all four plan `@Model` records
- **Severity:** High
- **Explanation:** Child records reference the parent by `planID: UUID` (a plain, unindexed attribute) instead of a SwiftData `@Relationship`. Every `synchronize*` and `materialize` does `context.fetch(FetchDescriptor<XRecord>()).filter { $0.planID == plan.id }` — it fetches **every** record of that type across **all** months and filters in memory. `fetch(month:)` and `save` likewise fetch all `MonthlyPlanRecord`s and `.first(where:)`. There is no cascade: a future "delete plan" or "copy month" feature will orphan groups/allocations/income.
- **Why it matters:** With 12–24 persisted months this is O(all‑allocations) work on every plan edit. Orphan risk is latent now and becomes a real bug the moment month management (roadmap milestone 3) lands.
- **Recommended fix:** Model `MonthlyPlanRecord` with `@Relationship(deleteRule: .cascade)` to its income/groups/allocations, or keep the FK style but (a) add `#Predicate` filters on `planID` to every fetch, (b) add an explicit cleanup step on plan deletion, (c) add `@Attribute(.index)` where SwiftData supports it. Also switch `fetch(month:)`/`save` to a `#Predicate { $0.monthKey == key }`.

### ID‑11 — Repositories are neither `Sendable` nor isolated; safety is convention‑only
- **File:** `QarjyFlow/Features/Categories/Persistence/CategoryRepository.swift`; `.../Transactions/Persistence/TransactionRepository.swift`; `.../Plan/Persistence/PlanRepository.swift`
- **Type:** `CategoryRepository`, `TransactionRepository`, `PlanRepository`
- **Severity:** High (given ID‑3)
- **Explanation:** Each is a `final class` holding a `ModelContainer` and (`CategoryRepository`) a mutable `var context`. They are created on `Task.detached` inside `LedgerDatabase.init` and stored as `let` actor properties. Nothing in the type system prevents a method from returning an internal `@Model` object or capturing `context` in an escaping closure. In previews the same `CategoryRepository` type runs on `@MainActor` (`PreviewCategoryStore`) — a *different* executor than production.
- **Why it matters:** The concurrency correctness the README advertises rests entirely on reviewers noticing. With strict concurrency off (ID‑3), the compiler will not catch a regression.
- **Recommended fix:** After enabling strict concurrency, make the isolation explicit: nest the repositories as private types inside `LedgerDatabase` (so they inherit actor isolation), or annotate them and audit every method signature to prove only `Sendable` values escape. Give preview stores their own lightweight in‑memory repository rather than reusing the production class on the main actor.

---

## 6. Medium Priority Issues

### ID‑12 — `visibleTransactions` / `visibleCategories` recompute O(n·m) per access, multiple times per render
- **File:** `TransactionsViewModel.swift:32`; `CategoriesViewModel.swift:18`
- **Type:** `TransactionsViewModel`, `CategoriesViewModel`
- **Severity:** Medium
- **Explanation:** Both are `var` computed properties that filter + sort the full collection on every read; `visibleTransactions` also calls `category(for:)` (linear scan of categories) per transaction, and `dateFilter.includes` builds `Calendar` math per element. Views read them several times per `body` (empty check, `ForEach`, count).
- **Why it matters:** Combines with ID‑6/ID‑9 into scroll and tab‑switch jank as data grows.
- **Recommended fix:** Memoize: recompute the derived list only when inputs (`transactions`, `filter`, `categoryFilterID`, `dateFilter`, dates, `searchText`) change; cache a `[UUID: CategoryItem]` lookup instead of `first(where:)`.

### ID‑13 — Large dead‑code island: the entire `Features/Home` prototype
- **File:** `QarjyFlow/Features/Home/Views/HomeView.swift`, `HomeEmptyView.swift`, `CategoryDetailView.swift`, `Views/Components/*` (`BudgetAlertsSection`, `CategorySpendingRow`, `HomeSummarySection`, `MonthProgressSection`, `SpendingCategorySection`, `SpendingDonutChart`), `Models/HomeSnapshot.swift`, `Models/CategorySnapshot.swift`, `PreviewData/HomeSnapshot+Demo.swift`, `PreviewData/CategorySnapshot+Demo.swift`
- **Type:** ~12 files
- **Severity:** Medium
- **Explanation:** The shipping app (`ContentView`) uses only `HomeLedgerView`. Every other type under `Features/Home` is referenced exclusively from within `Features/Home` and its own `#Preview` blocks — a self‑contained island reachable only from previews. There are effectively two parallel "Home" implementations.
- **Why it matters:** A new engineer opening `Features/Home` cannot tell which Home is real. Maintenance and compile cost for code that never runs. `Charts` is linked only for the dead donut chart.
- **Recommended fix:** Decide: either promote pieces you intend to use (donut chart, month‑progress) into the real `HomeLedgerView` path, or delete the prototype. If it must stay as a design reference, move it to a `#if DEBUG` sample gallery or a separate non‑shipping target, and say so in the README.

### ID‑14 — Two different error‑propagation styles in `PlanViewModel`
- **File:** `QarjyFlow/Features/Plan/ViewModels/PlanViewModel.swift`
- **Type:** `PlanViewModel`
- **Severity:** Medium
- **Explanation:** `saveIncome` / `addAllocation` / `saveGroup` **return `String?`** (a user message). `deleteIncome` / `updateAllocation` / `moveGroups` / `deleteGroups` / `deleteAllocation` **set `self.errorMessage`**. The private `persist(fallback:)` returns `Error?` (non‑throwing) and swallows typed errors; `guard !isSaving else { fallback(); return CancellationError() }` silently reverts a user's edit when a save is mid‑flight. User‑facing English strings are hard‑coded in the view model.
- **Why it matters:** Inconsistent contract for callers; rapid edits are silently dropped; strings in the VM block localization and are awkward to test. Contrast with `CategoriesViewModel` / `TransactionsViewModel`, which `throw`.
- **Recommended fix:** One mechanism. Prefer `throws` with a typed `PlanError`‑style enum; map to localized copy in the view. Replace the ad‑hoc `isSaving` bail‑out with a serialized mutation queue (an `actor`‑backed task or `AsyncChannel`) so edits are applied in order, not discarded.

### ID‑15 — Money formatting is inconsistent and locale‑hostile
- **File:** `QarjyFlow/Shared/Formatting/Decimal+Tenge.swift` vs. `QarjyFlow/Shared/Money/AmountInputFormatting.swift`
- **Type:** `Decimal.tenge` vs. `AmountInputFormatting.display`
- **Severity:** Medium
- **Explanation:** `tenge` hard‑codes `Locale(identifier: "en_US")` with `numberStyle = .decimal`, so it renders `1,875,000 ₸` (comma grouping) and manually appends the symbol. The input field (`AmountInputFormatting.display`) uses **space** grouping (`1 875 000`). The app shows amounts two different ways. `tenge` also returns `"—"` on formatter failure and ignores the device locale entirely.
- **Why it matters:** Visibly inconsistent number presentation; not localizable; "—" can leak into UI for edge values.
- **Recommended fix:** Single `MoneyFormatter` with a cached formatter, space grouping to match input (or pick one convention app‑wide), `Decimal.FormatStyle.Currency(code: "KZT")` where suitable, and a defined fallback. Route both display paths through it.

### ID‑16 — `TransactionDateFilter` labels don't match their semantics; default hides history
- **File:** `QarjyFlow/Features/Transactions/Models/TransactionDateFilter.swift`; `TransactionsViewModel.swift:15`
- **Type:** `TransactionDateFilter`, `TransactionsViewModel`
- **Severity:** Medium
- **Explanation:** `.last7Days` computes `startOfDay(now) - 7 days … now` = 8 inclusive calendar days. `.lastMonth` computes `startOfDay(now) - 1 month … now` — a rolling ~30 days, **not** the previous calendar month, though the label reads "Last month." `TransactionsViewModel.dateFilter` defaults to `.last7Days`, so first entry into Activity shows only the last week and the empty state says "adjust your filters."
- **Why it matters:** Users read "Last month" as September vs. August. New users with older data think Activity is empty/broken.
- **Recommended fix:** Rename to match behavior (`.last7Days` → "Last 7 days" is fine if it's truly 7; fix the off‑by‑one), add a true `.thisMonth` / `.previousCalendarMonth` if that's intended, and default to a wider window (or "All") until the user narrows it.

### ID‑17 — `MoneySummaryCard` uses `.fixedSize()` on the amount
- **File:** `QarjyFlow/Shared/UI/MoneySummaryCard.swift:11`
- **Type:** `MoneySummaryCard`
- **Severity:** Medium
- **Explanation:** `Text(amount.tenge).font(.subheadline.bold()).fixedSize()` forces the amount to its ideal width with no wrap/truncation. With large Dynamic Type and/or maximum amounts (`999,999,999,999.99 ₸`) the text overflows its rounded background and can clip or push the card past the screen edge.
- **Why it matters:** Layout breakage at accessibility text sizes and large balances — exactly the cases QA under‑tests.
- **Recommended fix:** Drop `.fixedSize()` or constrain to horizontal only with `minimumScaleFactor` and `lineLimit(1)`; verify at `.accessibility5` with a 15‑digit amount.

### ID‑18 — Category refresh via `.onDisappear` of a nested `CategoriesView`
- **File:** `QarjyFlow/Features/Transactions/Views/TransactionEditorView.swift:71-74`
- **Type:** `TransactionEditorView`
- **Severity:** Medium
- **Explanation:** `NavigationLink { CategoriesView(store: categoryStore).onDisappear(perform: onCategoriesChanged) }`. `onDisappear` fires on any disappearance (pushing a further view, tab switch, sheet dismissal timing), not reliably "user finished editing categories." `onCategoriesChanged` → `Task { await model.load() }` (a full ledger reload).
- **Why it matters:** Spurious full reloads, or a missed refresh if `onDisappear` doesn't fire as expected; the new category may not appear in the picker.
- **Recommended fix:** Have `CategoriesViewModel` mutations publish through the shared store/signal so the editor's category list updates without an explicit callback; or pass an explicit "done" completion from `CategoriesView`. At minimum, reload only categories, not the whole snapshot.

### ID‑19 — `CategoriesViewModel` instantiated per view; divergent lists over one store
- **File:** `QarjyFlow/Features/Categories/Views/CategoriesView.swift:14`; used from `SettingsView.swift` and `TransactionEditorView.swift`
- **Type:** `CategoriesView` / `CategoriesViewModel`
- **Severity:** Medium
- **Explanation:** `CategoriesView.init` builds a fresh `CategoriesViewModel(store:)`. Opened from Settings and (separately) from the transaction editor, two instances hold independent `categories` arrays backed by the same store. `save()` patches one item in memory (`replace(saved)`) rather than reloading, so the two lists can diverge until each reloads.
- **Why it matters:** Stale category names/colors across screens; the editor and Settings can show different truth simultaneously.
- **Recommended fix:** Single source of truth for categories (the shared `TransactionsViewModel.categories`, or a dedicated `CategoryStoreObservable`), with `CategoriesView` as a pure editor over it. Reload after mutation instead of local patching, or drive both from a store change signal.

### ID‑20 — `AmountTextField` focus handling
- **File:** `QarjyFlow/Shared/UI/AmountTextField.swift`
- **Type:** `AmountTextField: UIViewRepresentable`, `Coordinator`
- **Severity:** Medium
- **Explanation:** Focus is driven by a `Binding<Bool>?` toggled from `.onTapGesture` on a `LabeledContent` wrapper, and `updateUIView` calls `becomeFirstResponder()` / `resignFirstResponder()` during the SwiftUI update pass. Caret mapping counts UTF‑16 units (fine for digits, but the algorithm in `AmountInputFormatting.edit` is intricate and only partially tested — e.g. no test for pasting text containing a currency symbol mid‑string, or an emoji).
- **Why it matters:** Calling responder changes during `updateUIView` risks "modifying state during view update" warnings and focus fights with the keyboard toolbar's Done button. The tap‑to‑focus proxy is fragile across layout changes.
- **Recommended fix:** Use `@FocusState` (iOS 15+) bound through the representable via `focused`/`FocusState.Binding`, or move responder changes to `DispatchQueue.main.async` / a coordinator callback outside the update pass. Add tests for paste with non‑numeric characters and for locale decimal separators.

### ID‑21 — Manual list‑move math in `PlanViewModel.moveGroups`
- **File:** `QarjyFlow/Features/Plan/ViewModels/PlanViewModel.swift:120`
- **Type:** `PlanViewModel.moveGroups`
- **Severity:** Medium
- **Explanation:** Reimplements `move(fromOffsets:toOffset:)` with `adjusted = destination - source.filter { $0 < destination }.count` and manual clamping. Correct for single‑item moves; error‑prone for multi‑index `IndexSet`.
- **Recommended fix:** `var reordered = groups; reordered.move(fromOffsets: source, toOffset: destination)` then persist. Delete the hand math.

### ID‑22 — Validation length checks use untrimmed strings
- **File:** `QarjyFlow/Features/Transactions/Models/TransactionDraft.swift:37`
- **Type:** `TransactionDraft.validate`
- **Severity:** Medium (low impact, easy)
- **Explanation:** `guard merchant.count <= 100, note.count <= 500` runs on the raw draft strings, but `TransactionRepository.save` stores the **trimmed** values. A 103‑char merchant that is 100 after trimming trailing spaces is rejected.
- **Recommended fix:** Validate `merchant.trimmingCharacters(in: .whitespacesAndNewlines).count`. Same review for `CategoryDraft`.

### ID‑23 — SwiftData store has no elevated file protection
- **File:** `QarjyFlow/Shared/Persistence/AppDatabase.swift`
- **Type:** `AppDatabase.makeContainer`
- **Severity:** Medium
- **Explanation:** The store inherits the default `NSFileProtectionCompleteUntilFirstUserAuthentication`. It holds amounts, merchant names, and free‑text notes. There is no app‑level lock (biometric/passcode gate).
- **Why it matters:** On a lost/stolen unlocked‑once device, the ledger file is readable. For a finance app, users expect at‑rest protection.
- **Recommended fix:** Evaluate `.complete` file protection for the store URL (understand the "unavailable while locked" trade‑off for any future background work), and add an optional Face ID / passcode gate on launch (roadmap: Release preparation).

---

## 7. Concurrency Review

**Verdict: the design is thoughtfully structured but not compiler‑verified, and it is over‑exercised by the UI layer.**

### Strengths
- Single serial `actor LedgerDatabase` owning all three repositories — cross‑entity invariants (category ↔ transaction ↔ plan) are protected together.
- `fetchSnapshot()` reads categories then transactions with **no `await` between them**, so a concurrent mutation cannot tear the snapshot. This is the right instinct and is tested (`testConcurrentDeleteAndTransactionSaveCannotCreateOrphan`).
- Only immutable `Sendable` value types cross the actor boundary; `@Model` objects and `ModelContext` never reach a view.
- `ModelContainer` creation runs on `Task.detached` so disk open / migration does not block the main actor.
- View models are `@MainActor @Observable`; `revision` tokens guard against a late fetch overwriting a newer mutation (`CategoriesViewModel.load`, `TransactionsViewModel.load`), and this is tested (`testLateRefreshCannotOverwriteCompletedSave`).
- No `@unchecked Sendable`, no `DispatchQueue`, no `Thread.sleep`, no `.sync`, no `try!`/`as!` in app code. Clean.

### Weaknesses / risks
- **ID‑3:** strict concurrency off → none of the above is enforced. This is the headline concurrency finding.
- **ID‑11:** repositories are non‑`Sendable`, non‑isolated classes; preview path runs the same class on `@MainActor`.
- **ID‑9:** duplicate concurrent `load()` on cold launch and on every tab switch. The `revision` guard makes it *safe*, not *efficient*.
- **Fire‑and‑forget `Task {}` in views** with no handle/cancellation: `ContentView` `.onChange` blocks, `CategoriesView` / `ActivityView` / `PlanView` confirmation‑dialog buttons (`Task { await model.delete(...) }`), `ActivityView.reloadCategories`. If a view disappears mid‑task the work still completes and mutates an `@Observable` that may no longer be presented. Mostly benign here (value‑type views, MainActor hops) but it is unstructured.
- **Ad‑hoc mutual exclusion via `Bool`s** (`isMutating`, `isSaving`, `isLoading`, `preparingToAdd`) instead of a structured serialized queue. `PlanViewModel.persist` *reverts and drops* an edit if `isSaving` is true (ID‑14). `CategoriesViewModel.load` silently no‑ops while `isMutating` (a `.refreshable` pull then does nothing and the user thinks it refreshed).
- **`load()` is not cancellable** in a useful way — it checks `Task.isCancelled` after the `await`, but the callers create detached `Task {}`s that are never cancelled on view disappear, and `.task` cancellation only covers the `.task` one.

### UI‑thread safety
No evidence of UI updates off the main actor. View models are `@MainActor`; results are published after resuming on the main actor. `AmountTextField.Coordinator` is `@MainActor`. This part is correct.

### Recommendations
1. `SWIFT_STRICT_CONCURRENCY = complete`, fix fallout, then Swift 6 mode.
2. Replace the `Bool` guards with a real serialized mutation path per view model (an internal `actor` or an `AsyncStream` of commands) so operations queue instead of being dropped or ignored.
3. Own the reload story (§2.3) so `ContentView` isn't firing three overlapping loads.
4. Give `load()`/mutation `Task`s stored handles and cancel on disappear where it matters.

---

## 8. SwiftUI Review

**Verdict: modern and mostly idiomatic; the problems are state‑placement and derived‑work‑in‑`body`, not misuse of the property wrappers.**

### Done well
- `@Observable` + `@State private var model` created once in `init` via `State(initialValue:)`; `@Bindable var model` where two‑way binding to VM fields is needed (`ActivityView`, `PlanGroupsView`, `PlannedIncomeSourcesView`). Correct.
- No `@StateObject`/`@ObservedObject`/`ObservableObject` legacy. No `@EnvironmentObject` (dependencies are passed explicitly — arguably verbose, but honest).
- `@Binding` used correctly in leaf components (`AmountTextField`, `CategoryIconPicker`, `ThemeColorPicker`).
- View composition is good: screens compose sections; sections own layout; reusable rows/cards take explicit value inputs and hold no navigation.
- `#Preview` for every view, with empty / populated / dark / accessibility variants. `ViewThatFits` for summary cards. `ContentUnavailableView` for empty/error states.
- `.interactiveDismissDisabled(isSaving)` and disabled Save while saving — good sheet hygiene.

### Anti‑patterns / issues
- **Derived work inside `body`:** `HomeLedgerView.body` builds `TransactionSummary(transactions: model.transactions, month: Date())` every render (ID‑12 sibling); `let month = Date()` in `body` is a new value each pass. Move to the VM as a memoized property keyed on `transactions`.
- **Non‑memoized computed collections** read multiple times per `body` (`visibleTransactions`, `visibleCategories`, `filterCategories`, `availableCategories`, `expenseCategories`) — ID‑12.
- **State owned too high / conflated:** `TransactionsViewModel` holds Home's data, Activity's data, Activity's filter + search + custom date range, *and* feeds Plan's category list. Home re‑renders are coupled to Activity's `searchText` changing (Observation is property‑granular so the actual damage is limited, but the design mixes three screens' concerns in one object).
- **State owned too low / duplicated:** categories (ID‑19) — two `CategoriesViewModel`s over one store.
- **`.onDisappear` as a lifecycle signal** (ID‑18) — unreliable.
- **`@MainActor` on `View` structs** (`CategoryEditorView`, `TransactionEditorView`) is redundant (SwiftUI views are already main‑actor isolated under approachable/Swift 6 concurrency).
- **`.tint(.green)` repeated** on ~25 views and nearly every sheet; there is an `AccentColor` asset that this overrides inconsistently. Centralize (set once at the `WindowGroup`/root, delete the rest).
- **`AmountTextField` responder churn in `updateUIView`** (ID‑20).
- **Layout fragility:** `.fixedSize()` on money text (ID‑17); `MonthProgressSection` etc. only in the dead prototype.
- **`ForEach(Array(recent.enumerated()), id: \.element.id)`** with manual `Divider()` in `HomeLedgerView` — works, but a plain `ForEach(recent)` inside a styled container reads better.

### Is state owned in the right place?
Mostly. Two concrete fixes: (1) split `TransactionsViewModel` (ledger data vs. per‑screen filter state); (2) make categories a single shared observable instead of per‑view VMs.

### Performance
Covered in §11. Nothing here is fatal at demo scale; `body`‑time computation + unbounded data (ID‑6) + per‑render `NumberFormatter` (ID‑7) compound into list/scroll jank at real data sizes.

---

## 9. Database & Persistence Review

**Technology:** SwiftData, one `ModelContainer`, `cloudKitDatabase: .none`, per‑operation non‑autosaving `ModelContext`, manual `save()` / `rollback()`.

### Reasonable choices
- Opting out of the SwiftUI `.modelContainer`/`@Query` path and using manual contexts is a **defensible** decision here: it keeps all SwiftData work on the actor and off the main‑thread autosave context, which is what enables the concurrency model.
- Fresh context per transaction/plan operation; `Categoryrepository` rebuilds its context after a failed save (documented reason: a failed SwiftData save can leave registered objects reflecting rolled‑back edits). This is a real SwiftData gotcha and the handling is correct.
- `@Attribute(.unique)` on `CategoryRecord.id`, `MonthlyPlanRecord.id` / `monthKey`, etc.
- Stable `UUID` identity; display name is never an identifier; normalized‑name dedupe ignoring case/accents/whitespace.
- Disk‑reopen and rollback‑on‑readonly tests exist and pass.

### Problems
| ID | Issue | Severity |
|---|---|---|
| ID‑1 | No `VersionedSchema` / `SchemaMigrationPlan` — only additive auto‑migration works | Critical |
| ID‑10 | Plan children use unindexed `planID: UUID`, no `@Relationship`, no cascade; every sync/materialize fetches all rows and filters in memory | High |
| ID‑6 | `fetchAll()` / `fetchSnapshot()` unbounded, no `fetchLimit`, no predicate windowing | High |
| ID‑8 | `PlanAllocationRecord` has no `sortOrder` → non‑deterministic materialize order | High |
| ID‑23 | Default file protection only | Medium |
| — | `TransactionRepository.save` fetches **all** `CategoryRecord`s to resolve one `categoryID` (`.first(where:)`) instead of a `#Predicate` | Low‑Med |
| — | `CategoryRepository.isUsed` fetches all `PlanAllocationRecord`s and scans in memory for `categoryID` (a `#Predicate` on the optional `UUID?` is trickier but doable) | Low‑Med |
| — | No composite/secondary indexes anywhere (`TransactionRecord.date`, `.categoryID`, `PlanAllocationRecord.planID`) | Low‑Med (matters with ID‑6 fixed) |

### Transactions (DB sense)
Each operation is atomic via a single `context.save()` with `rollback()` on failure. `PlanRepository.save` does income + groups + allocations as one `save()` — good, it's all‑or‑nothing. No partial‑write path observed.

### Consistency
Referential integrity is application‑enforced (not DB‑level relationships) and is covered by concurrent‑race tests. The gap is **ordering** (ID‑8) and **future cascade** (ID‑10).

### Recommendations
Add the versioned schema now; add `sortOrder` to allocations; convert plan children to cascading relationships (or fully predicate + explicit cleanup); add bounded/predicate fetches; add indexes; raise file protection.

---

## 10. Networking Review

**There is no networking.** No `URLSession`, `URLRequest`, `URLComponents`, no `Combine` network pipeline, no reachability, no background tasks. This is correct and intentional for the product ("manual entry and on‑device storage, without bank integrations, login, or app cloud sync").

Nothing to fix today. Forward‑looking notes for when milestone 5+ (accounts, bank sync, export upload, or CloudKit) lands:

- There is **no API layer, no DTO/`Codable` decoding layer, no error taxonomy for I/O, no retry/backoff/timeout policy, no auth/token storage**. All of that is greenfield.
- Token/secret storage would need Keychain (none today — which is fine, there are no secrets).
- The concurrency model (`LedgerDatabase` actor) would need to absorb remote writes without blocking; the current "reload everything" UI refresh strategy (ID‑9) would not survive a sync engine.
- Export/backup (roadmap) that writes a file and hands it to a share sheet is the first "outbound data" feature and needs a privacy/consent decision.

---

## 11. Performance Review

Ranked by expected real‑world impact.

| ID | Cost | Trigger | Severity |
|---|---|---|---|
| ID‑6 | Full transaction table fetched + held in memory; O(n) serialize/publish | every `load()`: cold launch, each tab switch, each foreground, each pull‑to‑refresh | High |
| ID‑7 | `NumberFormatter` allocated per amount string | every row/card render, every scroll frame | High |
| ID‑9 | Duplicate + whole‑ledger reloads | launch (×2), every tab tap, every foreground | High (compounds ID‑6) |
| ID‑12 | `visible*` filter+sort+`first(where:)` O(n·m), multiple times per `body` | every render of Categories / Activity | Medium |
| ID‑13 sibling | `TransactionSummary` recomputed from all rows in `body` | every `HomeLedgerView` render | Medium |
| — | `PlanRepository` fetches all plan child rows across all months per edit | every plan mutation | Medium (grows with months) |
| — | `Decimal.tenge` also does string concatenation + `NSDecimalNumber` bridging per call | with ID‑7 | Low |
| — | `Charts` linked only for dead code (ID‑13) | binary size / launch | Low |

**No image loading, no remote assets, no caching layer needed** (SF Symbols only). `LazyVGrid` used for icon/color pickers — good. `List` used for the big collections — good (row recycling), but the per‑row cost (ID‑7, ID‑12) is what bites.

**Fixes:** bounded fetches (ID‑6), cached formatter (ID‑7), one reload owner + debounce (ID‑9), memoized derived collections + `[UUID: CategoryItem]` map (ID‑12), summary in the VM not `body`.

---

## 12. Memory Management Review

**No retain cycles or leaks identified.**

- View models are `@Observable` classes captured by SwiftUI value‑type views and by `Task {}` closures. Views are structs; there is no `self` reference cycle. `Task { await model.foo() }` captures the class `model` strongly for the task's duration only — acceptable, though see the "fire‑and‑forget" note in §7 (tasks outlive view presentation).
- `AmountTextField.Coordinator` holds `var parent: AmountTextField` (a struct) and is owned by the representable's context — no cycle. `parent` is refreshed each `updateUIView`.
- No `[weak self]` / `unowned` anywhere — and none is needed, because there are no escaping closures stored on long‑lived reference types.
- No large object graphs retained *except* the deliberate one: **`TransactionsViewModel` lives for the whole app session and holds the entire transaction array** (ID‑6). That is the only unbounded retention, and it's a consequence of the fetch strategy, not a closure bug.
- Preview `fatalError` closures don't retain anything problematic (preview‑only).

**Recommendation:** fixing ID‑6 also fixes the only real "large object retention" concern. Otherwise nothing to do.

---

## 13. Security Review

**Baseline is strong for a v1 local finance app.**

| Area | Status | Note |
|---|---|---|
| Network exposure | None | No `URLSession`, no analytics/ads/crash SDKs |
| API keys / secrets | None present | Nothing to leak; no `.env`, no hard‑coded tokens (`.gitignore` covers `*.p12`, `*.mobileprovision`, `.env*`) |
| Token storage | N/A | No auth |
| `UserDefaults` | Not used | No `@AppStorage`; nothing sensitive in defaults |
| Keychain | Not used | Nothing requires it yet |
| Cloud sync | Explicitly `cloudKitDatabase: .none` | Intentional, documented |
| Data at rest | **Weak** | SwiftData store at default file protection only — ID‑23 |
| App lock | None | No biometric/passcode gate on the ledger |
| Privacy manifest | **Missing** | ID‑2 — also a compliance/submission blocker |
| Logging of sensitive data | N/A now | When logging is added (ID‑5), do **not** log amounts/merchant/notes at `.info`; use `.debug` + `privacy: .private` |
| Pasteboard | `AmountInputFormatting` accepts pasted amounts | Parsed/validated, not executed — fine |
| Backups | Device backup includes the store | Documented in README; acceptable, but note it in a privacy screen |

**Recommendations:** add the privacy manifest (ID‑2); raise file protection and consider an optional app lock (ID‑23); when logging lands, mark financial fields `.private`; keep the "no SDKs" policy explicit in CONTRIBUTING so it isn't eroded.

---

## 14. Production Readiness Review

| Concern | State | Gap |
|---|---|---|
| **Logging** | None | ID‑5 — no `Logger`, no signposts |
| **Crash reporting** | None | No MetricKit/`MXCrashDiagnostic` subscriber; decide before public beta |
| **Error handling** | Present but lossy | Every `catch` discards the real error; two styles in `PlanViewModel` (ID‑14); generic user copy only |
| **Offline behavior** | N/A (fully offline) | Correct by design |
| **Data‑open failure** | Handled well | `AppRootView` non‑destructive retry screen — good |
| **Refresh‑failure** | Handled | `HomeLedgerView` keeps last good snapshot + warning — good |
| **Migrations** | **Not handled** | ID‑1 |
| **Crash risk** | Low in app code | `fatalError` only in preview fixtures (but shipped — ID‑4); `PlanMonth.init(year:month:)` has a `precondition((1...12).contains(month))` — currently only called with `Calendar` components (safe), but it's a latent trap if ever called with user input |
| **Defensive programming** | Good in the money/validation layer | `AmountInputParsing`, `TransactionDraft.validate`, category guards are thorough |
| **Privacy manifest** | Missing | ID‑2 |
| **App icon** | Placeholder only | `AppIcon.appiconset/Contents.json` has no image files; also carries `mac` idiom slots for an iOS‑only target |
| **Localization** | English only, strings inline | Acceptable for v1 (documented), but user strings are scattered in view models and `LocalizedError` cases; `CategoryKind.title` / `ThemeColor.title` are `rawValue.capitalized` |
| **State restoration / deep links** | None | `TabView` selection is a bare `Int`; acceptable for v1 |
| **iPad** | `TARGETED_DEVICE_FAMILY = 1,2` | Layouts are list/scroll‑based and use `ViewThatFits`; no iPad‑specific QA evident — needs a pass |
| **Tests** | Strong core unit coverage; **zero UI tests** | Accessibility identifiers exist (`categories.add`, `category.save`, `transaction.amount`, …) implying UI tests were planned but not written |
| **CI** | Not present in repo | `Package.swift` "check harness" is a manual `swift test`; no `.github/workflows`, no `xcodebuild` CI |
| **README/doc drift** | Minor | Claims "32 tests" (actual ≈ 38); Xcode/runtime‑mismatch section; roadmap wording |

**Blocking for release:** ID‑1, ID‑2, ID‑3, ID‑4, ID‑5. **Blocking for public beta:** ID‑6, ID‑9, plus a crash‑reporting decision and at least a smoke‑level UI test suite.

---

## 15. Technical Debt

### AI‑generated shortcuts / smells
- **Two parallel Home implementations** left side by side (`HomeView` prototype vs. `HomeLedgerView`) — ID‑13. Classic "generated the mockup, then generated the real thing, kept both."
- **Preview scaffolding not `#if DEBUG`**, and a domain type (`PlanViewModel`) importing `PlanPreviewData` — ID‑4. Test doubles leaked into production.
- **Hyper‑compact one‑liners** in the Plan layer (`record.name = x; record.normalizedName = y; record.symbol = z` many per line; `if … { } else { }` collapsed). Optimized to *look* small; hurts readability, blame, and diffs. Contrast with the Categories/Transactions layer, which is formatted normally.
- **Very long doc‑comments and a 200‑line README making concurrency‑correctness claims** the build settings don't enforce (ID‑3). The prose is ahead of the guarantees.
- **`Package.swift` shadow target** compiling a hand‑maintained subset of the app sources via `exclude:` — clever for running core tests without a simulator, but every new `Views/` folder must be manually excluded or the macOS build breaks. Brittle; a maintenance trap.
- **Hand‑rolled where a standard API exists:** list move math (ID‑21), money formatting (ID‑15), plan FK synchronization (ID‑10), duplicate‑prevention via full fetch + in‑memory scan.
- **Ad‑hoc `Bool` state machines** (`isMutating` / `isSaving` / `isLoading` / `preparingToAdd` / `hasLoaded` / `loadFailed`) scattered across each VM instead of one modeled state enum; `PlanViewModel` even drops user edits when two collide (ID‑14).
- **Inconsistent error contracts** between VMs (throwing vs. `String?` return vs. `errorMessage` property).

### Under‑engineering
- No schema migration plan (ID‑1). No logging (ID‑5). No bounded fetches (ID‑6). No store change notification — reactivity is manual `load()` calls wired in four places (ID‑9). No UI tests / CI.

### Over‑engineering
- Mild. The `Preview*Store` + isolated in‑memory repository setup is more machinery than the previews strictly need. Per‑operation context recreation in `TransactionRepository`/`PlanRepository` is arguably heavier than necessary now, though it's a deliberate isolation choice. The README's Java‑analogy table is documentation weight, not code weight.
- The abstraction count is otherwise *appropriate* — the store protocols and DTOs earn their place.

### Places that should be rewritten
1. `Decimal+Tenge.tenge` → a cached, locale‑aware `MoneyFormatter` (ID‑7, ID‑15).
2. `PlanRepository` synchronization → relationships + predicates, or predicate‑filtered FK sync with explicit cleanup (ID‑10).
3. `PlanViewModel` error/state handling → one typed error path + one state model + a serialized mutation queue (ID‑14).
4. `ContentView` reload orchestration → a single refresh owner or a store signal (ID‑9).
5. `TransactionsViewModel` → split ledger data from per‑screen filter state (§8).
6. `Features/Home` prototype → delete or quarantine (ID‑13).
7. `AmountTextField` focus → `@FocusState` (ID‑20).

---

## 16. Recommended Refactoring Roadmap

Sequenced so each step is independently shippable and de‑risks the next.

### Phase 0 — Release blockers (do first, no feature work)
1. **ID‑4** Wrap all `*PreviewData` / `Preview*Store` in `#if DEBUG`; remove `PlanPreviewData` from `PlanViewModel`; require a store in production.
2. **ID‑1** Add `LedgerSchemaV1: VersionedSchema` + `LedgerMigrationPlan`; open the container with the plan; test.
3. **ID‑2** Add `PrivacyInfo.xcprivacy` (collects nothing; declare required‑reason APIs).
4. **ID‑5** Add `AppLogger`; log the real error in every `catch`; signposts around DB open/save.
5. **ID‑3** `SWIFT_STRICT_CONCURRENCY = complete`; fix fallout (expect repo isolation work — ID‑11); then `SWIFT_VERSION = 6.0`.

### Phase 1 — Scale & correctness (before any external beta)
6. **ID‑6** Bounded read API on `LedgerDatabase` (`recentTransactions(limit:)`, `transactions(in:filter:limit:)`, aggregate month totals); stop holding the whole table.
7. **ID‑9** One reload owner (per‑screen `.task(id:)`), debounce scene‑phase; or a store revision signal that VMs observe.
8. **ID‑8** `sortOrder` on `PlanAllocationRecord`; deterministic `materialize`; multi‑allocation round‑trip test.
9. **ID‑10** Plan children → cascading `@Relationship` (or predicate‑filtered FK + explicit cleanup); predicate fetches for `fetch(month:)`.
10. **ID‑7 / ID‑15** Single cached `MoneyFormatter`; one grouping convention app‑wide.

### Phase 2 — Architecture cleanup
11. **ID‑13** Delete/quarantine `Features/Home` prototype; drop `Charts` if unused.
12. **§8** Split `TransactionsViewModel` (ledger data vs. filter state); **ID‑19** single shared categories observable.
13. **ID‑14** `PlanViewModel`: typed errors, one state model, serialized mutation queue; replace `Bool` guards across all VMs.
14. **ID‑12** Memoize `visible*`; `[UUID: CategoryItem]` lookup; move `TransactionSummary` into the VM.
15. **ID‑21 / ID‑22 / ID‑20 / ID‑17 / ID‑16 / ID‑18** Batch of smaller fixes (stdlib `move`, trimmed validation, `@FocusState`, layout, filter labels, category refresh).

### Phase 3 — Production hardening
16. **ID‑23** File protection + optional biometric app lock.
17. Crash reporting (MetricKit subscriber), CI (`xcodebuild test` + the SPM check), UI smoke tests using the existing accessibility identifiers.
18. Export/backup before the first schema change; real app icon; iPad layout pass; localization structure (move user strings out of VMs).

---

## Appendix A — Issue Index by Severity

**Critical:** ID‑1 (migrations), ID‑2 (privacy manifest), ID‑3 (strict concurrency), ID‑4 (preview fixtures in prod), ID‑5 (no logging)

**High:** ID‑6 (unbounded fetches), ID‑7 (`NumberFormatter` per render), ID‑8 (allocation ordering), ID‑9 (reload churn), ID‑10 (plan FK/cascade/predicates), ID‑11 (repos not `Sendable`)

**Medium:** ID‑12 (non‑memoized `visible*`), ID‑13 (Home dead code), ID‑14 (`PlanViewModel` error/state), ID‑15 (money formatting inconsistency), ID‑16 (date filter labels), ID‑17 (`.fixedSize()` clipping), ID‑18 (`.onDisappear` refresh), ID‑19 (per‑view `CategoriesViewModel`), ID‑20 (`AmountTextField` focus), ID‑21 (manual list move), ID‑22 (untrimmed validation), ID‑23 (file protection)

**Low:** `.tint(.green)` repetition; app icon placeholder + `mac` slots; non‑localized `title` computed props; `Package.swift` exclude‑list brittleness; `Charts` linked for dead code; README "32 tests" drift; `PlanMonth.init` `precondition` as a latent trap; redundant `@MainActor` on `View` structs.

---

## Appendix B — What I deliberately did NOT flag as a problem

So the review isn't read as "change everything":

- **Manual `ModelContext` instead of `@Query`/`.modelContainer`.** A legitimate trade‑off that enables the actor isolation model. Keep it — just add the change‑signal (ID‑9) and bounded reads (ID‑6).
- **Passing dependencies explicitly instead of `@EnvironmentObject`.** Verbose but honest and testable. Fine.
- **`Int64` tiyn + `Decimal` arithmetic.** Correct. Do not switch to `Double` or a currency library.
- **One actor for the whole database.** Correct for the invariant set; don't shard it prematurely.
- **`AppRootView` async open with a retry screen.** This is the right pattern; other teams get this wrong.
- **Thorough validation and category‑reference guards.** Keep.
