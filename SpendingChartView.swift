import SwiftUI
import Charts

struct SpendingChartView: View {
    let monthlyTotals: [(String, Double)]
    let average: Double
    @State private var animate = false

    var body: some View {
        Chart {
            ForEach(monthlyTotals, id: \.0) { month, total in
                LineMark(
                    x: .value("Month", month),
                    y: .value("Spent", total)
                )
                .foregroundStyle(.orange)
                .interpolationMethod(.monotone)
            }

            RuleMark(y: .value("Average", average))
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
                .foregroundStyle(.gray)
        }
        .chartXAxis {
            AxisMarks(values: monthlyTotals.map { $0.0 })
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .opacity(animate ? 1 : 0)
        .scaleEffect(animate ? 1 : 0.97)
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                animate = true
            }
        }
    }
}
