import SwiftUI

struct PlanAllocationRow: View {
    let allocation: PlanAllocation
    let group: PlanGroup
    let income: Decimal

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: allocation.symbol)
                .font(.body.weight(.semibold)).foregroundStyle(group.tint)
                .frame(width: 40, height: 40)
                .background(group.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text(allocation.name).font(.subheadline.weight(.medium))
                switch allocation.rule {
                case .fixed: Text("Fixed amount").font(.caption).foregroundStyle(.secondary)
                case .percentage(let value):
                    Text("\(NSDecimalNumber(decimal: value).stringValue)% of expected income")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            Text(allocation.rule.amount(income: income).tenge)
                .font(.subheadline.weight(.semibold)).multilineTextAlignment(.trailing)
            Image(systemName: "chevron.right").font(.caption2.bold()).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6).frame(minHeight: 44).contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

#Preview("Allocation row · percentage", traits: .sizeThatFitsLayout) {
    PlanAllocationRow(allocation: PlanPreviewData.allocations[3], group: PlanPreviewData.groups[1],
                      income: PlanPreviewData.income).padding()
}
