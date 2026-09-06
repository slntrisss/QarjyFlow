import SwiftUI

struct PlanAllocationEditorView: View {
    let allocation: PlanAllocation
    let groups: [PlanGroup]
    let income: Decimal
    let otherAllocated: Decimal
    let onApply: (PlanAllocationRule, UUID) async -> Void
    let onDelete: () async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedGroupID: UUID
    @State private var usePercentage: Bool
    @State private var amountText: String
    @State private var percentText: String
    @State private var confirmingDeletion = false
    @State private var isSaving = false
    @State private var valueFocused = false

    init(allocation: PlanAllocation, groups: [PlanGroup], income: Decimal, otherAllocated: Decimal,
         onApply: @escaping (PlanAllocationRule, UUID) async -> Void,
         onDelete: @escaping () async -> Void) {
        self.allocation = allocation; self.groups = groups; self.income = income
        self.otherAllocated = otherAllocated; self.onApply = onApply; self.onDelete = onDelete
        _selectedGroupID = State(initialValue: allocation.groupID)
        switch allocation.rule {
        case .fixed(let value):
            _usePercentage = State(initialValue: false)
            _amountText = State(initialValue: NSDecimalNumber(decimal: value).stringValue)
            _percentText = State(initialValue: "")
        case .percentage(let value):
            _usePercentage = State(initialValue: true)
            _percentText = State(initialValue: NSDecimalNumber(decimal: value).stringValue)
            _amountText = State(initialValue: NSDecimalNumber(decimal: allocation.rule.amount(income: income)).stringValue)
        }
    }

    private var rule: PlanAllocationRule? {
        guard let minor = AmountInputParsing.positiveMinorUnits(usePercentage ? percentText : amountText) else { return nil }
        let value = Decimal(minor) / 100
        if usePercentage { return value <= 100 ? .percentage(value) : nil }
        return .fixed(value)
    }
    private var selectedGroup: PlanGroup? { groups.first { $0.id == selectedGroupID } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label(allocation.name, systemImage: allocation.symbol)
                        .font(.title3.weight(.semibold)).foregroundStyle(selectedGroup?.tint ?? .green)
                    Picker("Plan section", selection: $selectedGroupID) {
                        ForEach(groups) { Label($0.name, systemImage: $0.symbol).tag($0.id) }
                    }
                }
                Section("Allocate by") {
                    Picker("Allocation mode", selection: $usePercentage) {
                        Text("Fixed amount").tag(false); Text("Percentage").tag(true)
                    }.pickerStyle(.segmented)
                    if usePercentage {
                        LabeledContent("Percent") {
                            PercentageInputField(text: $percentText, isFocused: $valueFocused,
                                                 identifier: "plan.percentage")
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { valueFocused = true }
                    } else {
                        LabeledContent("Amount · KZT") {
                            AmountTextField(rawText: $amountText, inputIdentifier: "plan.amount",
                                            isFocused: $valueFocused).frame(minHeight: 44)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { valueFocused = true }
                    }
                    Text(usePercentage
                         ? "Based on expected income of \(income.tenge), not recorded income. Enter more than 0 and up to 100%."
                         : "This amount stays fixed when expected income changes.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Result in this sample") {
                    if let rule {
                        LabeledContent("Planned", value: rule.amount(income: income).tenge)
                        let remaining = income - otherAllocated - rule.amount(income: income)
                        LabeledContent(remaining < 0 ? "Over-allocated" : "Left unallocated", value: abs(remaining).tenge)
                            .foregroundStyle(remaining < 0 ? .red : .green)
                        if remaining < 0 { Text("This preview allows over-allocation with a warning.")
                            .font(.footnote).foregroundStyle(.secondary) }
                    } else { Text("Enter a valid positive value with up to two decimal places.")
                        .font(.footnote).foregroundStyle(.secondary) }
                }
                Section { Text("Changes are saved to this monthly plan. They do not create or modify Activity transactions.")
                    .font(.footnote).foregroundStyle(.secondary) }
                Section {
                    Button("Delete Allocation", systemImage: "trash", role: .destructive) {
                        confirmingDeletion = true
                    }
                } footer: {
                    Text("Deleting returns this planned amount to Unallocated and does not delete any Activity transaction.")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Edit Allocation").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") { Task { await apply() } }
                        .disabled(isSaving || rule == nil || selectedGroup == nil)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer(); Button("Done") { valueFocused = false }
                }
            }
        }
        .confirmationDialog("Delete \(allocation.name)?", isPresented: $confirmingDeletion,
                            titleVisibility: .visible) {
            Button("Delete Allocation", role: .destructive) {
                Task { isSaving = true; await onDelete(); dismiss() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(allocation.rule.amount(income: income).tenge) will become Unallocated.")
        }
        .interactiveDismissDisabled(isSaving)
        .tint(.green)
    }

    private func apply() async {
        guard !isSaving, let rule else { return }
        isSaving = true; defer { isSaving = false }
        await onApply(rule, selectedGroupID)
        dismiss()
    }
}

#Preview("Allocation editor · move between sections") {
    PlanAllocationEditorView(allocation: PlanPreviewData.allocations[0], groups: PlanPreviewData.groups,
                             income: 800_000, otherAllocated: 520_000,
                             onApply: { _, _ in }, onDelete: {})
}
