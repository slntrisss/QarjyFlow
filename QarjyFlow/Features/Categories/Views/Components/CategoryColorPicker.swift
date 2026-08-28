import SwiftUI

struct CategoryColorPicker: View {
    @Binding var selection: CategoryColor

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 12)], spacing: 12) {
            ForEach(CategoryColor.allCases) { color in
                Button {
                    selection = color
                } label: {
                    VStack(spacing: 8) {
                        Circle()
                            .fill(color.tint)
                            .frame(width: 32, height: 32)
                        Text(color.title)
                            .font(.caption)
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 72)
                    .padding(6)
                    .background(color.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(selection == color ? Color.primary : .clear, lineWidth: 2)
                    }
                    .overlay(alignment: .topTrailing) {
                        if selection == color {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.primary)
                                .padding(4)
                        }
                    }
                    .contentShape(Rectangle())
                }
                // A plain button preserves the swatch; native menu pickers may
                // render their labels using the app-wide accent instead.
                .buttonStyle(.plain)
                .accessibilityLabel(color.title)
                .accessibilityAddTraits(selection == color ? .isSelected : [])
                .accessibilityIdentifier("category.color.\(color.rawValue)")
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview("Colors · tap to select", traits: .sizeThatFitsLayout) {
    @Previewable @State var selection = CategoryColor.orange
    CategoryColorPicker(selection: $selection)
        .padding()
        .tint(.green)
}

#Preview("Colors · dark mode", traits: .sizeThatFitsLayout) {
    @Previewable @State var selection = CategoryColor.blue
    CategoryColorPicker(selection: $selection)
        .padding()
        .preferredColorScheme(.dark)
}
