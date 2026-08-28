import SwiftUI

struct CategoryIconPicker: View {
    @Binding var selection: String
    let tint: Color

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 12)], spacing: 12) {
            ForEach(CategoryDraft.symbols, id: \.self) { symbol in
                Button {
                    selection = symbol
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: symbol)
                            .font(.system(size: 28))
                            .foregroundStyle(tint)
                            .frame(height: 32)
                        Text(iconName(symbol))
                            .font(.caption)
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 72)
                    .padding(6)
                    .background(tint.opacity(selection == symbol ? 0.14 : 0.04), in: RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(selection == symbol ? tint : .clear, lineWidth: 2)
                    }
                    .overlay(alignment: .topTrailing) {
                        if selection == symbol {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(tint)
                                .padding(4)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(iconName(symbol))
                .accessibilityAddTraits(selection == symbol ? .isSelected : [])
                .accessibilityIdentifier("category.icon.\(symbol)")
            }
        }
        .padding(.vertical, 4)
    }

    private func iconName(_ symbol: String) -> String {
        switch symbol {
        case "house.fill": "Home"
        case "fork.knife": "Food"
        case "bus.fill": "Transport"
        case "bag.fill": "Shopping"
        case "play.tv.fill": "Entertainment"
        case "heart.fill": "Health"
        case "book.fill": "Education"
        case "airplane": "Travel"
        case "gift.fill": "Gifts"
        case "briefcase.fill": "Work"
        case "banknote.fill": "Money"
        default: "Tag"
        }
    }
}

#Preview("Icons · tap to select", traits: .sizeThatFitsLayout) {
    @Previewable @State var selection = "fork.knife"
    CategoryIconPicker(selection: $selection, tint: .orange)
        .padding()
}
