import SwiftUI

/// Opens the local database once. Failure never silently replaces it with an empty store.
struct AppRootView: View {
    private let makeStore: @MainActor () throws -> SwiftDataCategoryStore
    @State private var store: SwiftDataCategoryStore?
    @State private var failedToOpen = false

    init(makeStore: @escaping @MainActor () throws -> SwiftDataCategoryStore = {
        SwiftDataCategoryStore(container: try AppDatabase.makeContainer())
    }) {
        self.makeStore = makeStore
    }

    var body: some View {
        Group {
            if let store {
                ContentView(store: store)
            } else if failedToOpen {
                ContentUnavailableView {
                    Label("Could not open local data", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text("Your data has not been reset. Try again, or restart the app. Avoid deleting the app to troubleshoot this error.")
                } actions: {
                    Button("Try Again", action: openDatabase)
                }
            } else {
                ProgressView("Opening your categories…")
            }
        }
        .task { if store == nil { openDatabase() } }
    }

    private func openDatabase() {
        do {
            store = try makeStore()
            failedToOpen = false
        } catch {
            failedToOpen = true
        }
    }
}

#Preview("App root · isolated preview store") {
    AppRootView { CategoryPreviewData.makeStore() }
}

#Preview("App root · storage unavailable") {
    AppRootView { throw CocoaError(.fileReadNoPermission) }
}
