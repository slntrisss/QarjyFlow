import Foundation

/// Immutable presentation value. SwiftData objects stay inside the store.
struct CategoryItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let kind: CategoryKind
    let symbol: String
    let color: ThemeColor
    let isArchived: Bool
}
