import SwiftUI

struct PlanGroupSection: View {
    let group: PlanGroup
    let allocations: [PlanAllocation]
    let income: Decimal
    let onEdit: (PlanAllocation) -> Void
    let onDelete: (PlanAllocation) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: group.symbol).foregroundStyle(group.tint)
                Text(group.name).font(.headline)
                Spacer()
                Text(allocations.reduce(Decimal.zero) { $0 + $1.rule.amount(income: income) }.tenge)
                    .font(.subheadline.weight(.semibold)).foregroundStyle(group.tint)
            }
            if !group.subtitle.isEmpty {
                Text(group.subtitle).font(.caption).foregroundStyle(.secondary)
            }
            if allocations.isEmpty {
                Text("No allocations in this section").font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            ForEach(allocations) { allocation in
                HStack(spacing: 4) {
                    Button { onEdit(allocation) } label: {
                        PlanAllocationRow(allocation: allocation, group: group, income: income)
                    }
                    .buttonStyle(.plain)
                    Menu {
                        Button("Edit Allocation", systemImage: "pencil") { onEdit(allocation) }
                        Button("Delete Allocation", systemImage: "trash", role: .destructive) {
                            onDelete(allocation)
                        }
                    } label: {
                        Image(systemName: "ellipsis").frame(width: 44, height: 44).contentShape(Rectangle())
                    }
                    .accessibilityLabel("Actions for \(allocation.name)")
                }
            }
            if allocations.contains(where: \.tracksContribution) {
                Label("Contribution tracking isn’t available yet.", systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.cardStyle()
    }
}

#Preview("Section · allocation actions", traits: .sizeThatFitsLayout) {
    PlanGroupSection(group: PlanPreviewData.groups[1],
                     allocations: PlanPreviewData.allocations.filter { $0.groupID == PlanPreviewData.futureID },
                     income: PlanPreviewData.income, onEdit: { _ in }, onDelete: { _ in }).padding()
}
