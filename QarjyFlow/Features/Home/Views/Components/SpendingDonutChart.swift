import SwiftUI
import Charts

struct SpendingDonutChart: View {
    let categories: [CategorySnapshot]
    let total: Decimal

    var body: some View {
        Chart(categories) { category in
            SectorMark(
                angle: .value("Spent", NSDecimalNumber(decimal: category.spent).doubleValue),
                innerRadius: .ratio(0.72), angularInset: 2
            )
            .foregroundStyle(by: .value("Category", category.name))
            .cornerRadius(4)
        }
        .chartLegend(.hidden)
        .frame(height: 170)
        .chartBackground { _ in
            VStack(spacing: 4) {
                Text("Total spent").font(.caption).foregroundStyle(.secondary)
                Text(total.tenge).font(.subheadline.bold())
            }
        }
        .accessibilityLabel("Spending breakdown. Amounts are listed below.")
    }
}

#Preview("Spending chart · category distribution", traits: .sizeThatFitsLayout) {
    SpendingDonutChart(
        categories: HomeSnapshot.demo.categories,
        total: HomeSnapshot.demo.spent
    )
    .padding(20)
}
