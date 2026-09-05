import SwiftUI

struct PlanView: View {
    @State private var model: PlanViewModel
    @State private var editing: PlanAllocation?
    @State private var deleting: PlanAllocation?
    @State private var editingIncome = false
    @State private var addingAllocation = false
    let categories: [CategoryItem]

    init(store: (any PlanStore)? = nil, initialPlan: MonthlyPlan? = nil,
         categories: [CategoryItem] = []) {
        self.categories = categories
        _model = State(initialValue: PlanViewModel(store: store, initialPlan: initialPlan))
    }

    var body: some View {
        Group {
            if !model.hasLoaded {
                ProgressView("Loading your plan…")
            } else if !model.hasPlan {
                ContentUnavailableView {
                    Label("No plan for \(model.month.title)", systemImage: "chart.pie")
                } description: {
                    Text("Create a clean monthly plan with customizable sections. No sample amounts will be saved.")
                } actions: {
                    Button("Create Monthly Plan") { Task { await model.createPlan() } }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.isSaving)
                }
            } else {
                plan
            }
        }
        .task { await model.load() }
        .alert("Plan", isPresented: Binding(get: { model.errorMessage != nil },
              set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }

    private var plan: some View {
        PlanOverviewView(monthTitle: model.month.title,
                         income: model.income, incomeSourceCount: model.incomeSources.count,
                         groups: model.groups, allocations: model.allocations,
                         onEdit: { editing = $0 }, onDelete: { deleting = $0 },
                         onEditIncome: { editingIncome = true },
                         onAddAllocation: { addingAllocation = true })
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink { PlanGroupsView(model: model) } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3.weight(.semibold)).frame(minWidth: 44, minHeight: 44)
                }.accessibilityLabel("Customize Plan Sections")
            }
        }
        .sheet(item: $editing) { allocation in
            PlanAllocationEditorView(
                allocation: allocation, groups: model.groups, income: model.income,
                otherAllocated: model.allocated - allocation.rule.amount(income: model.income)
            ) { rule, groupID in
                await model.updateAllocation(id: allocation.id, rule: rule, groupID: groupID)
            } onDelete: { await model.deleteAllocation(id: allocation.id) }
        }
        .sheet(isPresented: $editingIncome) {
            NavigationStack { PlannedIncomeSourcesView(model: model) }
        }
        .sheet(isPresented: $addingAllocation) {
            PlanAllocationCreatorView(groups: model.groups, categories: categories,
                                      income: model.income, onSave: model.addAllocation)
        }
        .confirmationDialog("Delete \(deleting?.name ?? "allocation")?", isPresented: Binding(
            get: { deleting != nil }, set: { if !$0 { deleting = nil } }
        ), titleVisibility: .visible) {
            if let deleting {
                Button("Delete Allocation", role: .destructive) {
                    Task { await model.deleteAllocation(id: deleting.id); self.deleting = nil }
                }
            }
            Button("Cancel", role: .cancel) { deleting = nil }
        } message: {
            Text("The planned amount will return to Unallocated. No transaction will be deleted.")
        }
    }
}

#Preview("Plan · persisted UI with sample fixture") {
    NavigationStack { PlanView(initialPlan: PlanPreviewData.plan) }.tint(.green)
}

#Preview("Plan · no monthly plan yet") {
    NavigationStack { PlanView(store: PreviewPlanStore()) }.tint(.green)
}
