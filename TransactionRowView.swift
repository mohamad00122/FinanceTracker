import SwiftUI

struct TransactionRowView: View {
    let transaction: PlaidTransaction

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.name)
                    .font(.headline)

                if let category = transaction.category?.joined(separator: ", ") {
                    Text(category)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                Text(formattedDate(transaction.date))
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            Text(transaction.amount.formattedCurrency())
                .font(.headline)
                .foregroundColor(transaction.amount >= 0 ? .primary : .red)
        }
        .padding(.vertical, 8)
    }

    private func formattedDate(_ iso: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        if let date = isoFormatter.date(from: iso) {
            return dateFormatter.string(from: date)
        }

        return iso // fallback
    }
}
