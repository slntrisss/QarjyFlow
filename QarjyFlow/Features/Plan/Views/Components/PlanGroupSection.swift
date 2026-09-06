import SwiftUI

struct PlanGroupSection: View {
    let group: PlanGroup
    let allocations: [AllocationProgress]
    let onEdit: (PlanAllocation) -> Void
    let onDelete: (PlanAllocation) -> Void

    var body: some View {
        Section {
            if allocations.isEmpty {
                Text("No allocations in this section")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            ForEach(allocations) { progress in
                let allocation = progress.allocation
                Button { onEdit(allocation) } label: {
                    PlanAllocationRow(progress: progress, group: group)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        onDelete(allocation)
                    }
                    .tint(.red)
                }
            }
            if allocations.contains(where: { $0.allocation.tracksContribution && $0.actual == nil }) {
                Label("Contribution tracking isn’t available yet.", systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.secondary)
            }
        } header: {
            VStack(alignment: .leading, spacing: 4) {
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
            }
            .textCase(nil)
        }
    }
}

#Preview("Section · tap and swipe actions") {
    let allocations = PlanPreviewData.allocations.filter { $0.groupID == PlanPreviewData.futureID }.map {
        AllocationProgress(allocation: $0, planned: $0.rule.amount(income: PlanPreviewData.income), actual: nil)
    }
    List {
        PlanGroupSection(group: PlanPreviewData.groups[1],
                         allocations: allocations, onEdit: { _ in }, onDelete: { _ in })
    }
}
