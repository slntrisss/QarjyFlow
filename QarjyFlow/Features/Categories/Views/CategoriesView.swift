import SwiftUI

struct CategoriesView: View {
    @State private var model: CategoriesViewModel
    @State private var isAdding = false
    @State private var editing: CategoryItem?
    @State private var deleting: CategoryItem?

    private var suggestedColor: ThemeColor {
        let palette = ThemeColor.allCases
        return palette[model.categories.count % palette.count]
    }

    init(store: any CategoryStore) {
        _model = State(initialValue: CategoriesViewModel(store: store))
    }

    var body: some View {
        List {
            if model.isLoading && !model.hasLoaded {
                ProgressView("Loading categories…")
            } else if !model.hasLoaded {
                ContentUnavailableView {
                    Label("Categories unavailable", systemImage: "tag")
                } description: {
                    Text("Load your saved categories before making changes.")
                } actions: {
                    Button("Reload") { Task { await model.load() } }
                }
            }
            if model.hasLoaded && model.visibleCategories.isEmpty {
                ContentUnavailableView {
                    Label(model.searchText.isEmpty ? "No categories yet" : "No matching categories", systemImage: "tag")
                } description: {
                    Text("Create categories that fit your life. They are saved on this iPhone.")
                } actions: {
                    Button("Add Category") { isAdding = true }
                }
            }
            ForEach(CategoryKind.allCases) { kind in
                let items = model.visibleCategories.filter { $0.kind == kind }
                if !items.isEmpty {
                    Section("\(kind.title) Categories") {
                        ForEach(items) { category in
                            Button { editing = category } label: {
                                CategoryRow(category: category)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Delete", role: .destructive) { deleting = category }
                                    .tint(.red)
                            }
                            .contextMenu {
                                Button("Edit", systemImage: "pencil") { editing = category }
                                Button("Delete", systemImage: "trash", role: .destructive) { deleting = category }
                            }
                        }
                    }
                }
            }
            Section {
                Label("Stored locally. No bank connection or app cloud sync.", systemImage: "iphone")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Categories")
        .disabled(model.isMutating)
        .searchable(text: $model.searchText, prompt: "Find a category")
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { isAdding = true } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                    .disabled(!model.hasLoaded)
                    .accessibilityLabel("Add Category")
                    .accessibilityIdentifier("categories.add")
            }
        }
        .task { await model.load() }
        .refreshable { await model.load() }
        .sheet(isPresented: $isAdding) {
            CategoryEditorView(suggestedColor: suggestedColor, onSave: model.save)
        }
        .sheet(item: $editing) { category in
            CategoryEditorView(category: category, onSave: model.save)
        }
        .confirmationDialog("Delete category?", isPresented: Binding(
            get: { deleting != nil }, set: { if !$0 { deleting = nil } }
        ), titleVisibility: .visible) {
            if let deleting {
                Button("Delete \(deleting.name)", role: .destructive) { Task { await model.delete(deleting) } }
            }
            Button("Cancel", role: .cancel) { deleting = nil }
        } message: {
            Text("This permanently removes the category. Categories used by Activity or Plan cannot be deleted.")
        }
        .alert("Categories", isPresented: Binding(
            get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("Reload List") { Task { await model.load() } }
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}

#Preview("Categories · saved samples") {
    NavigationStack { CategoriesView(store: CategoryPreviewData.makeStore()) }
        .tint(.green)
}

#Preview("Categories · empty") {
    NavigationStack { CategoriesView(store: CategoryPreviewData.makeStore(seed: false)) }
        .tint(.green)
}
