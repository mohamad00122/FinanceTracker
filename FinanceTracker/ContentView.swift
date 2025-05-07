import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @EnvironmentObject var vm: BankAccountsViewModel
    @State private var linkToken = ""
    @State private var isLinkPresented = false
    @State private var showingError = false
    @State private var errorMessage: String?
    @State private var showAllTransactions = false
    @State private var searchText = ""
    @State private var animateFloat = false

    private var allTransactions: [PlaidTransaction] {
        vm.transactions.values.flatMap { $0 }
    }

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
            }
            .navigationTitle("Dashboard")
            .refreshable {
                await vm.fetchAccounts()
                await vm.fetchAllTransactions()
            }
            .sheet(isPresented: $isLinkPresented) {
                PlaidLinkView(
                    linkToken: linkToken,
                    onSuccess: { publicToken in
                        exchangePublicToken(publicToken) {
                            isLinkPresented = false
                        }
                    },
                    onExit: { _ in
                        isLinkPresented = false
                    }
                )
            }
            .alert(isPresented: $showingError) {
                Alert(
                    title: Text("Error"),
                    message: Text(errorMessage ?? "Unknown error"),
                    dismissButton: .default(Text("OK")) {
                        errorMessage = nil
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
                Text("Connect Bank Account")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .scaleEffect(isLinkPresented ? 0.95 : 1.0)
            }
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
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                Text("Spendr")
                    .font(.largeTitle).bold()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            SpendingComparisonView(
                currentFormatted: calculateThisMonth().formattedCurrency(),
                averageFormatted: calculateAvg().formattedCurrency()
            )

            SpendingChartView(
                monthlyTotals: calculateMonthlyTotals(),
                average: calculateAvg()
            )
            .frame(height: 220)

            Label("Plaid Connected", systemImage: "checkmark.shield.fill")
                .font(.footnote)
                .foregroundColor(.green)
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
                    .font(.title2).bold()
                Spacer()
                Button {
                    withAnimation { showAllTransactions.toggle() }
                } label: {
                    Image(systemName: showAllTransactions ? "chevron.up" : "chevron.down")
                        .foregroundColor(.blue)
                        .scaleEffect(showAllTransactions ? 1.1 : 1.0)
                        .animation(.spring(), value: showAllTransactions)
                }
            }

            if showAllTransactions {
                TextField("Search transactions", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.bottom, 5)
            }

            if filteredTransactions.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "wallet.pass")
                        .resizable()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.gray)
                        .opacity(0.7)
                        .offset(y: animateFloat ? -6 : 6)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: animateFloat)
                        .onAppear {
                            animateFloat.toggle()
                        }

                    Text("No transactions yet")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            } else {
                ForEach(filteredTransactions.prefix(showAllTransactions ? 100 : 3)) { txn in
                    TransactionRowView(transaction: txn)
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.3), value: filteredTransactions)
                }
            }
        }
    }

    private var filteredTransactions: [PlaidTransaction] {
        let all = allTransactions
        guard !all.isEmpty else { return [] }
        if searchText.isEmpty { return all }
        return all.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
            || ($0.category?.joined(separator: ", ").localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private func fetchLinkToken() {
        guard let url = URL(string: "\(Constants.serverBaseURL)/api/create_link_token") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"

        URLSession.shared.dataTask(with: req) { data, _, err in
            if let err = err {
                print("❌ Link token fetch error:", err)
                return
            }
            guard
                let data = data,
                let res = try? JSONDecoder().decode([String: String].self, from: data),
                let token = res["link_token"]
            else { return }
            DispatchQueue.main.async {
                linkToken = token
                isLinkPresented = true
            }
        }.resume()
    }

    private func exchangePublicToken(_ publicToken: String, completion: @escaping () -> Void) {
        guard
            let url = URL(string: "\(Constants.serverBaseURL)/api/exchange_public_token"),
            let userId = Auth.auth().currentUser?.uid
        else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "public_token": publicToken,
            "userId": userId
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { data, _, err in
            if let err = err {
                DispatchQueue.main.async {
                    errorMessage = err.localizedDescription
                    showingError = true
                    isLinkPresented = false
                }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async {
                    errorMessage = "No data from exchange"
                    showingError = true
                    isLinkPresented = false
                }
                return
            }
            do {
                _ = try JSONDecoder().decode(ExchangeResponse.self, from: data)
                DispatchQueue.main.async {
                    isLinkPresented = false
                }
            } catch {
                DispatchQueue.main.async {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isLinkPresented = false
                }
            }
        }.resume()
    }

    private func calculateThisMonth() -> Double {
        let currentMonth = Calendar.current.component(.month, from: Date())
        return allTransactions
            .filter { Calendar.current.component(.month, from: parseDate($0.date)) == currentMonth }
            .map(\.amount)
            .reduce(0, +)
    }

    private func calculateAvg() -> Double {
        let months = Set(allTransactions.map {
            Calendar.current.component(.month, from: parseDate($0.date))
        })
        let total = allTransactions.map(\.amount).reduce(0, +)
        return months.isEmpty ? 0 : total / Double(months.count)
    }

    private func calculateMonthlyTotals() -> [(String, Double)] {
        let grouped = Dictionary(grouping: allTransactions, by: { txn in
            let date = parseDate(txn.date)
            let fmt = DateFormatter(); fmt.dateFormat = "MMM yyyy"
            return fmt.string(from: date)
        })
        return grouped.map { month, txns in
            (month, txns.map(\.amount).reduce(0, +))
        }
        .sorted { lhs, rhs in
            let fmt = DateFormatter(); fmt.dateFormat = "MMM yyyy"
            return (fmt.date(from: lhs.0) ?? Date()) < (fmt.date(from: rhs.0) ?? Date())
        }
    }

    private func parseDate(_ s: String) -> Date {
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: s) { return d }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f.date(from: s) ?? Date()
    }
}

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
