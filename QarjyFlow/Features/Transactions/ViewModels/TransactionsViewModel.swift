import Foundation
import Observation
import os

@MainActor
@Observable
final class TransactionsViewModel {
    private(set) var transactions: [TransactionItem] = []
    private(set) var categories: [CategoryItem] = []
    private(set) var hasLoaded = false
    private(set) var isMutating = false
    @ObservationIgnored private var revision = 0
    /// O(1) category lookups; avoids a linear scan per transaction per render.
    @ObservationIgnored private var categoryByID: [UUID: CategoryItem] = [:]
    @ObservationIgnored private var lastLoadedAt: Date?
    private(set) var loadFailed = false
    var filter: CategoryKind?
    var categoryFilterID: UUID?
    var dateFilter: TransactionDateFilter = .last7Days
    var customFromDate = Calendar.current.date(byAdding: .day, value: -6,
                                                to: Calendar.current.startOfDay(for: Date())) ?? Date()
    var customToDate = Date()
    var searchText = ""
    var errorMessage: String?
    @ObservationIgnored private let store: any TransactionStore

    init(store: any TransactionStore, initialSnapshot: LedgerSnapshot? = nil) {
        if let initialSnapshot {
            transactions = initialSnapshot.transactions
            categories = initialSnapshot.categories
            categoryByID = Dictionary(initialSnapshot.categories.map { ($0.id, $0) }) { first, _ in first }
            hasLoaded = true
        }
        self.store = store
    }

    var visibleTransactions: [TransactionItem] {
        transactions.filter { item in
            (filter == nil || filter == item.kind) &&
            (categoryFilterID == nil || categoryFilterID == item.categoryID) &&
            dateFilter.includes(item.date, from: customFromDate, to: customToDate) && (searchText.isEmpty ||
                item.merchant.localizedStandardContains(searchText) ||
                item.note.localizedStandardContains(searchText) ||
                (category(for: item)?.name.localizedStandardContains(searchText) ?? false))
        }
    }

    var filterCategories: [CategoryItem] {
        categories.filter { filter == nil || $0.kind == filter }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func category(for item: TransactionItem) -> CategoryItem? {
        categoryByID[item.categoryID]
    }

    /// - Parameter minInterval: skip if a successful load finished less than this
    ///   many seconds ago. Cheap triggers (tab switch, scene activation) pass a
    ///   small value to coalesce redundant reloads; explicit refresh passes 0.
    func load(minInterval: TimeInterval = 0) async {
        guard !isMutating else { return }
        if minInterval > 0, hasLoaded, let last = lastLoadedAt,
           Date().timeIntervalSince(last) < minInterval { return }
        revision += 1
        let request = revision
        do {
            let snapshot = try await store.fetchSnapshot()
            guard request == revision, !Task.isCancelled else { return }
            categories = snapshot.categories
            categoryByID = Dictionary(snapshot.categories.map { ($0.id, $0) }) { first, _ in first }
            transactions = snapshot.transactions
            hasLoaded = true
            loadFailed = false
            errorMessage = nil
            lastLoadedAt = Date()
        } catch {
            guard request == revision, !Task.isCancelled else { return }
            AppLog.transactions.error("Snapshot load failed: \(String(describing: error), privacy: .private(mask: .hash))")
            loadFailed = true
            errorMessage = "Could not load your transactions. Please try again."
        }
    }

    func save(_ draft: TransactionDraft, id: UUID?) async throws {
        guard !isMutating else { throw CancellationError() }
        isMutating = true
        revision += 1
        defer { isMutating = false }
        let saved = try await store.save(draft, id: id)
        transactions.removeAll { $0.id == saved.id }
        transactions.append(saved)
        transactions.sort { $0.date > $1.date }
    }

    func delete(_ item: TransactionItem) async {
        guard !isMutating else { return }
        isMutating = true
        revision += 1
        defer { isMutating = false }
        do {
            try await store.delete(id: item.id)
            transactions.removeAll { $0.id == item.id }
        } catch {
            AppLog.transactions.error("Delete failed: \(String(describing: error), privacy: .private(mask: .hash))")
            errorMessage = "Could not delete this transaction. Please try again."
        }
    }
}
