import Foundation

struct PlaidTransaction: Identifiable, Decodable {
    var id = UUID()  // Local-only ID for SwiftUI List
    let name: String
    let amount: Double
    let date: String
    let category: [String]?  // New optional category field

    private enum CodingKeys: String, CodingKey {
        case name, amount, date, category
    }
}
