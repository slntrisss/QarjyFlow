import SwiftUI

struct SpendingCategorySection: View {
    let snapshot: HomeSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Spending by category").font(.headline)
            SpendingDonutChart(categories: snapshot.categories, total: snapshot.spent)
            ForEach(snapshot.categories) { category in
                NavigationLink {
                    CategoryDetailView(category: category)
                } label: {
                    CategorySpendingRow(category: category)
                }
            }
        }.cardStyle()
    }
}

#Preview("Spending section · tap a category") {
    NavigationStack {
        ScrollView {
            SpendingCategorySection(snapshot: .demo)
                .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }
    .tint(.green)
}
