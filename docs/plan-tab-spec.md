# Plan tab: product context and implementation brief

## Source and status

Imported from the accessible ChatGPT conversation **Plan Personal Finance App**, at the user's request in the development task. The relevant source is the latest detailed Plan response plus the initial product discovery exchange. Unrelated discussions and attachments have not been copied here.

The user's expressed aim is to distribute salary, understand where money goes, compare intentions with actual spending, and build a clear monthly financial picture. The specific screens below were proposed in that conversation; importing them does not mean every suggested detail has been separately approved. They are the working design direction, with unresolved rules explicitly listed below.

This document is the product context handoff. The Plan overview, expected-income editor, allocation editor, and customizable-section manager now operate on a locally persisted monthly plan. Named component previews use isolated in-memory fixtures.

## Purpose

**Plan allocates expected income before it is spent. Activity records what actually happened.**

The app should organize this experience by month. An August plan and a September plan are independent records. Editing one must not silently rewrite another or a future default template.

## Proposed Plan scope from the conversation

### 1. Monthly overview

- Previous/next month navigation.
- Expected monthly income, with multiple manually entered sources such as salary and freelance work.
- Total allocated and unallocated amounts, with proportions and a progress indicator.
- Allocation edits update the unallocated amount immediately in the draft.
- Allocating exactly 100% is not compulsory.
- Labels say **Allocated**, not **Spent**, for planned money.

### 2. Allocation groups

The default groups are **Needs**, **Future**, **Lifestyle**, and **Free**. Users may add, rename, style, and reorder groups. A confirmed group deletion removes that group and its allocations together, returning their planned amounts to Unallocated. These are presentation/planning groups, not income/expense transaction types. Stable group IDs keep allocations attached across renames and reordering.

The main hierarchy is `Monthly plan → Group → Allocation`:

- Needs: housing, groceries, transport, and similar expense categories.
- Lifestyle: entertainment, shopping, subscriptions, hobbies.
- Future: emergency fund, investments, apartment, travel fund.
- Free: an explicitly reserved flexible amount, if we retain this group.

Expense allocations should reference existing user-created category IDs. Future allocations need a separate planning-purpose concept; do not manufacture expense transactions or expense categories just to represent savings.

### 3. Fixed amounts and percentages

Each allocation supports either a fixed KZT amount or a percentage of expected monthly income.

Example from the proposed interaction:

- Rent is fixed at 250,000 ₸.
- Investments are set to 30% of planned income.
- At 800,000 ₸ income, investments resolve to 240,000 ₸.
- At 1,000,000 ₸ income, investments resolve to 300,000 ₸, while rent stays fixed.

Persist the allocation mode and percentage, not just the resulting amount. Otherwise copying or recalculating the plan loses the user's intent.

### 4. Planned versus actual

For expense categories, show **Planned / Spent / Remaining**, progress, approaching-limit states, and overspending.

Actual spending comes from saved expense transactions for that category and month. Changing a budget must not change transaction history. An allocation is not another expense.

For Future purposes, the intended labels are **Planned / Contributed / Remaining**. Contributions cannot be inferred from ordinary expenses. Until accounts/transfers or another explicit contribution mechanism exist, show contribution tracking as unavailable, not as a fabricated zero or completed target.

Expected income in Plan is separate from received income in Activity. Entering expected salary must not automatically create an income transaction. A richer expected-versus-received reconciliation flow was proposed for after the initial version.

### 5. Move budget / cover overspending

Allow a user to move an allocation amount from one purpose/category to another within the same month.

The operation changes planned amounts, keeps the total allocated amount unchanged, and does not create a money transfer or transaction. Both changes must save atomically.

The source example moves 11,500 ₸ from Entertainment to Restaurants to cover overspending.

### 6. Create a new month or copy the previous one

- Start a new plan from scratch or copy the previous month's plan.
- Fixed allocations retain their amounts.
- Percentage allocations recalculate against the new month's expected income.
- Copy planning inputs only, not actual transactions or recorded contributions.
- The copied plan must be editable independently of the source.

### 7. Supporting screens

The source proposed these seven UI states/screens:

1. Plan overview.
2. Add/edit planned income.
3. Edit allocation in an amount/percentage sheet.
4. Add/select category and assign its planning group.
5. Category allocation detail with actual transactions.
6. Move budget.
7. New month / copy plan.

Reuse the existing category editor and amount-field component where appropriate. Do not introduce a competing category list with separate identities.

## Later features in the source

- Default plan templates, distinct from monthly plan instances.
- Month-end review and explicit rollover decisions.
- Expected-versus-received income differences and allocation suggestions.
- Goals and contribution progress.
- Recurring income automation, smarter insights, and eventual integrations.

These should not be silently added to the first Plan milestone. A frequency/day field in the source's income sketch is not a commitment to a recurring transaction engine.

## Reconciliation with today's code

Already implemented:

- Dynamic income/expense categories with stable IDs, colors, and icons.
- Local income/expense transaction CRUD and exact monetary storage.
- Activity and recorded monthly Home totals.
- A live space-grouped amount field and component previews.

Missing for Plan:

- Planned-versus-actual views, budget moves, and copy-month behavior.
- Month navigation and reusable plan templates.
- Explicit contribution records for Future purposes.

Accounts/transfers and investment purchases are not implemented. Therefore the proposed Future contribution progress is not currently backed by real data. Production category and transaction persistence now runs through one shared background actor with asynchronous store boundaries; observable UI state remains on MainActor.

Category deletion and type-change guards cover transaction and Plan references. Archiving preserves existing historical allocations while excluding the category from new allocations.

## Rules to settle before implementation

These are engineering/product questions exposed by the source, not decisions already made by the user:

1. **Free versus Unallocated.** Recommended distinction: Free is an explicit flexible allocation; Unallocated is expected income minus all allocations, including Free. Never count the same remainder in both places, and do not label either as an actual account balance or guaranteed safe-to-spend amount.
2. **Over-allocation.** Decide whether saving a plan over expected income is allowed with a warning or blocked. Never silently reduce another allocation to compensate.
3. **Percentage base and rounding.** Use expected monthly income as the proposed base. Define precision, minor-unit rounding, and handling of rounding residuals explicitly and test them.
4. **Current-month income edits.** Confirm how percentage allocations recalculate and how the UI explains the effect before saving. Recorded income must not silently alter the plan.
5. **Moves involving percentages.** Decide whether a budget move creates a month-specific adjustment or changes allocation mode. Do not silently turn percentage intent into a fixed amount.
6. **Future contributions.** Decide whether tracking waits for local accounts/transfers or uses a distinct explicit contribution record. No double-counting as spending.
7. **Group ownership.** Decide whether groups are fixed for the first version and whether category-to-group placement belongs to each monthly allocation or a reusable default. Historical months must remain stable.
8. **Unbudgeted and archived categories.** Expense history without an allocation must still be visible; archiving cannot erase planned-versus-actual history. Define what gets copied into a new month.

## Suggested implementation sequence

1. Review this scope and resolve the accounting rules above. Complete the persistence concurrency refactor before expanding database work.
2. Build the Plan overview and allocation/income editor previews, using the current visual language and fixtures.
3. Implement one persisted slice: select month → enter expected income → allocate fixed/percentage amounts → see unallocated update.
4. Connect expense actuals from Activity, with category details and over-budget states.
5. Add atomic budget moves and independent month copying.
6. Add Future contribution tracking only when its underlying records exist.

Use feature-oriented MVVM, one primary type per file, reusable UI components, and previews for every new view. Test monetary calculations, month boundaries, copy independence, category protections, failure recovery, and migration before considering the feature complete.

## Implemented persisted slice

Plan creates an empty record for the current month and stores expected-income sources, custom ordered sections, and fixed or percentage allocations locally. Expense allocations reference dynamic expense categories; Future purposes can exist without a category. Expected income never creates an Activity transaction. Deleting an allocation or section returns its amount to Unallocated and never deletes Activity data. Category guards prevent deleting or changing the type of a referenced category. Every view retains a named preview backed by isolated fixtures. Planned-versus-actual values, month navigation, budget moves, copies, and Future contribution tracking remain future work.
