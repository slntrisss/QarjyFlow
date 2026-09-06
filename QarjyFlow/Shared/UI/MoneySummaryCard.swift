import SwiftUI

struct MoneySummaryCard: View {
    let title: String
    let amount: Decimal
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(color)
            Text(amount.tenge)
                .font(.subheadline.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(12)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview("Money card · spent", traits: .sizeThatFitsLayout) {
    MoneySummaryCard(title: "Spent", amount: 1_041_400, color: .red)
        .padding(20)
}

#Preview("Money card · saved", traits: .sizeThatFitsLayout) {
    MoneySummaryCard(title: "Saved", amount: 468_750, color: .green)
        .padding(20)
}
