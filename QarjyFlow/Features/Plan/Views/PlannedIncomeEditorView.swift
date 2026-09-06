import SwiftUI

struct PlannedIncomeEditorView: View {
    let source: PlannedIncomeSource?
    let onSave: (PlannedIncomeDraft, UUID?) async -> String?
    @Environment(\.dismiss) private var dismiss
    @State private var draft: PlannedIncomeDraft
    @State private var errorMessage: String?
    @State private var isSaving = false
    @State private var amountFocused = false

    init(source: PlannedIncomeSource? = nil,
         onSave: @escaping (PlannedIncomeDraft, UUID?) async -> String?) {
        self.source = source
        self.onSave = onSave
        _draft = State(initialValue: source.map(PlannedIncomeDraft.init) ?? PlannedIncomeDraft())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Source name, for example Freelance", text: $draft.name)
                        .textInputAutocapitalization(.words)
                    LabeledContent("Amount · KZT") {
                        AmountTextField(rawText: $draft.amountText,
                                        inputLabel: "Expected income amount",
                                        inputIdentifier: "plan.income.amount",
                                        isFocused: $amountFocused)
                            .frame(minHeight: 44)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { amountFocused = true }
                } header: {
                    Text("Expected income")
                } footer: {
                    Text("This is what you expect to receive during the month. It does not create an income transaction.")
                }
                if let errorMessage {
                    Section { Label(errorMessage, systemImage: "exclamationmark.circle")
                        .foregroundStyle(.red) }
                }
                Section { Text("This source belongs to the selected monthly plan.")
                    .font(.footnote).foregroundStyle(.secondary) }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(source == nil ? "Add Expected Income" : "Edit Expected Income")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") { Task { await save() } }
                        .disabled(isSaving || draft.trimmedName.isEmpty || draft.amountText.isEmpty)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer(); Button("Done") { amountFocused = false }
                }
            }
        }.interactiveDismissDisabled(isSaving).tint(.green)
    }

    private func save() async {
        guard !isSaving else { return }
        isSaving = true; defer { isSaving = false }
        if let message = await onSave(draft, source?.id) { errorMessage = message }
        else { dismiss() }
    }
}

#Preview("Add expected income · another source") {
    PlannedIncomeEditorView { _, _ in nil }
}

#Preview("Edit expected income · salary") {
    PlannedIncomeEditorView(source: PlanPreviewData.incomeSources[0]) { _, _ in nil }
}
