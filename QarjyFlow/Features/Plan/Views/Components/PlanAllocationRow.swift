import SwiftUI

struct PlanAllocationRow: View {
    let progress: AllocationProgress
    let group: PlanGroup

    private var allocation: PlanAllocation { progress.allocation }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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
                Image(systemName: "chevron.right").font(.caption2.bold()).foregroundStyle(.tertiary)
            }
            if let actual = progress.actual, let remaining = progress.remaining {
                HStack(alignment: .top, spacing: 12) {
                    metric("Planned", value: progress.planned, color: .primary)
                    metric("Spent", value: actual, color: .primary)
                    metric(progress.isOverBudget ? "Over" : "Remaining", value: abs(remaining),
                           color: progress.isOverBudget ? .red : .green)
                }
                if let fraction = progress.fractionUsed {
                    ProgressView(value: min(max(NSDecimalNumber(decimal: fraction).doubleValue, 0), 1))
                        .tint(progress.isOverBudget ? .red : group.tint)
                }
            } else {
                HStack {
                    metric("Planned", value: progress.planned, color: .primary)
                    Spacer()
                    Label("Actual unavailable", systemImage: "info.circle")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6).frame(minHeight: 44).contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func metric(_ title: String, value: Decimal, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value.tenge).font(.caption.weight(.semibold)).foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Allocation row · percentage", traits: .sizeThatFitsLayout) {
    let allocation = PlanPreviewData.allocations[3]
    PlanAllocationRow(progress: AllocationProgress(
        allocation: allocation, planned: allocation.rule.amount(income: PlanPreviewData.income), actual: nil
    ), group: PlanPreviewData.groups[1]).padding()
}
