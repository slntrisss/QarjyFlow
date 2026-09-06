import SwiftUI

struct HomeLedgerView: View {
    @Bindable var model: TransactionsViewModel

    var body: some View {
        Group {
            if model.hasLoaded {
                ledger
            } else if model.loadFailed {
                ContentUnavailableView {
                    Label("Transactions unavailable", systemImage: "exclamationmark.triangle")
                } description: {
                    Text("We could not load your saved data. No balances are shown until loading succeeds.")
                } actions: {
                    Button("Reload") { Task { await model.load() } }
                }
            } else {
                ProgressView("Loading transactions…")
            }
        }
        .navigationTitle("QarjyFlow")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var ledger: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                let month = Date()
                if model.loadFailed {
                    Label("Could not refresh. Showing previously loaded transactions.", systemImage: "exclamationmark.triangle")
                        .font(.footnote).foregroundStyle(.orange)
                }
                Text(month, format: .dateTime.month(.wide).year())
                    .font(.title2.bold())
                let summary = TransactionSummary(transactions: model.transactions, month: month)
                VStack(spacing: 12) {
                    MoneySummaryCard(title: "Recorded income", amount: summary.income, color: .green)
                    MoneySummaryCard(title: "Recorded expenses", amount: summary.expense, color: .orange)
                    MoneySummaryCard(title: "Net this month", amount: summary.net, color: .blue)
                }
                Text("Net is income minus expenses you recorded this month. It is not your bank balance or an amount safe to spend.")
                    .font(.footnote).foregroundStyle(.secondary)
                Label("Expected income and allocations entered in Plan do not change these recorded totals. Record money when it is actually received or spent in Activity.",
                      systemImage: "info.circle")
                    .font(.footnote).foregroundStyle(.secondary)

                if model.transactions.isEmpty {
                    Text("Your first transaction starts the story.").font(.headline)
                    Text("Create a category, then record income when it arrives or an expense when you spend it in Activity.")
                        .foregroundStyle(.secondary)
                } else {
                    Text("Recent transactions").font(.headline)
                    let recent = Array(model.transactions.prefix(5))
                    ForEach(Array(recent.enumerated()), id: \.element.id) { index, item in
                        TransactionRow(transaction: item, category: model.category(for: item))
                        if index < recent.count - 1 { Divider() }
                    }
                }
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("QarjyFlow")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await model.load() }
    }
}

#Preview("Home · recorded monthly totals") {
    NavigationStack {
        HomeLedgerView(model: TransactionPreviewData.model())
    }
    .tint(.green)
}
