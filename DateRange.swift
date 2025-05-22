// DateRange.swift
import Foundation

enum DateRange: String, CaseIterable, Identifiable {
    case last7Days   = "Last 7d"
    case last30Days  = "30d"
    case monthToDate = "Month to Date"
    case yearToDate  = "Year to Date"
    case custom      = "Custom"

    var id: String { rawValue }
}
