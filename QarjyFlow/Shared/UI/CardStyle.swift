import SwiftUI

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                Color(uiColor: .secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 18)
            )
    }
}

extension View {
    func cardStyle() -> some View { modifier(CardStyle()) }
}

#Preview("Card style · container surface", traits: .sizeThatFitsLayout) {
    VStack(alignment: .leading, spacing: 8) {
        Text("Card title").font(.headline)
        Text("CardStyle supplies the padding, background, and rounded corners.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
    .cardStyle()
    .padding(20)
    .background(Color(uiColor: .systemGroupedBackground))
}
