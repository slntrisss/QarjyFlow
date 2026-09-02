import SwiftUI

/// Temporary entry point for reviewing the design without creating real budgets.
struct PlanPreviewView: View {
    @State private var model = PlanPreviewViewModel()
    @State private var editing: PlanAllocation?
    @State private var deleting: PlanAllocation?
    @State private var editingIncome = false

    var body: some View {
        PlanOverviewView(income: model.income, incomeSourceCount: model.incomeSources.count,
                         groups: model.groups, allocations: model.allocations,
                         onEdit: { editing = $0 }, onDelete: { deleting = $0 },
                         onEditIncome: { editingIncome = true })
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    PlanGroupsView(model: model)
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3.weight(.semibold)).frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Customize Plan Sections")
            }
        }
        .sheet(item: $editing) { allocation in
            PlanAllocationEditorView(
                allocation: allocation, groups: model.groups, income: model.income,
                otherAllocated: model.allocated - allocation.rule.amount(income: model.income)
            ) { rule, groupID in
                model.updateAllocation(id: allocation.id, rule: rule, groupID: groupID)
            } onDelete: { model.deleteAllocation(id: allocation.id) }
        }
        .sheet(isPresented: $editingIncome) {
            NavigationStack { PlannedIncomeSourcesView(model: model) }
        }
        .confirmationDialog("Delete \(deleting?.name ?? "allocation")?", isPresented: Binding(
            get: { deleting != nil }, set: { if !$0 { deleting = nil } }
        ), titleVisibility: .visible) {
            if let deleting {
                Button("Delete Allocation", role: .destructive) {
                    model.deleteAllocation(id: deleting.id)
                    self.deleting = nil
                }
            }
            Button("Cancel", role: .cancel) { deleting = nil }
        } message: {
            Text("The planned amount will return to Unallocated. No transaction will be deleted.")
        }
    }
}

#Preview("Plan · interactive customizable sample") {
    NavigationStack { PlanPreviewView() }.tint(.green)
}
