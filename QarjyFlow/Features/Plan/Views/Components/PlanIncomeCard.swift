import SwiftUI

struct PlanIncomeCard: View {
    let expected: Decimal
    let recorded: Decimal
    let sourceCount: Int
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Expected monthly income", systemImage: "arrow.down.left.circle")
                    .font(.subheadline)
                Spacer()
                Button("Edit", action: onEdit).font(.subheadline.weight(.semibold))
            }
            Text(expected.tenge).font(.largeTitle.bold()).minimumScaleFactor(0.6)
            Text("\(sourceCount) planned source\(sourceCount == 1 ? "" : "s")")
                .font(.caption)
            Divider()
            LabeledContent("Recorded in Activity", value: recorded.tenge)
                .font(.subheadline.weight(.medium))
            let difference = expected - recorded
            LabeledContent(difference >= 0 ? "Still expected" : "Above expected",
                           value: abs(difference).tenge)
                .font(.caption).foregroundStyle(difference >= 0 ? Color.secondary : Color.green)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(20)
        .background(.green.opacity(0.09), in: RoundedRectangle(cornerRadius: 20))
    }
}

#Preview("Plan income · multiple expected sources", traits: .sizeThatFitsLayout) {
    PlanIncomeCard(expected: PlanPreviewData.income, recorded: 650_000,
                   sourceCount: 2, onEdit: {}).padding()
}
