import SwiftUI
import Charts    // make sure you have this

struct SpendingChartView: View {
  let monthlyTotals: [(String,Double)]
  let average: Double

  var body: some View {
    Chart {
      // orange line = this month’s data
      ForEach(monthlyTotals, id: \.0) { month, total in
        LineMark(
          x: .value("Month", month),
          y: .value("Spent", total)
        )
        .foregroundStyle(.orange)
        .interpolationMethod(.monotone)
      }

      // grey dotted rule = your overall average
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
  }
}
