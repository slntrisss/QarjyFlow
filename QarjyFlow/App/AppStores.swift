import Foundation

/// Both feature stores share one actor-isolated local database.
@MainActor
struct AppStores {
    let categories: any CategoryStore
    let transactions: any TransactionStore
    let plans: any PlanStore

    static func live() async throws -> AppStores {
        let database = try await LedgerDatabase.open()
        return AppStores(
            categories: SwiftDataCategoryStore(database: database),
            transactions: SwiftDataTransactionStore(database: database),
            plans: SwiftDataPlanStore(database: database)
        )
    }

    func transactionModel() -> TransactionsViewModel {
        TransactionsViewModel(store: transactions)
    }
}
