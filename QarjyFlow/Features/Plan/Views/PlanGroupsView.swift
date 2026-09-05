import SwiftUI

struct PlanGroupsView: View {
    @Bindable var model: PlanViewModel
    @State private var isAdding = false
    @State private var editing: PlanGroup?
    @State private var pendingDeletion: [PlanGroup] = []

    private var pendingIDs: Set<UUID> { Set(pendingDeletion.map(\.id)) }
    private var pendingAllocationCount: Int {
        model.allocations.filter { pendingIDs.contains($0.groupID) }.count
    }
    private var releasedAmount: Decimal { model.allocatedAmount(inGroupIDs: pendingIDs) }

    var body: some View {
        List {
            Section {
                ForEach(model.groups) { group in
                    Button { editing = group } label: {
                        HStack(spacing: 12) {
                            Image(systemName: group.symbol).foregroundStyle(group.tint)
                                .frame(width: 40, height: 40)
                                .background(group.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(group.name).foregroundStyle(.primary)
                                Text(group.subtitle.isEmpty ? "No description" : group.subtitle)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(model.allocations.filter { $0.groupID == group.id }.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contextMenu {
                        Button("Edit Section", systemImage: "pencil") { editing = group }
                        Button("Delete Section", systemImage: "trash", role: .destructive) {
                            pendingDeletion = [group]
                        }
                    }
                }
                .onMove { source, destination in Task { await model.moveGroups(from: source, to: destination) } }
                .onDelete { pendingDeletion = $0.sorted().map { model.groups[$0] } }
            } footer: {
                Text("Drag to reorder. Deleting a section also deletes its allocations and returns their planned amounts to Unallocated.")
            }
            Section {
                Text("These are Plan sections, not income/expense transaction types.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Plan Sections")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { EditButton() }
            ToolbarItem(placement: .primaryAction) {
                Button { isAdding = true } label: {
                    Image(systemName: "plus").font(.title2.weight(.semibold)).frame(minWidth: 44, minHeight: 44)
                }.accessibilityLabel("Add Plan Section")
            }
        }
        .sheet(isPresented: $isAdding) { PlanGroupEditorView(onSave: model.saveGroup) }
        .sheet(item: $editing) { PlanGroupEditorView(group: $0, onSave: model.saveGroup) }
        .confirmationDialog(
            pendingDeletion.count == 1 ? "Delete \(pendingDeletion[0].name)?" : "Delete selected sections?",
            isPresented: Binding(get: { !pendingDeletion.isEmpty }, set: { if !$0 { pendingDeletion = [] } }),
            titleVisibility: .visible
        ) {
            Button(pendingDeletion.count == 1 ? "Delete Section and Allocations" : "Delete Sections and Allocations",
                   role: .destructive) {
                let ids = pendingIDs
                pendingDeletion = []
                Task { await model.deleteGroups(ids: ids) }
            }
            Button("Cancel", role: .cancel) { pendingDeletion = [] }
        } message: {
            Text(pendingAllocationCount == 0
                 ? "This section has no allocations."
                 : "This deletes \(pendingAllocationCount) allocation\(pendingAllocationCount == 1 ? "" : "s"). \(releasedAmount.tenge) will become Unallocated.")
        }
    }
}

#Preview("Plan sections · delete with allocations") {
    NavigationStack { PlanGroupsView(model: PlanViewModel()) }.tint(.green)
}
