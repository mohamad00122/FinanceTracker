// BankAccountsViewModel.swift

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

    // MARK: – Load linked accounts
    func fetchAccounts() {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "Not signed in"
            return
        }
        let ref = db
            .collection("users")
            .document(uid)
            .collection("bank_accounts")

        ref.getDocuments { snapshot, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                }
                return
            }
            let docs = snapshot?.documents ?? []
            var loaded: [BankAccount] = []

            for doc in docs {
                let data = doc.data()
                do {
                    // 1) Turn the [String:Any] into JSON Data
                    let jsonData = try JSONSerialization.data(
                        withJSONObject: data,
                        options: []
                    )
                    // 2) Decode into your Codable model
                    var acct = try JSONDecoder().decode(BankAccount.self, from: jsonData)
                    // 3) Assign the documentID if your model has an `id` property
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

    // MARK: – Fetch *all* transactions under each account
    func fetchAllTransactions() {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "Not signed in"
            return
        }

        let accountsRef = db
            .collection("users")
            .document(uid)
            .collection("bank_accounts")

        accountsRef.getDocuments { acctSnap, acctErr in
            if let acctErr = acctErr {
                DispatchQueue.main.async {
                    self.errorMessage = acctErr.localizedDescription
                }
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
                            self.errorMessage = "Error loading txns for \(acctId): \(txnErr.localizedDescription)"
                        }
                        return
                    }

                    for doc in txnSnap?.documents ?? [] {
                        let data = doc.data()
                        do {
                            let jsonData = try JSONSerialization.data(withJSONObject: data, options: [])
                            var txn = try JSONDecoder().decode(PlaidTransaction.self, from: jsonData)
                            txn.id = doc.documentID
                            txn.accountId = acctId
                            allTxns.append(txn)
                        } catch {
                            DispatchQueue.main.async {
                                self.errorMessage = "Transaction decode error: \(error.localizedDescription)"
                            }
                        }
                    }
                }
            }

            group.notify(queue: .main) {
                // sort most recent first
                self.transactions = allTxns.sorted { $0.date > $1.date }
            }
        }
    }
}

