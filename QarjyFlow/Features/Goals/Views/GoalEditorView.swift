import SwiftUI

struct GoalEditorView: View {
    let goal: FinancialGoal?
    let onSave: (GoalDraft, UUID?) async -> String?
    @Environment(\.dismiss) private var dismiss
    @State private var draft: GoalDraft
    @State private var errorMessage: String?
    @State private var saving = false
    @State private var amountFocused = false

    init(goal: FinancialGoal? = nil, onSave: @escaping (GoalDraft, UUID?) async -> String?) {
        self.goal = goal; self.onSave = onSave
        _draft = State(initialValue: goal.map(GoalDraft.init) ?? GoalDraft())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Goal") {
                    TextField("Name, for example S&P 500", text: $draft.name)
                    Picker("Kind", selection: $draft.kind) {
                        ForEach(GoalKind.allCases) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented)
                    if draft.kind == .target {
                        LabeledContent("Target · KZT") {
                            AmountTextField(rawText: $draft.targetText, inputLabel: "Goal target amount",
                                            inputIdentifier: "goal.target", isFocused: $amountFocused)
                                .frame(minHeight: 44)
                        }.contentShape(Rectangle()).onTapGesture { amountFocused = true }
                    }
                }
                Section("Icon") { CategoryIconPicker(selection: $draft.symbol, tint: draft.color.tint) }
                Section("Color") { ThemeColorPicker(selection: $draft.color) }
                if let errorMessage { Section { Text(errorMessage).foregroundStyle(.red) } }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(goal == nil ? "New Goal" : "Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Saving…" : "Save") { Task { await save() } }.disabled(saving)
                }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { amountFocused = false } }
            }
        }.interactiveDismissDisabled(saving).tint(.green)
    }

    private func save() async {
        saving = true; defer { saving = false }
        if let message = await onSave(draft, goal?.id) { errorMessage = message }
        else { dismiss() }
    }
}

#Preview("Goal editor · target") {
    GoalEditorView { _, _ in nil }
}
