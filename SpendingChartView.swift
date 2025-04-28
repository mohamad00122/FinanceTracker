import SwiftUI
import Charts

struct SpendingChartView: View {
    let monthlyTotals: [(String, Double)]

    var body: some View {
        let average = monthlyTotals.map { $0.1 }.reduce(0, +) / Double(max(monthlyTotals.count, 1))

        Chart {
            spendingLine
            averageLine(average: average)
        }
        .chartYAxis {
            AxisMarks(position: .trailing)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6))
        }
        .padding(.top, 10)
    }

    private var spendingLine: some ChartContent {
        ForEach(monthlyTotals, id: \.0) { month, total in
            LineMark(
                x: .value("Month", month),
                y: .value("Total", total)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(.orange)
            .lineStyle(StrokeStyle(lineWidth: 3))
        }
    }

    private func averageLine(average: Double) -> some ChartContent {
        ForEach(monthlyTotals, id: \.0) { month, _ in
            LineMark(
                x: .value("Month", month),
                y: .value("Average", average)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(.gray)
            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
        }
    }
}
