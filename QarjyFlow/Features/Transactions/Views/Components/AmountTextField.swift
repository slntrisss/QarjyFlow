import SwiftUI
import UIKit

/// UIKit exposes the selection range needed to preserve the caret during regrouping.
struct AmountTextField: UIViewRepresentable {
    @Binding var rawText: String

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.keyboardType = .decimalPad
        field.textAlignment = .right
        field.font = .preferredFont(forTextStyle: .title3)
        field.adjustsFontForContentSizeCategory = true
        field.placeholder = "0.00"
        field.accessibilityLabel = "Amount in tenge"
        field.accessibilityHint = "Thousands are separated with spaces automatically."
        field.accessibilityIdentifier = "transaction.amount"
        field.delegate = context.coordinator
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        let display = AmountInputFormatting.display(rawText)
        if field.text != display { field.text = display }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    @MainActor
    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: AmountTextField

        init(parent: AmountTextField) { self.parent = parent }

        func textField(_ field: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            guard let edit = AmountInputFormatting.edit(display: field.text ?? "", range: range, replacement: string) else {
                return false
            }
            field.text = edit.displayText
            parent.rawText = edit.rawText
            if let position = field.position(from: field.beginningOfDocument, offset: edit.caretOffset) {
                field.selectedTextRange = field.textRange(from: position, to: position)
            }
            return false
        }

        func textFieldShouldClear(_ field: UITextField) -> Bool {
            parent.rawText = ""
            return true
        }
    }
}

#Preview("Amount · live thousands grouping", traits: .sizeThatFitsLayout) {
    @Previewable @State var rawText = "1000"
    VStack(alignment: .leading, spacing: 12) {
        LabeledContent("Amount · KZT") {
            AmountTextField(rawText: $rawText).frame(minHeight: 44)
        }
        Text("Draft value: \(rawText)").font(.caption)
    }
    .padding()
}
