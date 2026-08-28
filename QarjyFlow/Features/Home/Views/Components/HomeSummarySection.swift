import SwiftUI

struct HomeSummarySection: View {
    let snapshot: HomeSnapshot

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { cards }
            VStack(spacing: 10) { cards }
        }
    }

    @ViewBuilder private var cards: some View {
        MoneySummaryCard(title: "Spent", amount: snapshot.spent, color: .red)
        MoneySummaryCard(title: "Saved", amount: snapshot.saved, color: .green)
        MoneySummaryCard(title: "Available", amount: snapshot.available, color: .blue)
    }
}

#Preview("Summary · income breakdown", traits: .sizeThatFitsLayout) {
    HomeSummarySection(snapshot: .demo)
        .padding(20)
}

#Preview("Summary · accessibility text", traits: .sizeThatFitsLayout) {
    HomeSummarySection(snapshot: .demo)
        .padding(20)
        .dynamicTypeSize(.accessibility1)
}
