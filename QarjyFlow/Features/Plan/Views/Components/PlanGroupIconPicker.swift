import SwiftUI

struct PlanGroupIconPicker: View {
    @Binding var selection: String
    let tint: Color
    private let symbols = ["house.fill", "cart.fill", "chart.line.uptrend.xyaxis", "shield.fill",
                           "sparkles", "leaf.fill", "figure.run", "airplane", "gift.fill",
                           "book.fill", "heart.fill", "tag.fill"]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 58), spacing: 12)], spacing: 12) {
            ForEach(symbols, id: \.self) { symbol in
                Button { selection = symbol } label: {
                    Image(systemName: symbol).font(.title2)
                        .foregroundStyle(tint).frame(width: 52, height: 52)
                        .background(tint.opacity(selection == symbol ? 0.16 : 0.05),
                                    in: RoundedRectangle(cornerRadius: 13))
                        .overlay { RoundedRectangle(cornerRadius: 13)
                            .stroke(selection == symbol ? tint : .clear, lineWidth: 2) }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(symbol.replacingOccurrences(of: ".fill", with: ""))
                .accessibilityAddTraits(selection == symbol ? .isSelected : [])
            }
        }
    }
}

#Preview("Plan section icons · selectable", traits: .sizeThatFitsLayout) {
    @Previewable @State var symbol = "sparkles"
    PlanGroupIconPicker(selection: $symbol, tint: .purple).padding()
}
