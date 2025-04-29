import Foundation
import FirebaseAuth
import FirebaseFirestore

class BankAccountsViewModel: ObservableObject {
    @Published var accounts: [BankAccount] = []
    @Published var transactions: [PlaidTransaction] = []
    @Published var errorMessage: String?

    private let db = Firestore.firestore()

    init() {
        fetchAccounts()
        fetchAllTransactions()
    }

    /// Load all linked accounts under users/{uid}/bank_accounts
    func fetchAccounts() {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "Not signed in"
            return
        }
        let ref = db
            .collection("users").document(uid)
            .collection("bank_accounts")

        ref.getDocuments { snapshot, err in
            if let err = err {
                DispatchQueue.main.async { self.errorMessage = err.localizedDescription }
                return
            }
            let docs = snapshot?.documents ?? []
            var loaded: [BankAccount] = []

            for doc in docs {
                let data = doc.data()
                do {
                    let json = try JSONSerialization.data(withJSONObject: data)
                    var acct = try JSONDecoder().decode(BankAccount.self, from: json)
                    acct.id = doc.documentID
                    loaded.append(acct)
                } catch {
                    DispatchQueue.main.async {
                        self.errorMessage = "Account decode error: \(error.localizedDescription)"
                    }
                }
            }

            DispatchQueue.main.async {
                self.accounts = loaded
            }
        }
    }

    /// Fetch *all* transactions under each bank account
    func fetchAllTransactions() {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "Not signed in"
            return
        }
        let accountsRef = db
            .collection("users").document(uid)
            .collection("bank_accounts")

        accountsRef.getDocuments { acctSnap, acctErr in
            if let acctErr = acctErr {
                DispatchQueue.main.async { self.errorMessage = acctErr.localizedDescription }
                return
            }
            let acctDocs = acctSnap?.documents ?? []
            var allTxns: [PlaidTransaction] = []
            let group = DispatchGroup()

            for acctDoc in acctDocs {
                let acctId = acctDoc.documentID
                let txnsRef = accountsRef
                    .document(acctId)
                    .collection("transactions")

                group.enter()
                txnsRef.getDocuments { txnSnap, txnErr in
                    defer { group.leave() }
                    if let txnErr = txnErr {
                        DispatchQueue.main.async {
                            self.errorMessage = "Error loading txns for \(acctId): \(txnErr)"
                        }
                        return
                    }
                    for doc in txnSnap?.documents ?? [] {
                        let data = doc.data()
                        do {
                            let json = try JSONSerialization.data(withJSONObject: data)
                            var txn = try JSONDecoder().decode(PlaidTransaction.self, from: json)
                            txn.id = doc.documentID
                            txn.accountId = acctId
                            allTxns.append(txn)
                        } catch {
                            DispatchQueue.main.async {
                                self.errorMessage = "Transaction decode error: \(error)"
                            }
                        }
                    }
                }
            }

            group.notify(queue: .main) {
                // sort newest first
                self.transactions = allTxns.sorted { $0.date > $1.date }
            }
        }
    }
}
