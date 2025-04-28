import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ContentView: View {
    @StateObject private var viewModel = BankAccountsViewModel()
    @State private var transactions: [PlaidTransaction] = []
    @State private var linkToken: String = ""
    @State private var isLinkPresented = false
    @State private var errorMessage = ""
    @State private var showAllTransactions = false
    @State private var searchText = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    if viewModel.bankAccounts.isEmpty {
                        noBankConnectedView
                    } else {
                        dashboardView
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.vertical)
                .onAppear {
                    viewModel.fetchBankAccounts()
                    if let user = Auth.auth().currentUser {
                        fetchAccessTokens(for: user.uid)
                    }
                }
            }
            .navigationTitle("Dashboard")
            .sheet(isPresented: $isLinkPresented) {
                PlaidLinkView(
                    linkToken: linkToken,
                    onSuccess: { publicToken in
                        exchangePublicToken(publicToken) { token in
                            if token != nil {
                                viewModel.fetchBankAccounts()
                            }
                            isLinkPresented = false
                        }
                    },
                    onExit: { _ in
                        isLinkPresented = false
                    }
                )
            }
        }
    }

    private var noBankConnectedView: some View {
        VStack(spacing: 16) {
            Text("No Bank Account Connected")
                .font(.headline)

            Text("Connect your bank account to view your spending data.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: {
                fetchLinkToken()
            }) {
                Label("Connect Bank Account", systemImage: "link")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top, 10)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .padding(.horizontal)
        .shadow(radius: 10)
        .padding(.top)
    }

    private var dashboardView: some View {
        VStack(spacing: 16) {
            Text("Finance Tracker")
                .font(.largeTitle)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)

            SpendingComparisonView(
                currentFormatted: calculateThisMonth().formattedCurrency(),
                averageFormatted: calculateAvg().formattedCurrency()
            )

            SpendingChartView(
                monthlyTotals: calculateMonthlyTotals()
            )
            .frame(height: 220)

            Text("Plaid Status: Connected")
                .font(.footnote)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)

            transactionsView
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .padding(.horizontal)
        .shadow(radius: 8)
    }
    
    private var transactionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Transactions")
                    .font(.title2)
                    .bold()

                Spacer()

                Button(action: {
                    withAnimation {
                        showAllTransactions.toggle()
                    }
                }) {
                    Image(systemName: showAllTransactions ? "chevron.up" : "chevron.down")
                        .foregroundColor(.blue)
                }
            }

            if showAllTransactions {
                TextField("Search transactions", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.bottom, 5)
            }

            VStack(spacing: 12) {
                ForEach(filteredTransactions.prefix(showAllTransactions ? 100 : 3), id: \.id) { txn in
                    TransactionRowView(transaction: txn)
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                }
            }
        }
    }

    var filteredTransactions: [PlaidTransaction] {
        if searchText.isEmpty {
            return transactions
        } else {
            return transactions.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                ($0.category?.joined(separator: ", ").localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }

    // MARK: - Plaid Logic
    private func fetchLinkToken() {
        guard let url = URL(string: "\(Constants.serverBaseURL)/api/create_link_token") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data = data,
               let result = try? JSONDecoder().decode([String: String].self, from: data),
               let token = result["link_token"] {
                DispatchQueue.main.async {
                    self.linkToken = token
                    self.isLinkPresented = true
                }
            }
        }.resume()
    }

    private func exchangePublicToken(_ publicToken: String, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "\(Constants.serverBaseURL)/api/exchange_public_token"),
              let userId = Auth.auth().currentUser?.uid else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: String] = [
            "public_token": publicToken,
            "user_id": userId
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: request) { data, response, _ in
            if let httpRes = response as? HTTPURLResponse {
                print("HTTP Status Code:", httpRes.statusCode)
            }

            guard let data = data,
                  let result = try? JSONDecoder().decode([String: String].self, from: data),
                  let token = result["access_token"] else {
                print("❌ Token exchange failed or response was invalid.")
                completion(nil)
                return
            }

            print("✅ Access token received: \(token)")
            completion(token)
        }.resume()
    }

    // MARK: - Transaction Fetching
    func fetchAccessTokens(for userId: String) {
        let db = Firestore.firestore()
        db.collection("users").document(userId).collection("bank_accounts").getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching tokens:", error)
                return
            }

            let tokens = snapshot?.documents.compactMap { $0.data()["access_token"] as? String } ?? []
            for token in tokens {
                fetchTransactions(token)
            }
        }
    }

    func fetchTransactions(_ token: String) {
        guard let url = URL(string: "\(Constants.serverBaseURL)/api/transactions") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = ["access_token": token]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data else {
                print("❌ No transaction data")
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP Status Code:", httpResponse.statusCode)
                print("Raw Response:", String(data: data, encoding: .utf8) ?? "<invalid>")
            }

            do {
                let txns = try JSONDecoder().decode([PlaidTransaction].self, from: data)
                DispatchQueue.main.async {
                    self.transactions.append(contentsOf: txns)
                }
            } catch {
                print("Decode error:", error)
            }
        }.resume()
    }

    // MARK: - Helpers
    func calculateThisMonth() -> Double {
        let currentMonth = Calendar.current.component(.month, from: Date())
        return transactions
            .filter { Calendar.current.component(.month, from: parseDate($0.date)) == currentMonth }
            .map { $0.amount }
            .reduce(0, +)
    }

    func calculateAvg() -> Double {
        let months = Set(transactions.map {
            Calendar.current.component(.month, from: parseDate($0.date))
        })
        let total = transactions.map { $0.amount }.reduce(0, +)
        return months.count > 0 ? total / Double(months.count) : 0
    }

    func calculateMonthlyTotals() -> [(String, Double)] {

        let grouped = Dictionary(grouping: transactions) { txn in
            let date = parseDate(txn.date)
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM yyyy"
            return formatter.string(from: date)
        }

        return grouped.map { (month, txns) in
            let total = txns.map { $0.amount }.reduce(0, +)
            return (month, total)
        }
        .sorted { (lhs, rhs) in
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM yyyy"
            guard let lhsDate = formatter.date(from: lhs.0),
                  let rhsDate = formatter.date(from: rhs.0) else {
                return lhs.0 < rhs.0
            }
            return lhsDate < rhsDate
        }
    }

    func parseDate(_ dateString: String) -> Date {
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: dateString) {
            return date
        }

        let fallback = DateFormatter()
        fallback.dateFormat = "yyyy-MM-dd"
        fallback.timeZone = TimeZone(abbreviation: "UTC")
        if let date = fallback.date(from: dateString) {
            return date
        }

        return Date()
    }
}

// MARK: - Currency Formatter
extension Double {
    func formattedCurrency() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        formatter.usesGroupingSeparator = true
        return formatter.string(from: NSNumber(value: self)) ?? "$0.00"
    }
}
