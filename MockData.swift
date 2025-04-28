//
//  MockData.swift
//  FinanceTracker
//
//  This file provides sample transaction data for testing
//

import Foundation
import LinkKit

// A simple model representing a bank transaction.
struct Transaction: Identifiable {
    let id = UUID()
    let date: Date
    let amount: Double
}

// A model for monthly spending, used for the chart.
struct MonthlySpending: Identifiable {
    let id = UUID()
    let month: String  // e.g., "Jan", "Feb"
    let amount: Double
}

// Function to simulate fetching transactions for the past few months.
func fetchMockTransactions() -> [Transaction] {
    let calendar = Calendar.current
    var transactions: [Transaction] = []
    
    // Create transactions for the current month and previous 5 months.
    for monthOffset in 0..<6 {
        // Simulate a spending record on the 15th of each month.
        if let date = calendar.date(byAdding: .month, value: -monthOffset, to: Date()) {
            // Simulate spending amounts with random numbers
            let amount = Double.random(in: 500...1500)
            transactions.append(Transaction(date: date, amount: amount))
        }
    }
    return transactions
}

// Function to group transactions by month and calculate spending totals
func calculateMonthlySpend(from transactions: [Transaction]) -> [MonthlySpending] {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "MMM"
    
    var monthlySpend: [String: Double] = [:]
    
    for transaction in transactions {
        let month = dateFormatter.string(from: transaction.date)
        monthlySpend[month, default: 0] += transaction.amount
    }
    
    // Sort months by order (optional: you may want to sort chronologically)
    let sortedKeys = monthlySpend.keys.sorted { key1, key2 in
        dateFormatter.date(from: key1) ?? Date() < dateFormatter.date(from: key2) ?? Date()
    }
    
    return sortedKeys.map { MonthlySpending(month: $0, amount: monthlySpend[$0]!) }
}
