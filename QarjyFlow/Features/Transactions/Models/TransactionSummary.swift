import Foundation

/// Recorded cash flow for a month, not an account balance or safe-to-spend budget.
struct TransactionSummary {
    let income: Decimal
    let expense: Decimal
    let count: Int
    var net: Decimal { income - expense }

    init(transactions: [TransactionItem], month: Date = Date(), calendar: Calendar = .current) {
        let interval = calendar.dateInterval(of: .month, for: month)
        let items = transactions.filter { item in
            guard let interval else { return false }
            return item.date >= interval.start && item.date < interval.end
        }
        income = items.filter { $0.kind == .income }.reduce(Decimal.zero) { $0 + $1.amount }
        expense = items.filter { $0.kind == .expense }.reduce(Decimal.zero) { $0 + $1.amount }
        count = items.count
    }
}
