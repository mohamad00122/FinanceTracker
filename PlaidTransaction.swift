import Foundation

struct PlaidTransaction: Identifiable, Codable, Equatable {
    var id: String = ""        // Will be set to the docID
    var accountId: String = "" // Ditto

    let name: String
    let amount: Double
    let date: String
    let category: [String]?

    private enum CodingKeys: String, CodingKey {
        case name, amount, date, category
    }

    // Optional: Custom Equatable implementation (only needed if needed to skip id/accountId)
    static func == (lhs: PlaidTransaction, rhs: PlaidTransaction) -> Bool {
        return lhs.name == rhs.name &&
               lhs.amount == rhs.amount &&
               lhs.date == rhs.date &&
               lhs.category == rhs.category
    }
}
