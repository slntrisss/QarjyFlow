import SwiftUI

struct TransactionRow: View {
    let transaction: TransactionItem
    let category: CategoryItem?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category?.symbol ?? "tag.fill")
                .foregroundStyle(category?.color.tint ?? .gray)
                .frame(width: 36, height: 36)
                .background((category?.color.tint ?? .gray).opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.merchant.isEmpty ? (category?.name ?? "Category unavailable") : transaction.merchant)
                    .foregroundStyle(.primary)
                Text("\(category?.name ?? "Category unavailable")\(category?.isArchived == true ? " · archived" : "")")
                    .font(.caption).foregroundStyle(.secondary)
                Text(transaction.date, format: .dateTime.day().month().year())
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text("\(transaction.kind == .income ? "+" : "−")\(transaction.amount.tenge)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(transaction.kind == .income ? .green : .primary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Transaction row", traits: .sizeThatFitsLayout) {
    let model = TransactionPreviewData.model()
    if let item = model.transactions.first {
        TransactionRow(transaction: item, category: model.category(for: item)).padding()
    }
}
