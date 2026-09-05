import SwiftUI

struct PlanGroupEditorView: View {
    let group: PlanGroup?
    let onSave: (PlanGroupDraft, UUID?) async -> String?
    @Environment(\.dismiss) private var dismiss
    @State private var draft: PlanGroupDraft
    @State private var errorMessage: String?
    @State private var isSaving = false

    init(group: PlanGroup? = nil, onSave: @escaping (PlanGroupDraft, UUID?) async -> String?) {
        self.group = group
        self.onSave = onSave
        _draft = State(initialValue: group.map(PlanGroupDraft.init) ?? PlanGroupDraft())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Section details") {
                    TextField("Name", text: $draft.name)
                    TextField("Short description (optional)", text: $draft.subtitle)
                }
                Section("Icon") { PlanGroupIconPicker(selection: $draft.symbol, tint: draft.color.tint) }
                Section("Color") { ThemeColorPicker(selection: $draft.color) }
                Section("Preview") {
                    Label(draft.trimmedName.isEmpty ? "Your section" : draft.trimmedName,
                          systemImage: draft.symbol)
                        .font(.headline).foregroundStyle(draft.color.tint)
                    if !draft.trimmedSubtitle.isEmpty {
                        Text(draft.trimmedSubtitle).font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let errorMessage {
                    Section { Text(errorMessage)
                        .foregroundStyle(.red) }
                }
                Section { Text("This section belongs to the selected monthly plan.")
                    .font(.footnote).foregroundStyle(.secondary) }
            }
            .navigationTitle(group == nil ? "New Section" : "Edit Section")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") { Task { await save() } }
                        .disabled(isSaving)
                }
            }
        }
        .interactiveDismissDisabled(isSaving)
        .tint(.green)
    }

    private func save() async {
        guard !isSaving else { return }
        isSaving = true; defer { isSaving = false }
        if let message = await onSave(draft, group?.id) { errorMessage = message }
        else { dismiss() }
    }
}

#Preview("New Plan section · editable") { PlanGroupEditorView { _, _ in nil } }
#Preview("Edit Plan section · sample") { PlanGroupEditorView(group: PlanPreviewData.groups[0]) { _, _ in nil } }
