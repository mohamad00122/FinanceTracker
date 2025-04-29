import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @EnvironmentObject var vm: BankAccountsViewModel
    @State private var linkToken = ""
    @State private var isLinkPresented = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var showAllTransactions = false
    @State private var searchText = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    if vm.accounts.isEmpty {
                        noBankConnectedView
                    } else {
                        dashboardView
                    }
                    Spacer(minLength: 40)
                }
                .padding(.vertical)
                .onAppear {
                    vm.fetchAccounts()
                    vm.fetchAllTransactions()
                }
            }
            .navigationTitle("Dashboard")
            .sheet(isPresented: $isLinkPresented) {
                PlaidLinkView(
                    linkToken: linkToken,
                    onSuccess: { publicToken in
                        exchangePublicToken(publicToken) {
                            vm.fetchAccounts()
                            vm.fetchAllTransactions()
                            isLinkPresented = false
                        }
                    },
                    onExit: { _ in isLinkPresented = false }
                )
            }
            .alert(isPresented: $showingError) {
                Alert(
                    title: Text("Error"),
                    message: Text(errorMessage ?? ""),
                    dismissButton: .default(Text("OK")) {
                        errorMessage = nil
                    }
                )
            }
        }
    }

    private var noBankConnectedView: some View {
        VStack(spacing: 16) {
            Text("No Bank Account Connected").font(.headline)
            Text("Connect your bank account to view your spending data.")
                .font(.subheadline).multilineTextAlignment(.center).padding(.horizontal)
            Button("Connect Bank Account") { fetchLinkToken() }
                .font(.headline).padding().frame(maxWidth: .infinity)
                .background(Color.blue).foregroundColor(.white).cornerRadius(10)
        }
        .padding().background(.ultraThinMaterial).cornerRadius(20)
        .padding(.horizontal).shadow(radius: 10).padding(.top)
    }

    private var dashboardView: some View {
        VStack(spacing: 16) {
            Text("Finance Tracker").font(.largeTitle).bold()
                .frame(maxWidth: .infinity, alignment: .leading)

            // comparison cards
            SpendingComparisonView(
                currentFormatted: calculateThisMonth().formattedCurrency(),
                averageFormatted: calculateAvg().formattedCurrency()
            )

            // line + rule chart
            SpendingChartView(
                monthlyTotals: calculateMonthlyTotals(),
                average: calculateAvg()
            ).frame(height: 220)

            Text("Plaid Status: Connected")
                .font(.footnote).foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)

            transactionsView
        }
        .padding().background(.ultraThinMaterial).cornerRadius(20)
        .padding(.horizontal).shadow(radius: 8)
    }

    private var transactionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Transactions").font(.title2).bold()
                Spacer()
                Button { withAnimation { showAllTransactions.toggle() } } label: {
                    Image(systemName: showAllTransactions ? "chevron.up" : "chevron.down")
                        .foregroundColor(.blue)
                }
            }

            if showAllTransactions {
                TextField("Search transactions", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.bottom, 5)
            }

            ForEach(filteredTransactions.prefix(showAllTransactions ? 100 : 3)) { txn in
                TransactionRowView(transaction: txn)
                    .padding().background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            }
        }
    }

    private var filteredTransactions: [PlaidTransaction] {
        if searchText.isEmpty {
            return vm.transactions
        } else {
            return vm.transactions.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
                || ($0.category?.joined(separator: ", ").localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }

    // MARK: – Plaid Link & Token Exchange

    private func fetchLinkToken() {
        guard let url = URL(string: "\(Constants.serverBaseURL)/api/create_link_token") else { return }
        var req = URLRequest(url: url); req.httpMethod = "POST"
        URLSession.shared.dataTask(with: req) { data, _, _ in
            if let data = data,
               let res = try? JSONDecoder().decode([String:String].self, from: data),
               let token = res["link_token"] {
                DispatchQueue.main.async {
                    self.linkToken = token
                    self.isLinkPresented = true
                }
            }
        }.resume()
    }

    private func exchangePublicToken(_ publicToken: String, completion: @escaping ()->Void) {
        guard let url = URL(string: "\(Constants.serverBaseURL)/api/exchange_public_token"),
              let userId = Auth.auth().currentUser?.uid else { return }
        var req = URLRequest(url: url); req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "public_token": publicToken,
            "user_id": userId
        ])
        URLSession.shared.dataTask(with: req) { data, _, _ in
            completion()
        }.resume()
    }

    // MARK: – Calculations

    private func calculateThisMonth() -> Double {
        let currentMonth = Calendar.current.component(.month, from: Date())
        return vm.transactions
            .filter { Calendar.current.component(.month, from: parseDate($0.date)) == currentMonth }
            .map(\.amount).reduce(0, +)
    }

    private func calculateAvg() -> Double {
        let months = Set(vm.transactions.map {
            Calendar.current.component(.month, from: parseDate($0.date))
        })
        let total = vm.transactions.map(\.amount).reduce(0, +)
        return months.isEmpty ? 0 : total / Double(months.count)
    }

    private func calculateMonthlyTotals() -> [(String,Double)] {
        let grouped = Dictionary(grouping: vm.transactions) { txn in
            let date = parseDate(txn.date)
            let f = DateFormatter(); f.dateFormat = "MMM yyyy"
            return f.string(from: date)
        }
        return grouped.map { month, txns in
            (month, txns.map(\.amount).reduce(0, +))
        }
        .sorted { lhs, rhs in
            let f = DateFormatter(); f.dateFormat = "MMM yyyy"
            return (f.date(from: lhs.0) ?? Date()) < (f.date(from: rhs.0) ?? Date())
        }
    }

    private func parseDate(_ s: String) -> Date {
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: s) { return d }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = .utc
        return f.date(from: s) ?? Date()
    }
}

// MARK: – Currency Formatter

extension Double {
    func formattedCurrency() -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.maximumFractionDigits = 2
        fmt.minimumFractionDigits = 2
        fmt.usesGroupingSeparator = true
        return fmt.string(from: NSNumber(value: self)) ?? "$0.00"
    }
}
