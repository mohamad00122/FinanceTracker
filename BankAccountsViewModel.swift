import Foundation
import FirebaseAuth
import FirebaseFirestore

class BankAccountsViewModel: ObservableObject {
    @Published var accounts: [BankAccount] = []
    @Published var transactions: [String: [PlaidTransaction]] = [:]
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var uid: String? { Auth.auth().currentUser?.uid }

    init() {
        listenForAccounts()
    }

    func listenForAccounts() {
        guard let uid = uid else {
            print("❌ No user ID found.")
            return
        }

        db.collection("users").document(uid)
            .collection("bank_accounts")
            .addSnapshotListener { snap, err in
                if let err = err {
                    print("❌ Accounts listener error:", err)
                    self.errorMessage = err.localizedDescription
                    return
                }

                let docs = snap?.documents ?? []
                let loaded: [BankAccount] = docs.compactMap { doc in
                    let data = doc.data()
                    guard let token = data["access_token"] as? String else {
                        print("❌ Missing access_token in doc \(doc.documentID)")
                        return nil
                    }
                    return BankAccount(id: doc.documentID, accessToken: token)
                }

                print("🔍 accounts snapshot count:", loaded.count)
                DispatchQueue.main.async {
                    self.accounts = loaded
                    self.fetchAllTransactions()
                }
            }
    }

    func fetchAllTransactions() {
        guard let uid = uid else {
            print("❌ No user ID found.")
            return
        }

        for acct in accounts {
            let txRef = db.collection("users")
                .document(uid)
                .collection("bank_accounts")
                .document(acct.id)
                .collection("transactions")

            txRef.getDocuments { snap, err in
                if let err = err {
                    print("❌ Fetch txns error for \(acct.id):", err)
                    self.errorMessage = err.localizedDescription
                    return
                }

                let txCount = snap?.documents.count ?? 0
                print("📄 txs for", acct.id, ":", txCount)

                self.transactions[acct.id] = snap?.documents.compactMap {
                    try? $0.data(as: PlaidTransaction.self)
                } ?? []
            }
        }
    }
}
