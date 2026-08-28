import SwiftUI

/// Composes the screen; sections own their layout, and snapshots supply values.
struct HomeView: View {
    let snapshot: HomeSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Label("Sample data · not connected to your accounts", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Income").font(.subheadline).foregroundStyle(.secondary)
                    Text(snapshot.income.tenge).font(.largeTitle.bold()).minimumScaleFactor(0.6)
                }

                HomeSummarySection(snapshot: snapshot)
                MonthProgressSection(
                    fraction: 0.55,
                    caption: "55% of the month gone · sample date: August 17"
                )
                SpendingCategorySection(snapshot: snapshot)
                BudgetAlertsSection(categories: snapshot.overBudgetCategories)
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(snapshot.month)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Home · sample month") {
    NavigationStack {
        HomeView(snapshot: .demo)
    }
    .tint(.green)
}

#Preview("Home · dark mode") {
    NavigationStack {
        HomeView(snapshot: .demo)
    }
    .tint(.green)
    .preferredColorScheme(.dark)
}
