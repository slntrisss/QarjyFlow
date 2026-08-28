import SwiftUI

struct CategoryRow: View {
    let category: CategoryItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.symbol)
                .foregroundStyle(category.color.tint)
                .frame(width: 36, height: 36)
                .background(category.color.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(category.name).foregroundStyle(.primary)
                Text(category.isArchived ? "Archived · \(category.kind.title)" : category.kind.title)
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

#Preview("Category · custom label", traits: .sizeThatFitsLayout) {
    CategoryRow(category: CategoryPreviewData.food).padding()
}
