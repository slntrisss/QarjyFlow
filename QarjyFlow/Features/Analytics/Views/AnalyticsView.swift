import SwiftUI

struct AnalyticsView: View {
    @State private var model: AnalyticsViewModel

    init(store: any HomeStore) {
        _model = State(initialValue: AnalyticsViewModel(store: store))
    }

    var body: some View {
        Group {
            if let snapshot = model.snapshot { content(snapshot) }
            else if let message = model.errorMessage {
                ContentUnavailableView("Analytics unavailable", systemImage: "chart.bar.xaxis",
                                       description: Text(message))
            } else { ProgressView("Calculating analytics…") }
        }
        .navigationTitle("Analytics")
        .onAppear { Task { await model.load() } }
        .refreshable { await model.load() }
    }

    private func content(_ snapshot: AnalyticsSnapshot) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(model.month.title).font(.title2.bold())
                LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
                    AnalyticsMetricCard(title: "Total spent", value: snapshot.totalSpent.tenge,
                                        subtitle: comparisonText(snapshot), color: .orange)
                    AnalyticsMetricCard(title: "Savings rate", value: percentage(snapshot.savingsRate),
                                        subtitle: "of recorded income", color: .green)
                    AnalyticsMetricCard(title: "Average daily", value: snapshot.averageDailySpend.tenge,
                                        subtitle: "this month", color: .blue)
                    AnalyticsMetricCard(title: "Left", value: snapshot.calculatedRemaining.tenge,
                                        subtitle: "calculated, not bank balance", color: .purple)
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("Spending by category").font(.headline)
                    if snapshot.categories.isEmpty {
                        Text("No expenses recorded this month.").foregroundStyle(.secondary)
                    }
                    ForEach(snapshot.categories) { metric in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Label(metric.category.name, systemImage: metric.category.symbol)
                                    .foregroundStyle(metric.category.color.tint)
                                Spacer()
                                Text(metric.amount.tenge).fontWeight(.semibold)
                            }
                            ProgressView(value: min(NSDecimalNumber(decimal: metric.share).doubleValue, 100), total: 100)
                                .tint(metric.category.color.tint)
                            Text("\(percentage(metric.share)) of spending")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }.cardStyle()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Plan variance").font(.headline)
                    if snapshot.planProgress.isEmpty {
                        Text("Create a monthly plan to compare expected and actual spending.")
                            .foregroundStyle(.secondary)
                    } else if snapshot.overspentAllocations.isEmpty {
                        Label("No allocation is over plan.", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        ForEach(snapshot.overspentAllocations) { progress in
                            HStack {
                                Text(progress.allocation.name)
                                Spacer()
                                Text("+\(abs(progress.remaining ?? 0).tenge)")
                                    .fontWeight(.semibold).foregroundStyle(.red)
                            }
                        }
                    }
                }.cardStyle()
            }.padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private func percentage(_ value: Decimal?) -> String {
        guard let value else { return "—" }
        return "\(value.formatted(.number.precision(.fractionLength(0...1))))%"
    }

    private func comparisonText(_ snapshot: AnalyticsSnapshot) -> String {
        guard let rate = snapshot.spendingChangeRate else { return "No previous-month baseline" }
        return "\(percentage(abs(rate))) \(rate >= 0 ? "more" : "less") than last month"
    }
}

#Preview("Analytics · empty") {
    NavigationStack { AnalyticsView(store: PreviewHomeStore()) }.tint(.green)
}

#Preview("Analytics · realistic monthly scenario") {
    NavigationStack { AnalyticsView(store: PreviewHomeStore(snapshot: HomeScenarioPreviewData.rich)) }
        .tint(.green)
}
