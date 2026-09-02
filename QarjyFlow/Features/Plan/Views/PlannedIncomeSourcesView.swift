import SwiftUI

struct PlannedIncomeSourcesView: View {
    @Bindable var model: PlanPreviewViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isAdding = false
    @State private var editing: PlannedIncomeSource?
    @State private var deleting: PlannedIncomeSource?

    var body: some View {
        List {
            Section {
                LabeledContent("Expected monthly income") {
                    Text(model.income.tenge).font(.headline).foregroundStyle(.green)
                }
            } footer: {
                Text("Percentage allocations recalculate from this total. Fixed allocations do not change.")
            }
            if model.incomeSources.isEmpty {
                ContentUnavailableView {
                    Label("No expected income", systemImage: "banknote")
                } description: {
                    Text("Add salary, freelance work, rental income, or another source you expect this month.")
                } actions: {
                    Button("Add Income Source") { isAdding = true }
                }
            }
            Section("Sources") {
                ForEach(model.incomeSources) { source in
                    Button { editing = source } label: {
                        HStack {
                            Image(systemName: "arrow.down.left.circle.fill").foregroundStyle(.green)
                            Text(source.name).foregroundStyle(.primary)
                            Spacer()
                            Text(source.amount.tenge).fontWeight(.semibold).foregroundStyle(.primary)
                            Image(systemName: "chevron.right").font(.caption2.bold()).foregroundStyle(.tertiary)
                        }.frame(minHeight: 44)
                    }
                    .swipeActions(allowsFullSwipe: false) {
                        Button("Delete", role: .destructive) { deleting = source }
                    }
                    .contextMenu {
                        Button("Edit", systemImage: "pencil") { editing = source }
                        Button("Delete", systemImage: "trash", role: .destructive) { deleting = source }
                    }
                }
            }
            Section { Text("Expected income is planning data. Record money actually received in Activity.")
                .font(.footnote).foregroundStyle(.secondary) }
        }
        .navigationTitle("Expected Income")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            ToolbarItem(placement: .primaryAction) {
                Button { isAdding = true } label: {
                    Image(systemName: "plus").font(.title2.weight(.semibold)).frame(minWidth: 44, minHeight: 44)
                }.accessibilityLabel("Add Expected Income")
            }
        }
        .sheet(isPresented: $isAdding) { PlannedIncomeEditorView(onSave: model.saveIncome) }
        .sheet(item: $editing) { PlannedIncomeEditorView(source: $0, onSave: model.saveIncome) }
        .confirmationDialog("Delete \(deleting?.name ?? "income source")?", isPresented: Binding(
            get: { deleting != nil }, set: { if !$0 { deleting = nil } }
        ), titleVisibility: .visible) {
            if let deleting {
                Button("Delete Income Source", role: .destructive) {
                    model.deleteIncome(id: deleting.id)
                    self.deleting = nil
                }
            }
            Button("Cancel", role: .cancel) { deleting = nil }
        } message: {
            Text("Expected income will decrease and percentage allocations will recalculate. No Activity transaction will be deleted.")
        }
    }
}

#Preview("Expected income · multiple editable sources") {
    NavigationStack { PlannedIncomeSourcesView(model: PlanPreviewViewModel()) }.tint(.green)
}
