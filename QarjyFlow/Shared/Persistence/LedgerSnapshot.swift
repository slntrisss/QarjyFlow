struct LedgerSnapshot: Sendable {
    let categories: [CategoryItem]
    let transactions: [TransactionItem]
}
