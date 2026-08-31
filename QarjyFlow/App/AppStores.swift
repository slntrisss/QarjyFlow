import Foundation

/// Both stores use the same local database, while keeping separate operation contexts.
@MainActor
struct AppStores {
    let categories: any CategoryStore
    let transactions: any TransactionStore

    static func live() throws -> AppStores {
        let container = try AppDatabase.makeContainer()
        return AppStores(
            categories: SwiftDataCategoryStore(container: container),
            transactions: SwiftDataTransactionStore(container: container)
        )
    }

    func transactionModel() -> TransactionsViewModel {
        TransactionsViewModel(store: transactions, categoryStore: categories)
    }
}
