import Foundation

struct PlaidTransaction: Identifiable, Codable {
    var id: String = ""       // Will be set to the Firestore documentID
    var accountId: String = ""// Will be set to the parent account’s ID

    let name: String
    let amount: Double
    let date: String
    let category: [String]?

    private enum CodingKeys: String, CodingKey {
        case name, amount, date, category
    }
}
