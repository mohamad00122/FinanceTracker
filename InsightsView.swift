import SwiftUI
import Charts

struct InsightsView: View {
    @EnvironmentObject var vm: BankAccountsViewModel

    @State private var selectedCategory = "All"
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
    @State private var endDate = Date()
    @State private var selectedAccountIds: Set<String> = []

    private var categories: [String] {
        let allTxns = vm.transactions.values.flatMap { $0 }
        let cats = allTxns
            .compactMap { $0.category }
            .flatMap { $0 }
        let unique = Array(Set(cats)).sorted()
        return ["All"] + unique
    }

    private var accountOptions: [BankAccount] { vm.accounts }

    private var filteredTxns: [PlaidTransaction] {
        let allTxns = vm.transactions.values.flatMap { $0 }
        return allTxns.filter { txn in
            let txnDate = parseDate(txn.date)
            let matchesCategory = (selectedCategory == "All") || (txn.category?.contains(selectedCategory) ?? false)
            let matchesDate = txnDate >= startDate && txnDate <= endDate
            let matchesAccount = selectedAccountIds.isEmpty || selectedAccountIds.contains(txn.accountId)
            return matchesCategory && matchesDate && matchesAccount
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // ───── Filters Card ─────
                VStack(spacing: 12) {
                    HStack {
                        Text("Category")
                        Spacer()
                        Picker("", selection: $selectedCategory) {
                            ForEach(categories, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }

                    HStack {
                        DatePicker("From", selection: $startDate, in: ...endDate, displayedComponents: .date)
                        DatePicker("To", selection: $endDate, in: startDate..., displayedComponents: .date)
                    }

                    Menu {
                        ForEach(accountOptions) { acct in
                            Button {
                                if selectedAccountIds.contains(acct.id) {
                                    selectedAccountIds.remove(acct.id)
                                } else {
                                    selectedAccountIds.insert(acct.id)
                                }
                            } label: {
                                HStack {
                                    Text(acct.institutionName ?? acct.name)
                                    if selectedAccountIds.contains(acct.id) {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text("Accounts")
                            Spacer()
                            Text(selectedAccountIds.isEmpty ? "All" : "\(selectedAccountIds.count) selected")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .shadow(radius: 5)

                // ───── Chart or Empty State ─────
                if filteredTxns.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "chart.pie.fill")
                            .font(.system(size: 40))
                            .opacity(0.2)
                        Text("No data for your selection")
                            .foregroundColor(.secondary)
                        Button("Reset Filters") {
                            selectedCategory = "All"
                            selectedAccountIds.removeAll()
                            startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
                            endDate = Date()
                        }
                        .font(.footnote)
                    }
                    .padding(.top, 40)

                } else {
                    let grouped = Dictionary(grouping: filteredTxns, by: { $0.category?.first ?? "Uncategorized" })

                    var chartData: [(category: String, sum: Double)] = []
                    for (category, txns) in grouped {
                        let total = txns.map(\.amount).reduce(0, +)
                        chartData.append((category: category, sum: total))
                    }

                    Chart(chartData, id: \.category) { item in
                        SectorMark(
                            angle: .value("Amount", item.sum),
                            innerRadius: .ratio(0.5),
                            angularInset: 1
                        )
                        .foregroundStyle(by: .value("Category", item.category))
                        .annotation(position: .center) {
                            Text(item.category)
                                .font(.caption)
                        }
                    }
                    .frame(height: 250)
                    .padding()
                    .animation(.easeOut(duration: 0.6), value: chartData)
                }
            }
            .padding()
        }
        .navigationTitle("Insights")
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
