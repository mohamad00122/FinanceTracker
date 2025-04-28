import SwiftUI
import Charts

struct SpendingChartView: View {
    let monthlyTotals: [(String, Double)]

    var body: some View {
        let average = monthlyTotals.map { $0.1 }.reduce(0, +) / Double(max(monthlyTotals.count, 1))

        Chart {
            // This Month Line (Orange)
            ForEach(monthlyTotals, id: \.0) { month, total in
                LineMark(
                    x: .value("Month", month),
                    y: .value("Total", total)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color.orange)
                .lineStyle(StrokeStyle(lineWidth: 3))
            }

            // Average Flat Line (Gray)
            if let firstMonth = monthlyTotals.first?.0, let lastMonth = monthlyTotals.last?.0 {
                LineMark(
                    x: .value("Month", firstMonth),
                    y: .value("Average", average)
                )
                .interpolationMethod(.linear)
                .foregroundStyle(Color.gray)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))

                LineMark(
                    x: .value("Month", lastMonth),
                    y: .value("Average", average)
                )
                .interpolationMethod(.linear)
                .foregroundStyle(Color.gray)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6))
        }
        .padding(.top, 10)
    }
}
