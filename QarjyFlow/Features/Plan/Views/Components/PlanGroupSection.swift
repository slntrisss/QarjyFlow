import SwiftUI

struct PlanGroupSection: View {
    let group: PlanGroup
    let allocations: [AllocationProgress]
    let onEdit: (PlanAllocation) -> Void
    let onDelete: (PlanAllocation) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: group.symbol).foregroundStyle(group.tint)
                Text(group.name).font(.headline)
                Spacer()
                Text(allocations.reduce(Decimal.zero) { $0 + $1.planned }.tenge)
                    .font(.subheadline.weight(.semibold)).foregroundStyle(group.tint)
            }
            if !group.subtitle.isEmpty {
                Text(group.subtitle).font(.caption).foregroundStyle(.secondary)
            }
            if allocations.isEmpty {
                Text("No allocations in this section").font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            ForEach(allocations) { progress in
                let allocation = progress.allocation
                HStack(spacing: 4) {
                    Button { onEdit(allocation) } label: {
                        PlanAllocationRow(progress: progress, group: group)
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
            if allocations.contains(where: { $0.allocation.tracksContribution }) {
                Label("Contribution tracking isn’t available yet.", systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.cardStyle()
    }
}

#Preview("Section · allocation actions", traits: .sizeThatFitsLayout) {
    let allocations = PlanPreviewData.allocations.filter { $0.groupID == PlanPreviewData.futureID }.map {
        AllocationProgress(allocation: $0, planned: $0.rule.amount(income: PlanPreviewData.income), actual: nil)
    }
    PlanGroupSection(group: PlanPreviewData.groups[1],
                     allocations: allocations, onEdit: { _ in }, onDelete: { _ in }).padding()
}
