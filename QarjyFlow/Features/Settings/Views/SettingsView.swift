import SwiftUI

struct SettingsView: View {
    let categoryStore: any CategoryStore

    var body: some View {
        List {
            Section {
                NavigationLink {
                    CategoriesView(store: categoryStore)
                } label: {
                    Label("Categories", systemImage: "tag")
                }
            } header: {
                Text("Money organization")
            } footer: {
                Text("Categories are shared by Activity and, later, persisted Plan allocations.")
            }

            Section("Current configuration") {
                LabeledContent("Currency", value: "KZT (₸)")
                LabeledContent("Data storage", value: "On this iPhone")
                LabeledContent("App cloud sync", value: "Off")
            }

            Section("About") {
                LabeledContent("App", value: "QarjyFlow")
                if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
                    LabeledContent("Version", value: version)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Settings · categories and local data") {
    NavigationStack { SettingsView(categoryStore: CategoryPreviewData.makeStore()) }
        .tint(.green)
}
