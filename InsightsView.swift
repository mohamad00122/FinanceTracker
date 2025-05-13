import SwiftUI
import Charts

// Quick‑select date ranges enum
enum DateRange: String, CaseIterable, Identifiable {
    case last7Days = "Last 7d"
    case last30Days = "30d"
    case monthToDate = "Month to Date"
    case yearToDate = "Year to Date"

    var id: String { rawValue }
}

struct InsightsView: View {
    @EnvironmentObject var vm: BankAccountsViewModel

    @State private var selectedDateRange: DateRange = .last30Days
    @State private var selectedCategory = "All"
    @State private var startDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
    @State private var endDate = Date()

    private var categories: [String] {
        let allTxns = vm.transactions.values.flatMap { $0 }
        let cats = allTxns
            .compactMap { $0.category }
            .flatMap { $0 }
        let unique = Array(Set(cats)).sorted()
        return ["All"] + unique
    }

    private var filteredTxns: [PlaidTransaction] {
        let allTxns = vm.transactions.values.flatMap { $0 }
        return allTxns.filter { txn in
            let date = parseDate(txn.date)
            let inCategory = (selectedCategory == "All") || (txn.category?.contains(selectedCategory) ?? false)
            let inDateRange = date >= startDate && date <= endDate
            return inCategory && inDateRange
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    filterSection
                    chartSection
                }
                .padding()
                .navigationTitle("Insights")
            }
        }
    }

    // MARK: - Quick‑Select Date Range Picker
    private var dateRangeSelector: some View {
        Picker("Date Range", selection: $selectedDateRange) {
            ForEach(DateRange.allCases) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal, -16)
        .onChange(of: selectedDateRange) { updateDateRange(for: $0) }
    }

    private func updateDateRange(for range: DateRange) {
        switch range {
        case .last7Days:
            startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
            endDate = Date()
        case .last30Days:
            startDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
            endDate = Date()
        case .monthToDate:
            let comps = Calendar.current.dateComponents([.year, .month], from: Date())
            startDate = Calendar.current.date(from: comps)!
            endDate = Date()
        case .yearToDate:
            let comps = Calendar.current.dateComponents([.year], from: Date())
            startDate = Calendar.current.date(from: comps)!
            endDate = Date()
        }
    }

    // MARK: - Filters Card
    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Filters")
                .font(.headline)
                .padding(.bottom, 4)

            // Quick‑select date ranges
            dateRangeSelector

            // Category chips scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories, id: \.self) { cat in
                        Text(cat)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                selectedCategory == cat ? Color.accentColor.opacity(0.2) : Color(.systemGray5)
                            )
                            .clipShape(Capsule())
                            .onTapGesture { selectedCategory = cat }
                    }
                }
            }

            // Date pickers fallback
            HStack {
                DatePicker("From", selection: $startDate, in: ...endDate, displayedComponents: .date)
                DatePicker("To", selection: $endDate, in: startDate..., displayedComponents: .date)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(32)
        .shadow(radius: 3)
    }

    // MARK: - Chart Section
    private var chartSection: some View {
        GroupBox {
            if filteredTxns.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 40))
                        .opacity(0.3)
                    Text("No data for the selection.")
                        .foregroundColor(.secondary)
                    Button("Reset Filters") { resetFilters() }
                        .font(.footnote)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                let data = summarizedData()
                Chart(data, id: \.category) { item in
                    SectorMark(
                        angle: .value("Amount", item.sum),
                        innerRadius: .ratio(0.5)
                    )
                    .foregroundStyle(by: .value("Category", item.category))
                }
                .chartLegend(position: .bottom)
                .frame(height: 250)
                .padding(.bottom, 8)
            }
        }
        .groupBoxStyle(DefaultGroupBoxStyle())
        .padding(.horizontal, -16)
    }

    // MARK: - Helpers
    private func summarizedData() -> [(category: String, sum: Double)] {
        let grouped = Dictionary(grouping: filteredTxns, by: { $0.category?.first ?? "Uncategorized" })
        return grouped.map { (key, txns) in (category: key, sum: txns.map(\.amount).reduce(0, +)) }
    }

    private func resetFilters() {
        selectedCategory = "All"
        selectedDateRange = .last30Days
        updateDateRange(for: selectedDateRange)
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

struct InsightsView_Previews: PreviewProvider {
    static var previews: some View {
        InsightsView()
            .environmentObject(BankAccountsViewModel())
    }
}
