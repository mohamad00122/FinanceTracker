import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import LinkKit

class SettingsViewModel: ObservableObject {
    @Published var isUserLoggedIn = false
    @Published var isLoading = false
    @Published var userEmail: String?
    @Published var hasBankAccount: Bool = false

    private var auth = Auth.auth()
    private var db = Firestore.firestore()
    private lazy var functions = Functions.functions()

    init() {
        checkAuthStatus()
        checkBankAccounts()
    }

    func checkAuthStatus() {
        if let user = auth.currentUser {
            isUserLoggedIn = true
            userEmail = user.email
        } else {
            isUserLoggedIn = false
        }
    }

    func refresh() {
        checkAuthStatus()
        checkBankAccounts()
    }

    func signOut() {
        do {
            try auth.signOut()
            isUserLoggedIn = false
            userEmail = nil
            hasBankAccount = false
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }

    func checkBankAccounts() {
        guard let userId = auth.currentUser?.uid else { return }
        db.collection("users").document(userId).collection("bank_accounts").getDocuments { snapshot, error in
            if let error = error {
                print("Error checking bank accounts: \(error)")
                return
            }
            self.hasBankAccount = !(snapshot?.documents.isEmpty ?? true)
        }
    }

    func openPlaidLink() {
        functions.httpsCallable("createLinkToken").call { result, error in
            if let error = error {
                print("Error getting link token: \(error.localizedDescription)")
                return
            }

            guard let data = result?.data as? [String: Any],
                  let linkToken = data["link_token"] as? String else {
                print("Invalid link token response.")
                return
            }

            var config = LinkTokenConfiguration(token: linkToken)

            config.onSuccess = { success in
                print("Plaid Link Success: \(success.publicToken)")
                self.saveAccessToken(publicToken: success.publicToken)
            }

            config.onExit = { exit in
                if let error = exit.error {
                    print("Plaid Link exited with error: \(error.localizedDescription)")
                } else {
                    print("User exited Plaid Link.")
                }
            }

            Plaid.create(configuration: config) { result in
                switch result {
                case .success(let handler):
                    handler.open()
                case .failure(let error):
                    print("Failed to create Plaid Link handler: \(error.localizedDescription)")
                }
            }
        }
    }

    private func saveAccessToken(publicToken: String) {
        guard let userId = auth.currentUser?.uid else { return }

        functions.httpsCallable("exchangePublicToken").call(["public_token": publicToken]) { result, error in
            if let error = error {
                print("Error exchanging public token: \(error.localizedDescription)")
                return
            }

            guard let data = result?.data as? [String: Any],
                  let accessToken = data["access_token"] as? String,
                  let itemId = data["item_id"] as? String else {
                print("Invalid response from token exchange.")
                return
            }

            let accountData: [String: Any] = [
                "access_token": accessToken,
                "item_id": itemId,
                "created_at": Timestamp(date: Date())
            ]

            self.db.collection("users").document(userId).collection("bank_accounts").addDocument(data: accountData) { error in
                if let error = error {
                    print("Error saving access token to Firestore: \(error.localizedDescription)")
                } else {
                    print("Access token saved.")
                    self.hasBankAccount = true
                }
            }
        }
    }
}
