import FirebaseFirestore
import FirebaseAuth

class BankAccountsViewModel: ObservableObject {
    @Published var bankAccounts: [BankAccount] = []

    func fetchBankAccounts() {
        guard let userID = Auth.auth().currentUser?.uid else { return }

        let db = Firestore.firestore()
        let bankAccountsRef = db.collection("users").document(userID).collection("bank_accounts")

        bankAccountsRef.getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching bank accounts: \(error.localizedDescription)")
                return
            }

            guard let documents = snapshot?.documents else { return }

            self.bankAccounts = documents.map { doc in
                let accessToken = doc.data()["access_token"] as? String ?? ""
                return BankAccount(id: doc.documentID, accessToken: accessToken)
            }
        }
    }
}
