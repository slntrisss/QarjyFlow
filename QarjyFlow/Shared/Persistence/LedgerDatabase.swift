import Foundation

/// A single serial worker protects category/transaction invariants together.
/// Contexts and SwiftData records stay inside this actor; only value types leave it.
actor LedgerDatabase {
    private let categories: CategoryRepository
    private let transactions: TransactionRepository
    private let plans: PlanRepository
    private let goals: GoalRepository

    private init(inMemory: Bool, url: URL?) throws {
        let container = try AppDatabase.makeContainer(inMemory: inMemory, url: url)
        categories = CategoryRepository(container: container)
        transactions = TransactionRepository(container: container)
        plans = PlanRepository(container: container)
        goals = GoalRepository(container: container)
    }

    static func open(inMemory: Bool = false, url: URL? = nil) async throws -> LedgerDatabase {
        // Container initialization may migrate/open disk data. Do not inherit the UI executor.
        try await Task.detached {
            try LedgerDatabase(inMemory: inMemory, url: url)
        }.value
    }

    func fetchCategories() throws -> [CategoryItem] { try categories.fetchAll() }
    func fetchTransactions() throws -> [TransactionItem] { try transactions.fetchAll() }
    func fetchSnapshot() throws -> LedgerSnapshot {
        // No suspension between reads: a concurrent delete/save cannot split the snapshot.
        try LedgerSnapshot(categories: categories.fetchAll(), transactions: transactions.fetchAll())
    }
    func saveCategory(_ draft: CategoryDraft, id: UUID?) throws -> CategoryItem {
        try categories.save(draft, id: id)
    }
    func setArchived(_ archived: Bool, id: UUID) throws -> CategoryItem {
        try categories.setArchived(archived, id: id)
    }
    func deleteCategory(id: UUID) throws { try categories.delete(id: id) }
    func saveTransaction(_ draft: TransactionDraft, id: UUID?) throws -> TransactionItem {
        try transactions.save(draft, id: id)
    }
    func deleteTransaction(id: UUID) throws { try transactions.delete(id: id) }
    func fetchPlan(month: PlanMonth) throws -> MonthlyPlan? { try plans.fetch(month: month) }
    func savePlan(_ plan: MonthlyPlan) throws -> MonthlyPlan { try plans.save(plan) }
    func fetchGoals() throws -> GoalSnapshot { try goals.fetchSnapshot() }
    func saveGoal(_ draft: GoalDraft, id: UUID?) throws -> FinancialGoal { try goals.save(draft, id: id) }
    func addGoalContribution(goalID: UUID, amountText: String, date: Date, note: String) throws -> GoalContribution {
        try goals.addContribution(goalID: goalID, amountText: amountText, date: date, note: note)
    }
    func deleteGoalContribution(id: UUID) throws { try goals.deleteContribution(id: id) }
    func deleteGoal(id: UUID) throws { try goals.deleteGoal(id: id) }

    func fetchHomeData(month: PlanMonth, calendar: Calendar = .current) throws -> HomeDataSnapshot {
        var components = DateComponents(); components.year = month.year; components.month = month.month
        guard let currentStart = calendar.date(from: components),
              let previousStart = calendar.date(byAdding: .month, value: -1, to: currentStart),
              let nextStart = calendar.date(byAdding: .month, value: 1, to: currentStart) else {
            return HomeDataSnapshot(transactions: [], categories: [], plan: nil, contributions: [])
        }
        return try HomeDataSnapshot(
            transactions: transactions.fetch(from: previousStart, to: nextStart),
            categories: categories.fetchAll(),
            plan: plans.fetch(month: month),
            contributions: goals.fetchContributions(from: currentStart, to: nextStart)
        )
    }
}
