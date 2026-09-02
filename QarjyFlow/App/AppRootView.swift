import SwiftUI

/// Opens the local database once. Failure never silently replaces it with an empty store.
struct AppRootView: View {
    private let makeStore: @MainActor () async throws -> AppStores
    @State private var store: AppStores?
    @State private var failedToOpen = false

    init(makeStore: @escaping @MainActor () async throws -> AppStores = {
        try await AppStores.live()
    }) {
        self.makeStore = makeStore
    }

    var body: some View {
        Group {
            if let store {
                ContentView(stores: store)
            } else if failedToOpen {
                ContentUnavailableView {
                    Label("Could not open local data", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text("Your data has not been reset. Try again, or restart the app. Avoid deleting the app to troubleshoot this error.")
                } actions: {
                    Button("Try Again") { Task { await openDatabase() } }
                }
            } else {
                ProgressView("Opening your data…")
            }
        }
        .task { if store == nil { await openDatabase() } }
    }

    private func openDatabase() async {
        failedToOpen = false
        do {
            store = try await makeStore()
            failedToOpen = false
        } catch {
            failedToOpen = true
        }
    }
}

#Preview("App root · isolated preview store") {
    AppRootView { TransactionPreviewData.stores() }
}

#Preview("App root · storage unavailable") {
    AppRootView { throw CocoaError(.fileReadNoPermission) }
}
