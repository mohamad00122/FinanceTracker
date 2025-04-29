import Foundation

struct BankAccount: Identifiable, Codable {
    var id: String            // Firestore document ID
    var accessToken: String

    // (Add other fields here if you’ve stored more under each bank_accounts doc)
}
