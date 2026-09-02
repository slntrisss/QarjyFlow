import Foundation

@MainActor
enum TransactionPreviewData {
    static func stores(seed: Bool = true) -> AppStores { fixture(seed: seed).stores }

    static func model(seed: Bool = true) -> TransactionsViewModel {
        let fixture = fixture(seed: seed)
        do {
            return TransactionsViewModel(store: fixture.transactions,
                initialSnapshot: try fixture.transactions.fetchSnapshot())
        } catch { fatalError("Could not load preview: \(error)") }
    }

    private static func fixture(seed: Bool) -> (stores: AppStores, transactions: PreviewTransactionStore) {
        do {
            let container = try AppDatabase.makeContainer(inMemory: true)
            let categories = PreviewCategoryStore(repository: CategoryRepository(container: container))
            let transactions = PreviewTransactionStore(
                repository: TransactionRepository(container: container), categories: categories
            )
            if seed {
                var food = CategoryDraft()
                food.name = "Groceries"
                food.symbol = "fork.knife"
                food.color = .orange
                let foodItem = try categories.save(food, id: nil)
                var salary = CategoryDraft()
                salary.name = "Salary"
                salary.kind = .income
                salary.symbol = "briefcase.fill"
                let salaryItem = try categories.save(salary, id: nil)
                var expense = TransactionDraft()
                expense.amountText = "12560"
                expense.categoryID = foodItem.id
                expense.merchant = "Magnum"
                _ = try transactions.save(expense, id: nil)
                var income = TransactionDraft()
                income.amountText = "1875000"
                income.kind = .income
                income.categoryID = salaryItem.id
                income.note = "Monthly salary"
                _ = try transactions.save(income, id: nil)
            }
            return (AppStores(categories: categories, transactions: transactions), transactions)
        } catch { fatalError("Could not build transaction preview: \(error)") }
    }
}
