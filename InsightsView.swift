import SwiftUI
import Charts
import FirebaseAuth
import FirebaseFirestore

struct CategorySpending: Identifiable, Equatable { // <-- Added Equatable
    let id = UUID()
    let category: String
    let amount: Double
}

struct InsightsView: View {
    @State private var selectedMonth = Date()
    @State private var allTransactions: [PlaidTransaction] = []
    @State private var monthTransactions: [PlaidTransaction] = []
    @State private var spendingData: [CategorySpending] = []
    @State private var isLoading = true

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Spending Breakdown")
                        .font(.largeTitle.bold())

                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Select Month")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            DatePicker("", selection: $selectedMonth, displayedComponents: [.date])
                                .labelsHidden()
                                .onChange(of: selectedMonth) {
                                    filterTransactionsByMonth()
                                }
                        }
                        .padding(.horizontal)

                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else if spendingData.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "wallet.pass")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 50, height: 50)
                                    .foregroundColor(.gray)
                                Text("No spending data for this month.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                        } else {
                            Chart(spendingData.sorted { $0.amount > $1.amount }) { item in
                                SectorMark(
                                    angle: .value("Amount", item.amount),
                                    innerRadius: .ratio(0.5),
                                    angularInset: 2
                                )
                                .foregroundStyle(colorForCategory(item.category))
                            }
                            .frame(height: 250)
                            .chartLegend(.hidden)
                            .animation(.easeInOut(duration: 0.5), value: spendingData)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(spendingData.sorted { $0.amount > $1.amount }) { item in
                                HStack {
                                    Circle()
                                        .fill(colorForCategory(item.category))
                                        .frame(width: 8, height: 8)
                                    Text(item.category)
                                        .font(.subheadline)
                                    Spacer()
                                    Text(item.amount.formattedCurrency())
                                        .font(.subheadline.bold())
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)
                }
                .padding()
            }
            .navigationTitle("Insights")
            .onAppear {
                fetchTransactions()
            }
        }
    }

    private func fetchTransactions() {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let db = Firestore.firestore()
        db.collection("users").document(userId).collection("bank_accounts").getDocuments { snapshot, error in
            if let error = error {
                print("❌ Firestore error:", error)
                self.isLoading = false
                return
            }

            let tokens = snapshot?.documents.compactMap { $0.data()["access_token"] as? String } ?? []
            for token in tokens {
                fetchTransactionsFromBackend(token)
            }
        }
    }

    private func fetchTransactionsFromBackend(_ accessToken: String) {
        guard let url = URL(string: "\(Constants.serverBaseURL)/api/transactions") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = ["access_token": accessToken]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let data = data {
                    do {
                        let decoded = try JSONDecoder().decode([PlaidTransaction].self, from: data)
                        self.allTransactions.append(contentsOf: decoded)
                        self.filterTransactionsByMonth()
                    } catch {
                        print("❌ Decoding error:", error)
                    }
                } else {
                    print("❌ Network error or no data")
                }
                self.isLoading = false
            }
        }.resume()
    }

    private func filterTransactionsByMonth() {
        let calendar = Calendar.current
        let selectedComponents = calendar.dateComponents([.year, .month], from: selectedMonth)

        monthTransactions = allTransactions.filter { txn in
            let txnDate = parseDate(txn.date)
            let txnComponents = calendar.dateComponents([.year, .month], from: txnDate)
            return txnComponents.year == selectedComponents.year && txnComponents.month == selectedComponents.month
        }

        spendingData = calculateSpendingData(from: monthTransactions)
    }

    private func calculateSpendingData(from transactions: [PlaidTransaction]) -> [CategorySpending] {
        let grouped = Dictionary(grouping: transactions, by: { $0.category?.first ?? "Other" })
        return grouped.map { (category, txns) in
            CategorySpending(category: category, amount: txns.map { $0.amount }.reduce(0, +))
        }
    }

    private func parseDate(_ dateString: String) -> Date {
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: dateString) {
            return date
        }

        let fallback = DateFormatter()
        fallback.dateFormat = "yyyy-MM-dd"
        fallback.timeZone = TimeZone(abbreviation: "UTC")
        return fallback.date(from: dateString) ?? Date()
    }

    private func colorForCategory(_ category: String) -> Color {
        switch category.lowercased() {
        case "food and drink": return .blue
        case "travel": return .purple
        case "transfer": return .orange
        case "recreation": return .pink
        case "payment": return .red
        case "shops": return .green
        default: return .gray
        }
    }
}

