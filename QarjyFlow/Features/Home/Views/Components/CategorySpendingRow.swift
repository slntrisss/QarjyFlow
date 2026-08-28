import SwiftUI

struct CategorySpendingRow: View {
    let category: CategorySnapshot

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.symbol).foregroundStyle(.green).frame(width: 28)
            Text(category.name)
            Spacer()
            Text(category.spent.tenge).fontWeight(.medium)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
        }
        .font(.subheadline).foregroundStyle(.primary)
        .padding(.vertical, 8).contentShape(Rectangle())
    }
}

#Preview("Category row · food", traits: .sizeThatFitsLayout) {
    CategorySpendingRow(category: .demoFood)
        .padding(20)
}
