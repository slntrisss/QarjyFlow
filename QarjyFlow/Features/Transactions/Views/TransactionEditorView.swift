import SwiftUI

@MainActor
struct TransactionEditorView: View {
    let categories: [CategoryItem]
    let categoryStore: any CategoryStore
    let onCategoriesChanged: () -> Void
    private let transaction: TransactionItem?
    private let onSave: @MainActor (TransactionDraft, UUID?) async throws -> Void
    @State private var draft: TransactionDraft
    @State private var errorMessage: String?
    @State private var isSaving = false
    @Environment(\.dismiss) private var dismiss

    init(
        transaction: TransactionItem? = nil, categories: [CategoryItem],
        categoryStore: any CategoryStore,
        onCategoriesChanged: @escaping () -> Void,
        onSave: @escaping @MainActor (TransactionDraft, UUID?) async throws -> Void
    ) {
        self.transaction = transaction
        self.categories = categories
        self.categoryStore = categoryStore
        self.onCategoriesChanged = onCategoriesChanged
        self.onSave = onSave
        if let transaction {
            _draft = State(initialValue: TransactionDraft(transaction: transaction))
        } else {
            _draft = State(initialValue: TransactionDraft())
        }
    }

    private var availableCategories: [CategoryItem] {
        categories.filter {
            $0.kind == draft.kind && (!$0.isArchived || $0.id == transaction?.categoryID)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $draft.kind) {
                        ForEach(CategoryKind.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    LabeledContent("Amount · KZT") {
                        AmountTextField(rawText: $draft.amountText)
                            .frame(minHeight: 44)
                    }
                    .font(.title3)
                } footer: {
                    Text("Spaces are added automatically: 1000 becomes 1 000. Use a dot or comma for up to two decimal places.")
                }
                Section("Category") {
                    if availableCategories.isEmpty {
                        Text("Create an \(draft.kind.title.lowercased()) category before saving this transaction.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Category", selection: $draft.categoryID) {
                            Text("Choose a category").tag(nil as UUID?)
                            ForEach(availableCategories) { category in
                                Label(category.name + (category.isArchived ? " (archived)" : ""), systemImage: category.symbol)
                                    .tag(Optional(category.id))
                            }
                        }
                    }
                    NavigationLink {
                        CategoriesView(store: categoryStore)
                            .onDisappear(perform: onCategoriesChanged)
                    } label: {
                        Label("Manage Categories", systemImage: "tag")
                    }
                }
                Section("Details") {
                    DatePicker("Date", selection: $draft.date, in: ...Date(), displayedComponents: .date)
                    TextField("Merchant or source (optional)", text: $draft.merchant)
                    TextField("Note (optional)", text: $draft.note, axis: .vertical)
                        .lineLimit(3...5)
                }
                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.circle")
                            .foregroundStyle(.red)
                    }
                }
                Section {
                    Text("Transfers between your own accounts are not income or expenses. Transfer and investment entry will be added separately.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle(transaction == nil ? "Add Transaction" : "Edit Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: draft.kind) { _, _ in draft.categoryID = nil }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") { Task { await save() } }
                        .disabled(draft.categoryID == nil || draft.amountText.isEmpty)
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
            try await onSave(draft, transaction?.id)
            dismiss()
        } catch let error as TransactionError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Could not save. Your edits are still here; please try again."
        }
    }
}

#Preview("Add transaction · categories ready") {
    let model = TransactionPreviewData.model()
    TransactionEditorView(categories: model.categories, categoryStore: CategoryPreviewData.makeStore(),
                          onCategoriesChanged: {}, onSave: model.save)
}

#Preview("Add transaction · no categories") {
    TransactionEditorView(categories: [], categoryStore: CategoryPreviewData.makeStore(seed: false),
                          onCategoriesChanged: {}) { _, _ in }
}
