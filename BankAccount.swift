import Foundation

struct BankAccount: Identifiable {
    let id: String           // Firestore documentID
    let accessToken: String  // from "access_token" field
}
