import SwiftUI

struct SpendingComparisonView: View {
    let currentFormatted: String
    let averageFormatted: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(comparisonMessage)
                .font(.headline)
                .foregroundColor(.white)

            HStack(spacing: 30) {
                VStack(alignment: .leading) {
                    Label("This Month", systemImage: "creditcard.fill")
                        .foregroundColor(.orange)
                        .font(.caption)

                    Text(currentFormatted)
                        .font(.title2) // Smaller than .title
                        .bold()
                        .foregroundColor(.orange)
                }

                VStack(alignment: .leading) {
                    Label("Average", systemImage: "chart.bar.fill")
                        .foregroundColor(.gray)
                        .font(.caption)

                    Text(averageFormatted)
                        .font(.title2) // Smaller than .title
                        .bold()
                        .foregroundColor(.gray)
                }
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var comparisonMessage: String {
        let currentValue = parseCurrency(currentFormatted)
        let averageValue = parseCurrency(averageFormatted)

        if currentValue < averageValue {
            return "You spent less than usual this month."
        } else {
            return "You spent more than usual this month."
        }
    }

    private func parseCurrency(_ string: String) -> Double {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.number(from: string)?.doubleValue ?? 0.0
    }
}
