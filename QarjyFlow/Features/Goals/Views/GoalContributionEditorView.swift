import SwiftUI

struct GoalContributionEditorView: View {
    let goal: FinancialGoal
    let onSave: (UUID, String, Date, String) async -> String?
    @Environment(\.dismiss) private var dismiss
    @State private var amountText = ""
    @State private var date = Date()
    @State private var note = ""
    @State private var focused = false
    @State private var saving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Contribution to \(goal.name)") {
                    LabeledContent("Amount · KZT") {
                        AmountTextField(rawText: $amountText, inputLabel: "Contribution amount",
                                        inputIdentifier: "goal.contribution", isFocused: $focused)
                            .frame(minHeight: 44)
                    }.contentShape(Rectangle()).onTapGesture { focused = true }
                    DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                    TextField("Note (optional)", text: $note)
                }
                Section { Text("Record this only after you actually save or invest the money.")
                    .font(.footnote).foregroundStyle(.secondary) }
                if let errorMessage { Section { Text(errorMessage).foregroundStyle(.red) } }
            }.scrollDismissesKeyboard(.interactively)
            .navigationTitle("Add Contribution").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Saving…" : "Save") { Task { await save() } }
                        .disabled(saving || amountText.isEmpty)
                }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focused = false } }
            }
        }.interactiveDismissDisabled(saving).tint(.green)
    }

    private func save() async {
        saving = true; defer { saving = false }
        if let message = await onSave(goal.id, amountText, date, note) { errorMessage = message }
        else { dismiss() }
    }
}

#Preview("Goal contribution") {
    GoalContributionEditorView(
        goal: FinancialGoal(id: UUID(), name: "S&P 500", kind: .ongoing,
                            targetAmount: nil, symbol: "chart.line.uptrend.xyaxis", color: .blue)
    ) { _, _, _, _ in nil }
}
