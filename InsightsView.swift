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
        return raw.map { (category: $0.category, sum: $0.sum, pct: total > 0 ? $0.sum / total : 0) }
            .sorted { $0.sum > $1.sum }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Filter Card
                    FilterCard(
                        selectedRange: $selectedDateRange,
                        selectedCategory: $selectedCategory,
                        allCategories: ["All"] + vm.uniqueCategories,
                        isCustomDateRange: $isCustomDateRange,
                        customFrom: $customFrom,
                        customTo: $customTo
                    )
                    
                    // Chart with Center Total and Legend
                    if summaryData.isEmpty {
                        EmptyStateView { resetFilters() }
                    } else {
                        DonutChart(data: summaryData, totalAmount: summaryData.map(\.sum).reduce(0, +))
                            .frame(height: 280)
                            .padding(.bottom, 8)
                    }
                }
                .padding()
            }
            .navigationTitle("Insights")
        }
    }
    
    private func resetFilters() {
        selectedCategory = "All"
        selectedDateRange = .last30Days
    }
}

// MARK: - Filter Card

private struct FilterCard: View {
    @Binding var selectedRange: DateRange
    @Binding var selectedCategory: String
    let allCategories: [String]
    
    @Binding var isCustomDateRange: Bool
    @Binding var customFrom: Date
    @Binding var customTo: Date
    
    private var showingPickers: Bool {
        isCustomDateRange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filters").font(.headline)
            
            Picker("", selection: $selectedRange) {
                ForEach(DateRange.allCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            
            // Category chips (two rows)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(allCategories, id: \.self) { category in
                        Chip(title: category, isSelected: category == selectedCategory)
                            .onTapGesture { selectedCategory = category }
                    }
                }
                .padding(.vertical, 4)  // To make the chips less spaced out
            }
            
            // Custom date picker disclosure
            Button(action: { isCustomDateRange.toggle() }) {
                Text("Custom Date Range")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            .padding(.top, 4)
            
            if showingPickers {
                HStack {
                    DatePicker("From", selection: $customFrom, in: ...customTo, displayedComponents: .date)
                    DatePicker("To", selection: $customTo, in: customFrom..., displayedComponents: .date)
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

// MARK: - EmptyStateView

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

// MARK: - Donut Chart

private struct DonutChart: View {
    let data: [(category: String, sum: Double, pct: Double)]
    let totalAmount: Double
    
    private let palette: [String: Color] = [
        "Transfer": .blue,
        "Shops": .green,
        "Travel": .orange,
        "Payment": .purple,
        "Recreation": .red,
        "Food and Drink": .cyan,
        "Uncategorized": .gray
    ]
    
    var body: some View {
        VStack {
            // Center total display
            Text("$\(totalAmount, specifier: "%.2f")")
                .font(.title.bold())
                .padding(.bottom, 8)
            
            // Donut chart
            Chart {
                ForEach(data, id: \.category) { item in
                    SectorMark(
                        angle: .value("Amount", item.sum),
                        innerRadius: .ratio(0.6),
                        angularInset: 1
                    )
                    .foregroundStyle(palette[item.category] ?? .secondary)
                    .annotation(position: .overlay) {
                        if item.pct > 0.05 {
                            Text(item.category)
                                .font(.caption2)
                                .foregroundColor(.white)
                                .rotationEffect(.radians(itemStartAngle(item)) - .degrees(90))
                        }
                    }
                }
            }
            .chartLegend(position: .bottom)
        }
    }
    
    private func itemStartAngle(_ item: (String, Double, Double)) -> Double {
        let priorSum = data
            .prefix { $0.0 != item.0 }
            .map { $0.1 }
            .reduce(0, +)
        let mid = priorSum + item.1 / 2
        let total = data.map { $0.1 }.reduce(0, +)
        return 2 * .pi * (mid / total)
    }
}

// MARK: - DateRange Enum

enum DateRange: String, CaseIterable, Identifiable {
    case last7Days = "Last 7d"
    case last30Days = "30d"
    case monthToDate = "Month to Date"
    case yearToDate = "Year to Date"
    case custom      = "Custom"
    
    var id: String { rawValue }
}
