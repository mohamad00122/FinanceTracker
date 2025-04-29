import Foundation

struct BankAccount: Identifiable, Decodable {
    var id: String            // will be set to the Firestore documentID
    let accessToken: String   // from the “access_token” field

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.accessToken = try container.decode(String.self, forKey: .accessToken)
        self.id = ""         // placeholder; view model will overwrite with docID
    }
}
