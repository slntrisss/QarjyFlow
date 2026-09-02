import SwiftUI

@MainActor
struct CategoryEditorView: View {
    private let category: CategoryItem?
    private let onSave: @MainActor (CategoryDraft, UUID?) async throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var draft: CategoryDraft
    @State private var errorMessage: String?
    @State private var isSaving = false

    init(category: CategoryItem? = nil, onSave: @escaping @MainActor (CategoryDraft, UUID?) async throws -> Void) {
        self.category = category
        self.onSave = onSave
        // Keep initialization on the main actor instead of passing an isolated
        // initializer as a function reference to Optional.map.
        if let category {
            _draft = State(initialValue: CategoryDraft(category: category))
        } else {
            _draft = State(initialValue: CategoryDraft())
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Category name", text: $draft.name)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("category.name")
                    Picker("Type", selection: $draft.kind) {
                        ForEach(CategoryKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                }
                Section("Icon") {
                    CategoryIconPicker(selection: $draft.symbol, tint: draft.color.tint)
                }
                Section("Color") {
                    ThemeColorPicker(selection: $draft.color)
                }
                Section("Preview") {
                    CategoryRow(category: CategoryItem(
                        id: category?.id ?? UUID(),
                        name: draft.trimmedName.isEmpty ? "Your category" : draft.trimmedName,
                        kind: draft.kind, symbol: draft.symbol, color: draft.color,
                        isArchived: category?.isArchived ?? false
                    ))
                }
                Section {
                    Text("A category labels transactions; it does not hold a balance. Record actual amounts in Activity. Monthly budget planning will be added separately.")
                    Text("Moving money to your own savings or investment account is a transfer, not an expense. Transfer entry is not available yet.")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.circle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(category == nil ? "New Category" : "Edit Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") { Task { await save() } }
                        .disabled(draft.trimmedName.isEmpty)
                        .accessibilityIdentifier("category.save")
                }
            }
        }
        .disabled(isSaving)
        .interactiveDismissDisabled(isSaving)
        .tint(.green)
    }

    private func save() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await onSave(draft, category?.id)
            dismiss()
        } catch let error as CategoryError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Could not save this category. Your edits are still here; please try again."
        }
    }

}

#Preview("New category · editable") {
    CategoryEditorView { draft, id in
        _ = try CategoryPreviewData.makeStore().save(draft, id: id)
    }
}

#Preview("Edit category · sample") {
    CategoryEditorView(category: CategoryPreviewData.food) { draft, _ in
        try draft.validate()
    }
}
