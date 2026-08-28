import SwiftUI

struct BudgetAlertsSection: View {
    let categories: [CategorySnapshot]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Plan vs actual").font(.headline)
            ForEach(categories) { category in
                NavigationLink {
                    CategoryDetailView(category: category)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(category.name).font(.subheadline.bold())
                            Text("\((-category.remaining).tenge) over budget").font(.caption)
                        }
                        Spacer()
                        Text(category.budgetFraction, format: .percent.precision(.fractionLength(0)))
                            .font(.title3.bold())
                    }
                    .foregroundStyle(.red).padding()
                    .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }
}

#Preview("Budget alerts · tap to see details") {
    NavigationStack {
        BudgetAlertsSection(categories: HomeSnapshot.demo.overBudgetCategories)
            .padding(20)
    }
    .tint(.green)
}
