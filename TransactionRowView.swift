import SwiftUI

struct TransactionRowView: View {
    let transaction: PlaidTransaction

    var body: some View {
        HStack(spacing: 16) {
            // Category Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 44, height: 44)

                Image(systemName: iconForCategory())
                    .foregroundColor(.blue)
            }

            // Transaction Info
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.name)
                    .font(.headline)

                if let category = transaction.category?.joined(separator: ", ") {
                    Text(category)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Text(formattedDate(transaction.date))
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            // Amount
            VStack(alignment: .trailing) {
                Text(transaction.amount.formattedCurrency())
                    .font(.headline)
                    .foregroundColor(transaction.amount >= 0 ? .primary : .red)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    // MARK: – Helpers

    private func formattedDate(_ iso: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        if let date = isoFormatter.date(from: iso) {
            return dateFormatter.string(from: date)
        }
        return iso
    }

    private func iconForCategory() -> String {
        guard let category = transaction.category?.first?.lowercased() else {
            return "questionmark.circle"
        }

        switch category {
        case let c where c.contains("food"):
            return "fork.knife"
        case let c where c.contains("shop"):
            return "bag.fill"
        case let c where c.contains("travel"):
            return "airplane"
        case let c where c.contains("recreation"):
            return "figure.walk"
        case let c where c.contains("payment"):
            return "creditcard.fill"
        case let c where c.contains("transfer"):
            return "arrow.left.arrow.right"
        default:
            return "dollarsign.circle"
        }
    }
}
