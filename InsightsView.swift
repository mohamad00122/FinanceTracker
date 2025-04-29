import SwiftUI
import Charts

struct InsightsView: View {
  @StateObject private var vm = BankAccountsViewModel()
  
  // 1. Category filter
  @State private var selectedCategory: String = "All"
  private var categories: [String] {
    let cats = vm.transactions.map { $0.category }
    return ["All"] + Array(Set(cats)).sorted()
  }
  
  // 2. Date range
  @State private var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
  @State private var endDate: Date = Date()
  
  // 3. Accounts selector
  @State private var selectedAccountIds: Set<String> = []
  private var accountOptions: [BankAccount] { vm.accounts }
  
  // Filtered data
  private var filteredTxns: [PlaidTransaction] {
    vm.transactions.filter { txn in
      // category
      (selectedCategory == "All" || txn.category == selectedCategory)
      // date
      && txn.date >= startDate && txn.date <= endDate
      // account
      && (selectedAccountIds.isEmpty || selectedAccountIds.contains(txn.accountId))
    }
  }
  
  var body: some View {
    ScrollView {
      VStack(spacing: 16) {
        // — Filters
        VStack(spacing: 8) {
          // Category
          Picker("Category", selection: $selectedCategory) {
            ForEach(categories, id: \.self) { Text($0).tag($0) }
          }
          .pickerStyle(.menu)
          
          // Date pickers
          HStack {
            DatePicker("From", selection: $startDate, in: ...endDate, displayedComponents: .date)
            DatePicker("To",   selection: $endDate,   in: startDate..., displayedComponents: .date)
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
                  Text(acct.name)
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
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(.secondarySystemBackground)))
          }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
        .shadow(radius: 1)
        
        // — Chart / Empty state
        if filteredTxns.isEmpty {
          VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
              .font(.largeTitle).opacity(0.3)
            Text("No data for your selection")
              .foregroundColor(.secondary)
          }
          .padding(.top, 50)
        } else {
          // Example: total spent by category pie chart
          Chart {
            ForEach( Dictionary(grouping: filteredTxns, by: \.category).map { ($0.key, $0.value.map(\.amount).reduce(0,+)) }, id: \.0 ) { category, sum in
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
    .onAppear { vm.fetchAllTransactions() }
  }
}
