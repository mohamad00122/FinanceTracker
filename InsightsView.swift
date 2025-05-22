import SwiftUI
import Charts

struct InsightsView: View {
    @EnvironmentObject private var vm: BankAccountsViewModel

    @State private var selectedDateRange: DateRange = .last30Days
    @State private var selectedCategory: String = "All"
    @State private var isCustomDateRange: Bool = false
    @State private var customFrom: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
    @State private var customTo: Date = Date()

    private var filteredTxns: [PlaidTransaction] {
        vm.transactions(for: selectedDateRange, category: selectedCategory)
    }

    private var summaryData: [(category: String, sum: Double, pct: Double)] {
        let raw = vm.summarize(transactions: filteredTxns)
        let total = raw.map(\.sum).reduce(0, +)
        return raw
          .map { (category: $0.category, sum: $0.sum, pct: total > 0 ? $0.sum / total : 0) }
          .sorted { $0.sum > $1.sum }
    }

    private var averageDaily: Double {
        let dayCount = Calendar.current.dateComponents([.day], from: customFrom, to: customTo).day.map { Double(max($0, 1)) } ?? 30
        let total = summaryData.map(\.sum).reduce(0, +)
        return total / dayCount
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    // 1️⃣ Filters
                    FilterCard(
                        selectedRange: $selectedDateRange,
                        selectedCategory: $selectedCategory,
                        allCategories: ["All"] + vm.uniqueCategories,
                        isCustomDateRange: $isCustomDateRange,
                        customFrom: $customFrom,
                        customTo: $customTo
                    )

                    // 2️⃣ Metric Cards
                    HStack(spacing: 16) {
                        MetricCard(
                            title: "Total Spent",
                            value: summaryData.map(\.sum).reduce(0, +),
                            formatter: { Text($0, format: .currency(code: "USD")) }
                        )
                        MetricCard(
                            title: "Avg / Day",
                            value: averageDaily,
                            formatter: { Text($0, format: .currency(code: "USD")) }
                        )
                    }
                    .padding(.horizontal)

                    // 3️⃣ Chart + Breakdown
                    if summaryData.isEmpty {
                        EmptyStateView { resetFilters() }
                    } else {
                        VStack(spacing: 16) {
                            Card {
                                Chart {
                                    ForEach(summaryData, id: \.category) { item in
                                        SectorMark(
                                            angle: .value("Amount", item.sum),
                                            innerRadius: .ratio(0.6),
                                            angularInset: 1
                                        )
                                        .foregroundStyle(color(for: item.category))
                                    }
                                }
                                .chartLegend(.hidden)
                                .frame(height: 240)
                            }

                            VStack(spacing: 0) {
                                ForEach(summaryData, id: \.category) { item in
                                    HStack {
                                        Circle()
                                            .fill(color(for: item.category))
                                            .frame(width: 12, height: 12)
                                        Text(item.category)
                                            .font(.subheadline)
                                        Spacer()
                                        Text(item.sum, format: .currency(code: "USD"))
                                            .font(.subheadline.weight(.semibold))
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal)
                                    if item.category != summaryData.last?.category {
                                        Divider().padding(.leading, 28)
                                    }
                                }
                            }
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Insights")
        }
    }

    private func resetFilters() {
        selectedCategory = "All"
        selectedDateRange = .last30Days
    }

    private func color(for category: String) -> Color {
        let palette: [String: Color] = [
            "Transfer": .blue,
            "Shops": .green,
            "Travel": .orange,
            "Payment": .purple,
            "Recreation": .red,
            "Food and Drink": .cyan,
            "Uncategorized": .gray
        ]
        return palette[category] ?? .secondary
    }
}

// MARK: – FilterCard + Chip

private struct FilterCard: View {
    @Binding var selectedRange: DateRange
    @Binding var selectedCategory: String
    let allCategories: [String]

    @Binding var isCustomDateRange: Bool
    @Binding var customFrom: Date
    @Binding var customTo: Date

    private var showingPickers: Bool { isCustomDateRange }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filters").font(.headline)

            Picker("", selection: $selectedRange) {
                ForEach(DateRange.allCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(allCategories, id: \.self) { category in
                        Chip(title: category, isSelected: category == selectedCategory)
                            .onTapGesture { selectedCategory = category }
                    }
                }
                .padding(.vertical, 4)
            }

            Button { isCustomDateRange.toggle() } label: {
                Text("Custom Date Range")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            .padding(.top, 4)

            if showingPickers {
                HStack {
                    DatePicker("From", selection: $customFrom, in: ...customTo, displayedComponents: .date)
                    DatePicker("To",   selection: $customTo, in: customFrom..., displayedComponents: .date)
                }
                .padding(.top, 12)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

private struct Chip: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        Text(title)
            .font(.subheadline)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(
                Capsule()
                    .fill(isSelected
                          ? Color.accentColor.opacity(0.2)
                          : Color(.systemGray5))
            )
    }
}

// MARK: – EmptyStateView

private struct EmptyStateView: View {
    var onReset: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.pie.fill")
                .font(.system(size: 40))
                .opacity(0.3)
            Text("No data for the selection.")
                .foregroundColor(.secondary)
            Button("Reset Filters", action: onReset)
                .font(.footnote)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

// MARK: – MetricCard + Card

private struct MetricCard<Value>: View where Value: BinaryFloatingPoint {
    let title: String
    let value: Value
    let formatter: (Value) -> Text

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            formatter(value)
                .font(.title3.weight(.bold))
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
}

private struct Card<Content: View>: View {
    let content: Content
    init(@ViewBuilder _ content: () -> Content) {
        self.content = content()
    }
    var body: some View {
        content
            .padding(.vertical)
            .padding(.horizontal, 16)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}
