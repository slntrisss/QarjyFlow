import Foundation
import Observation

@MainActor @Observable
final class HomeDashboardViewModel {
    let month: PlanMonth
    private(set) var dashboard: HomeDashboardSnapshot?
    private(set) var recentTransactions: [TransactionItem] = []
    private(set) var categoriesByID: [UUID: CategoryItem] = [:]
    private(set) var isLoading = false
    private(set) var showLoading = false
    var errorMessage: String?
    @ObservationIgnored private let store: any HomeStore
    @ObservationIgnored private var revision = 0

    init(store: any HomeStore, month: PlanMonth = PlanMonth()) {
        self.store = store; self.month = month
    }

    func load() async {
        revision += 1
        let request = revision
        isLoading = true
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard let self, self.isLoading, self.revision == request, self.dashboard == nil else { return }
            self.showLoading = true
        }
        defer {
            if request == revision { isLoading = false; showLoading = false }
        }
        do {
            let data = try await store.fetch(month: month)
            guard request == revision, !Task.isCancelled else { return }
            dashboard = HomeDashboardCalculator().calculate(
                month: month, transactions: data.transactions, plan: data.plan,
                contributions: data.contributions
            )
            categoriesByID = Dictionary(data.categories.map { ($0.id, $0) }) { first, _ in first }
            let calendar = Calendar.current
            let start = calendar.date(byAdding: .day, value: -6,
                                      to: calendar.startOfDay(for: Date())) ?? Date()
            recentTransactions = Array(data.transactions.filter { $0.date >= start }.prefix(5))
            errorMessage = nil
        } catch {
            guard request == revision, !Task.isCancelled else { return }
            errorMessage = "Could not load your dashboard. Your saved data is unchanged."
        }
    }

    func category(for transaction: TransactionItem) -> CategoryItem? {
        categoriesByID[transaction.categoryID]
    }
}
