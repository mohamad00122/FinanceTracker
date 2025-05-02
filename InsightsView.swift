import SwiftUI
import Charts

struct InsightsView: View {
    @EnvironmentObject var vm: BankAccountsViewModel

    // 1) Category filter
    @State private var selectedCategory = "All"
    private var categories: [String] {
        // flatten all transactions to one array
        let allTxns = vm.transactions.values.flatMap { $0 }
        // pull out every category array, then flatten
        let cats = allTxns
            .compactMap { $0.category }    // [String]?
            .flatMap { $0 }                // [String]
        let unique = Array(Set(cats)).sorted()
        return ["All"] + unique
    }

    // 2) Date range
    @State private var startDate = Calendar.current.date(
        byAdding: .month, value: -1, to: Date()
    )!
    @State private var endDate = Date()

    // 3) Account selector
    @State private var selectedAccountIds: Set<String> = []
    private var accountOptions: [BankAccount] { vm.accounts }

    // ─── Filtered transactions ───
    private var filteredTxns: [PlaidTransaction] {
        // flatten dictionary into one array
        let allTxns = vm.transactions.values.flatMap { $0 }
        return allTxns.filter { txn in
            let txnDate = parseDate(txn.date)
            let matchesCategory = (selectedCategory == "All")
                || (txn.category?.contains(selectedCategory) ?? false)
            let matchesDate = (txnDate >= startDate && txnDate <= endDate)
            let matchesAccount = selectedAccountIds.isEmpty
                || selectedAccountIds.contains(txn.accountId)
            return matchesCategory && matchesDate && matchesAccount
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // ───── Filters ─────
                VStack(spacing: 8) {
                    // Category picker
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)

                    // Date range pickers
                    HStack {
                        DatePicker("From", selection: $startDate,
                                   in: ...endDate, displayedComponents: .date)
                        DatePicker("To", selection: $endDate,
                                   in: startDate..., displayedComponents: .date)
                    }

                    // Accounts multi-select
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
                                    Text(acct.id) // or acct.institutionName
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
                            Text(selectedAccountIds.isEmpty
                                 ? "All"
                                 : "\(selectedAccountIds.count) selected")
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.secondarySystemBackground))
                        )
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                )
                .shadow(radius: 1)

                // ───── Chart or Empty State ─────
                if filteredTxns.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.largeTitle)
                            .opacity(0.3)
                        Text("No data for your selection")
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 50)

                } else {
                    // Group by first category, or "Uncategorized"
                    let grouped = Dictionary(
                        grouping: filteredTxns,
                        by: { $0.category?.first ?? "Uncategorized" }
                    )

                    // Convert to (category, totalAmount)
                    let data = grouped.map { (category, txns) in
                        (category, txns.map(\.amount).reduce(0, +))
                    }

                    Chart {
                        ForEach(data, id: \.0) { category, sum in
                            SectorMark(
                                angle: .value("Amount", sum),
                                innerRadius: .ratio(0.5),
                                angularInset: 1
                            )
                            .foregroundStyle(by: .value("Category", category))
                        }
                    }
                    .frame(height: 250)
                    .padding()
                }
            }
            .padding()
        }
        .navigationTitle("Insights")
    }

    // MARK: – Date parser
    private func parseDate(_ s: String) -> Date {
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: s) { return d }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f.date(from: s) ?? Date()
    }
}
