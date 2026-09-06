import SwiftUI

struct GoalsView: View {
    @Bindable var model: GoalsViewModel
    @State private var adding = false
    @State private var editing: FinancialGoal?
    @State private var contributing: FinancialGoal?
    @State private var deleting: FinancialGoal?

    var body: some View {
        List {
            if model.goals.isEmpty && !model.isLoading {
                ContentUnavailableView("No goals yet", systemImage: "target",
                                       description: Text("Create an ongoing investment or a target amount."))
            }
            ForEach(model.goals) { goal in
                let saved = model.total(for: goal.id)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label(goal.name, systemImage: goal.symbol).font(.headline).foregroundStyle(goal.color.tint)
                        Spacer()
                    }
                    if let target = goal.targetAmount {
                        LabeledContent("Saved", value: saved.tenge)
                        LabeledContent("Target", value: target.tenge)
                        ProgressView(value: min(NSDecimalNumber(decimal: saved / target).doubleValue, 1))
                            .tint(goal.color.tint)
                        LabeledContent(saved >= target ? "Above target" : "Remaining",
                                       value: abs(target - saved).tenge)
                    } else {
                        LabeledContent("Total contributed", value: saved.tenge)
                        Text("Ongoing goal · no final target").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
                .onTapGesture { contributing = goal }
                .accessibilityAction(named: "Contribute") { contributing = goal }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button("Delete", systemImage: "trash", role: .destructive) { deleting = goal }
                        .tint(.red)
                    Button("Edit", systemImage: "pencil") { editing = goal }
                        .tint(.blue)
                }
            }
        }
        .navigationTitle("Goals")
        .toolbar { ToolbarItem(placement: .primaryAction) {
            Button("Add Goal", systemImage: "plus") { adding = true }
        } }
        .task { await model.load() }
        .sheet(isPresented: $adding) { GoalEditorView(onSave: model.save) }
        .sheet(item: $editing) { GoalEditorView(goal: $0, onSave: model.save) }
        .sheet(item: $contributing) { GoalContributionEditorView(goal: $0, onSave: model.contribute) }
        .confirmationDialog("Delete \(deleting?.name ?? "goal")?", isPresented: Binding(
            get: { deleting != nil }, set: { if !$0 { deleting = nil } }
        ), titleVisibility: .visible) {
            if let deleting {
                Button("Delete Goal", role: .destructive) {
                    Task { await model.delete(deleting); self.deleting = nil }
                }
            }
            Button("Cancel", role: .cancel) { deleting = nil }
        } message: {
            Text("Its contribution history will also be deleted. A goal linked to a monthly plan must be removed from that plan first.")
        }
        .alert("Goals", isPresented: Binding(get: { model.errorMessage != nil },
              set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }
}

#Preview("Goals · empty") {
    NavigationStack { GoalsView(model: GoalsViewModel(store: PreviewGoalStore())) }
}
