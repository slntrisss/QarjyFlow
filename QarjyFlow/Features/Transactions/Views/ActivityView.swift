import SwiftUI

struct ActivityView: View {
    @Bindable var model: TransactionsViewModel
    let categoryStore: any CategoryStore
    @State private var adding = false
    @State private var editing: TransactionItem?
    @State private var deleting: TransactionItem?
    @State private var preparingToAdd = false

    var body: some View {
        List {
            if model.loadFailed {
                Label("Could not refresh transactions. Try reloading.", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Button("Reload") { Task { await model.load() } }
            } else if !model.hasLoaded {
                ProgressView("Loading transactions…")
            }
            Picker("Transaction type", selection: $model.filter) {
                Text("All").tag(nil as CategoryKind?)
                Text("Income").tag(Optional(CategoryKind.income))
                Text("Expense").tag(Optional(CategoryKind.expense))
            }
            .pickerStyle(.segmented)
            if model.hasLoaded && model.visibleTransactions.isEmpty {
                ContentUnavailableView {
                    Label("No transactions", systemImage: "list.bullet.rectangle")
                } description: {
                    Text("Record your first income or expense, or adjust your filters.")
                } actions: {
                    Button("Add Transaction") { prepareToAdd() }
                }
            }
            ForEach(model.visibleTransactions) { item in
                Button { editing = item } label: {
                    TransactionRow(transaction: item, category: model.category(for: item))
                }
                .swipeActions(allowsFullSwipe: false) {
                    Button("Delete", role: .destructive) { deleting = item }
                        .tint(.red)
                }
                .contextMenu {
                    Button("Edit", systemImage: "pencil") { editing = item }
                    Button("Delete", systemImage: "trash", role: .destructive) { deleting = item }
                }
            }
        }
        .navigationTitle("Activity")
        .disabled(model.isMutating || preparingToAdd)
        .searchable(text: $model.searchText, prompt: "Category, merchant, or note")
        .refreshable { await model.load() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: prepareToAdd) {
                    Image(systemName: "plus").font(.title2.weight(.semibold))
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Add Transaction")
            }
        }
        .sheet(isPresented: $adding) {
            TransactionEditorView(categories: model.categories, categoryStore: categoryStore,
                                  onCategoriesChanged: reloadCategories, onSave: model.save)
        }
        .sheet(item: $editing) { item in
            TransactionEditorView(transaction: item, categories: model.categories, categoryStore: categoryStore,
                                  onCategoriesChanged: reloadCategories, onSave: model.save)
        }
        .confirmationDialog("Delete transaction?", isPresented: Binding(
            get: { deleting != nil }, set: { if !$0 { deleting = nil } }
        ), titleVisibility: .visible) {
            if let deleting {
                Button("Delete permanently", role: .destructive) { Task { await model.delete(deleting) } }
            }
            Button("Cancel", role: .cancel) { deleting = nil }
        } message: {
            Text("This removes the transaction and updates your recorded totals.")
        }
    }

    private func reloadCategories() {
        Task { await model.load() }
    }

    private func prepareToAdd() {
        guard !preparingToAdd else { return }
        preparingToAdd = true
        Task {
            defer { preparingToAdd = false }
            await model.load()
            if model.hasLoaded && model.errorMessage == nil { adding = true }
        }
    }
}

#Preview("Activity · local transactions") {
    NavigationStack { ActivityView(model: TransactionPreviewData.model(), categoryStore: CategoryPreviewData.makeStore()) }
        .tint(.green)
}

#Preview("Activity · empty") {
    NavigationStack { ActivityView(model: TransactionPreviewData.model(seed: false), categoryStore: CategoryPreviewData.makeStore(seed: false)) }
        .tint(.green)
}
