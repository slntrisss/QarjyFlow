import SwiftUI

struct PercentageInputField: View {
    @Binding var text: String
    @Binding var isFocused: Bool
    let identifier: String

    var body: some View {
        HStack(spacing: 4) {
            AmountTextField(
                rawText: $text,
                placeholder: "30",
                inputLabel: "Percentage of expected income",
                inputIdentifier: identifier,
                isFocused: $isFocused
            )
            .frame(width: 88)
            .frame(minHeight: 44)

            Text("%")
                .fixedSize()
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

#Preview("Percentage input", traits: .sizeThatFitsLayout) {
    @Previewable @State var text = "30"
    @Previewable @State var focused = false
    PercentageInputField(text: $text, isFocused: $focused, identifier: "preview.percentage")
        .padding()
}
