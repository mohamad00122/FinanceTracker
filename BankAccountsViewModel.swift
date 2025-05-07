import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
class BankAccountsViewModel: ObservableObject {
    @Published var accounts: [BankAccount] = []
    @Published var transactions: [String: [PlaidTransaction]] = [:]
    @Published var errorMessage: String?

    private let db = Firestore.firestore()

    private var uid: String? {
        Auth.auth().currentUser?.uid
    }

    init() {
        Task {
            await fetchAccounts()
        }
    }

    func fetchAccounts() async {
        guard let uid = uid else {
            print("❌ No user ID found.")
            return
        }

        do {
            let snapshot = try await db.collection("users").document(uid)
                .collection("bank_accounts")
                .getDocuments()

            let loaded: [BankAccount] = snapshot.documents.compactMap { doc in
                let data = doc.data()
                guard let token = data["access_token"] as? String else {
                    print("❌ Missing access_token in doc \(doc.documentID)")
                    return nil
                }
                return BankAccount(id: doc.documentID, accessToken: token)
            }

            print("🔍 accounts snapshot count:", loaded.count)
            self.accounts = loaded
            await fetchAllTransactions()

        } catch {
            print("❌ Accounts fetch error:", error.localizedDescription)
            self.errorMessage = error.localizedDescription
        }
    }

    func fetchAllTransactions() async {
        guard let uid = uid else {
            print("❌ No user ID found.")
            return
        }

        var updated: [String: [PlaidTransaction]] = [:]

        for acct in accounts {
            do {
                let snapshot = try await db.collection("users")
                    .document(uid)
                    .collection("bank_accounts")
                    .document(acct.id)
                    .collection("transactions")
                    .getDocuments()

                let txns = snapshot.documents.compactMap {
                    try? $0.data(as: PlaidTransaction.self)
                }

                print("📄 txs for", acct.id, ":", txns.count)
                updated[acct.id] = txns

            } catch {
                print("❌ Fetch txns error for \(acct.id):", error)
                self.errorMessage = error.localizedDescription
            }
        }

        self.transactions = updated
    }
}
