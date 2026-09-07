import SwiftUI

struct HomeLedgerView: View {
    @State private var model: HomeDashboardViewModel
    @Environment(\.scenePhase) private var scenePhase

    init(store: any HomeStore) {
        _model = State(initialValue: HomeDashboardViewModel(store: store))
    }

    var body: some View {
        Group {
            if let dashboard = model.dashboard {
                dashboardView(dashboard)
            } else if let error = model.errorMessage {
                ContentUnavailableView {
                    Label("Dashboard unavailable", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Reload") { Task { await model.load() } }
                }
            } else if model.showLoading {
                ProgressView("Opening your dashboard…")
            } else {
                Color(uiColor: .systemGroupedBackground)
            }
        }
        .navigationTitle("QarjyFlow")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { Task { await model.load() } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.load() } }
        }
    }

    private func dashboardView(_ dashboard: HomeDashboardSnapshot) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(model.month.title)
                    .font(.title2.bold())
                VStack(spacing: 12) {
                    MoneySummaryCard(title: "Recorded income", amount: dashboard.recordedIncome, color: .green)
                    MoneySummaryCard(title: "Recorded expenses", amount: dashboard.recordedExpenses, color: .orange)
                    MoneySummaryCard(title: "Goal contributions", amount: dashboard.goalContributions, color: .purple)
                    MoneySummaryCard(title: "Calculated remaining", amount: dashboard.calculatedRemaining, color: .blue)
                }
                Text("Calculated remaining is recorded income minus expenses and goal contributions. It is not a verified bank balance.")
                    .font(.footnote).foregroundStyle(.secondary)

                if let rate = dashboard.savingsRate {
                    LabeledContent("Saved this month",
                                   value: "\(rate.formatted(.number.precision(.fractionLength(0...1))))%")
                        .font(.headline)
                }
                if dashboard.hasPlan {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Plan progress").font(.headline)
                        LabeledContent("Planned", value: dashboard.plannedAmount.tenge)
                        LabeledContent("Actual", value: dashboard.actualAgainstPlan.tenge)
                        if let overspend = dashboard.largestOverspend,
                           let amount = overspend.remaining {
                            Label("\(overspend.allocation.name) is over by \(abs(amount).tenge)",
                                  systemImage: "exclamationmark.triangle.fill")
                                .font(.subheadline).foregroundStyle(.orange)
                        }
                    }.cardStyle()
                }
                if let change = dashboard.expenseChangeRate {
                    let direction = change >= 0 ? "more" : "less"
                    Text("You spent \(abs(NSDecimalNumber(decimal: change).intValue))% \(direction) than last month.")
                        .font(.subheadline).foregroundStyle(change > 0 ? .orange : .green)
                }

                if model.recentTransactions.isEmpty {
                    Text("No transactions recorded in the last 7 days.")
                        .font(.headline).foregroundStyle(.secondary)
                } else {
                    Text("Recent transactions").font(.headline)
                    ForEach(Array(model.recentTransactions.enumerated()), id: \.element.id) { index, item in
                        TransactionRow(transaction: item, category: model.category(for: item))
                        if index < model.recentTransactions.count - 1 { Divider() }
                    }
                }
            }.padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .refreshable { await model.load() }
    }
}

#Preview("Home · empty bounded dashboard") {
    NavigationStack { HomeLedgerView(store: PreviewHomeStore()) }.tint(.green)
}
