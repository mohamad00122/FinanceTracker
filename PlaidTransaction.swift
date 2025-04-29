import Foundation

struct PlaidTransaction: Identifiable, Codable {
    var id: String = ""        // Will be set to the docID
    var accountId: String = "" // Ditto

    let name: String
    let amount: Double
    let date: String
    let category: [String]?

    private enum CodingKeys: String, CodingKey {
        case name, amount, date, category
    }
}
