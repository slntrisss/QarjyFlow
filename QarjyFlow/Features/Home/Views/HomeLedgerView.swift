import SwiftUI

struct HomeLedgerView: View {
    @Bindable var model: TransactionsViewModel
    @State private var planModel: PlanViewModel
    @State private var goalsModel: GoalsViewModel

    init(model: TransactionsViewModel, planStore: (any PlanStore)? = nil,
         goalStore: any GoalStore = PreviewGoalStore()) {
        self.model = model
        _planModel = State(initialValue: PlanViewModel(store: planStore))
        _goalsModel = State(initialValue: GoalsViewModel(store: goalStore))
    }

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
        .onAppear { Task { await loadDashboardSources() } }
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
                let dashboard = HomeDashboardCalculator().calculate(
                    month: planModel.month, transactions: model.transactions,
                    plan: planModel.currentPlan, contributions: goalsModel.contributions
                )
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
                    }
                    .cardStyle()
                }
                if let change = dashboard.expenseChangeRate {
                    let direction = change >= 0 ? "more" : "less"
                    Text("You spent \(abs(NSDecimalNumber(decimal: change).intValue))% \(direction) than last month.")
                        .font(.subheadline).foregroundStyle(change > 0 ? .orange : .green)
                }

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
        .refreshable {
            async let ledger: Void = model.load()
            async let dashboard: Void = loadDashboardSources()
            _ = await (ledger, dashboard)
        }
    }

    private func loadDashboardSources() async {
        async let plan: Void = planModel.load()
        async let goals: Void = goalsModel.load()
        _ = await (plan, goals)
    }
}

#Preview("Home · recorded monthly totals") {
    NavigationStack {
        HomeLedgerView(model: TransactionPreviewData.model())
    }
    .tint(.green)
}
