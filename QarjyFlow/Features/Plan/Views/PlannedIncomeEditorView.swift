import SwiftUI

struct PlannedIncomeEditorView: View {
    let source: PlannedIncomeSource?
    let onSave: (PlannedIncomeDraft, UUID?) -> String?
    @Environment(\.dismiss) private var dismiss
    @State private var draft: PlannedIncomeDraft
    @State private var errorMessage: String?

    init(source: PlannedIncomeSource? = nil,
         onSave: @escaping (PlannedIncomeDraft, UUID?) -> String?) {
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
                                        inputIdentifier: "plan.income.amount")
                            .frame(minHeight: 44)
                    }
                } header: {
                    Text("Expected income")
                } footer: {
                    Text("This is what you expect to receive during the month. It does not create an income transaction.")
                }
                if let errorMessage {
                    Section { Label(errorMessage, systemImage: "exclamationmark.circle")
                        .foregroundStyle(.red) }
                }
                Section { Text("Design preview only. This source resets when the app restarts.")
                    .font(.footnote).foregroundStyle(.secondary) }
            }
            .navigationTitle(source == nil ? "Add Expected Income" : "Edit Expected Income")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let message = onSave(draft, source?.id) { errorMessage = message }
                        else { dismiss() }
                    }.disabled(draft.trimmedName.isEmpty || draft.amountText.isEmpty)
                }
            }
        }.tint(.green)
    }
}

#Preview("Add expected income · another source") {
    PlannedIncomeEditorView { _, _ in nil }
}

#Preview("Edit expected income · salary") {
    PlannedIncomeEditorView(source: PlanPreviewData.incomeSources[0]) { _, _ in nil }
}
