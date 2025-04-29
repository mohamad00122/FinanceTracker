import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SettingsView: View {
    @EnvironmentObject private var viewModel: BankAccountsViewModel
    @AppStorage("accessToken") private var accessToken: String = ""
    @State private var linkToken = ""
    @State private var isLinkPresented = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            List {
                // — User info
                Section {
                    HStack(spacing:12) {
                        Image(systemName:"person.circle.fill")
                            .resizable().frame(width:48,height:48)
                            .foregroundColor(.blue)
                        VStack(alignment:.leading) {
                            Text(Auth.auth().currentUser?.email ?? "Unknown User")
                                .font(.headline)
                            Text("Manage your account")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical,8)
                }

                // — Bank Connection
                Section(header: Text("BANK CONNECTION")) {
                    if viewModel.accounts.isEmpty {
                        Button("Connect Bank Account") { fetchLinkToken() }
                    } else {
                        Label("Bank Account Connected", systemImage:"checkmark.circle.fill")
                            .foregroundColor(.green)
                        Button("Connect Another Bank") { fetchLinkToken() }
                    }
                }

                // — Log out
                Section {
                    Button(role:.destructive, action: logout) {
                        Label("Log Out", systemImage:"arrowshape.turn.up.left")
                    }
                }

                // — Errors
                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage).foregroundColor(.red)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Settings")
            .onAppear { viewModel.fetchAccounts() }
            .sheet(isPresented: $isLinkPresented) {
                PlaidLinkView(
                    linkToken: linkToken,
                    onSuccess: { publicToken in
                        exchangePublicToken(publicToken) { token in
                            if let token = token {
                                self.accessToken = token
                            }
                        }
                    },
                    onExit: { _ in isLinkPresented = false }
                )
            }
        }
    }

    // MARK: – Actions

    private func logout() {
        do { try Auth.auth().signOut() }
        catch { errorMessage = error.localizedDescription }
    }

    private func fetchLinkToken() {
        guard let url = URL(string: "\(Constants.serverBaseURL)/api/create_link_token")
        else { return }
        var req = URLRequest(url:url); req.httpMethod = "POST"
        URLSession.shared.dataTask(with:req) { data,_,_ in
            guard
              let data = data,
              let res = try? JSONDecoder().decode([String:String].self, from:data),
              let token = res["link_token"]
            else { return }
            DispatchQueue.main.async {
                linkToken = token
                isLinkPresented = true
            }
        }.resume()
    }

    private func exchangePublicToken(
        _ publicToken: String,
        completion: @escaping (String?)->Void
    ) {
        guard
          let url = URL(string: "\(Constants.serverBaseURL)/api/exchange_public_token"),
          let userId = Auth.auth().currentUser?.uid
        else {
            completion(nil); return
        }

        var req = URLRequest(url:url); req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField:"Content-Type")
        req.httpBody = try? JSONSerialization.data(
          withJSONObject: ["public_token":publicToken, "user_id":userId]
        )

        URLSession.shared.dataTask(with:req) { data,_,_ in
            guard
              let data = data,
              let res = try? JSONDecoder().decode([String:String].self, from:data),
              let token = res["access_token"]
            else {
                completion(nil)
                return
            }

            // Persist the account under snake_case key
            let db = Firestore.firestore()
            let acctRef = db
              .collection("users").document(userId)
              .collection("bank_accounts").document("primary")

            acctRef.setData([
              "access_token": token,
              "linkedAt": Timestamp(date: Date())
            ]) { err in
                DispatchQueue.main.async {
                    if let err = err {
                        errorMessage = err.localizedDescription
                    } else {
                        // reload both accounts & transactions
                        viewModel.fetchAccounts()
                        viewModel.fetchAllTransactions()
                    }
                    isLinkPresented = false
                }
            }

            completion(token)
        }.resume()
    }
}
