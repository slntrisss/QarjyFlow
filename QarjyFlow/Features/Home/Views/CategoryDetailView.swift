import SwiftUI

struct CategoryDetailView: View {
    let category: CategorySnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Label("Sample budget", systemImage: category.symbol)
                    .font(.subheadline).foregroundStyle(.secondary)
                Text(category.budget.tenge).font(.largeTitle.bold())
                ProgressView(value: min(category.budgetFraction, 1))
                    .tint(category.remaining < 0 ? .red : .green)
                LabeledContent("Spent", value: category.spent.tenge)
                LabeledContent(
                    category.remaining < 0 ? "Over budget" : "Remaining",
                    value: abs(category.remaining).tenge
                )
                .foregroundStyle(category.remaining < 0 ? .red : .green)
                Text("Transaction history and budget editing will arrive in the next milestones. These amounts are for design review only.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }.cardStyle().padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Category detail · within budget") {
    NavigationStack {
        CategoryDetailView(category: .demoFood)
    }
    .tint(.green)
}

#Preview("Category detail · over budget") {
    NavigationStack {
        CategoryDetailView(category: .demoEntertainment)
    }
    .tint(.green)
}
