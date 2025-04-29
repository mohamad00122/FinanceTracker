import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SettingsView: View {
    @EnvironmentObject private var viewModel: BankAccountsViewModel
    @AppStorage("accessToken") private var accessToken: String = ""
    @State private var linkToken: String = ""
    @State private var isLinkPresented = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            List {
                // — User Info
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 48, height: 48)
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text(Auth.auth().currentUser?.email ?? "Unknown User")
                                .font(.headline)
                            Text("Manage your account")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // — Bank Connection
                Section(header: Text("BANK CONNECTION")) {
                    if viewModel.accounts.isEmpty {
                        Button {
                            fetchLinkToken()
                        } label: {
                            Label("Connect Bank Account", systemImage: "link")
                        }
                    } else {
                        Label("Bank Account Connected", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        
                        Button {
                            fetchLinkToken()
                        } label: {
                            Label("Connect Another Bank", systemImage: "link")
                        }
                    }
                }
                
                // — Logout
                Section {
                    Button(role: .destructive) {
                        logout()
                    } label: {
                        Label("Log Out", systemImage: "arrowshape.turn.up.left")
                    }
                }
                
                // — Errors
                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Settings")
            .onAppear {
                viewModel.fetchAccounts()
            }
            .sheet(isPresented: $isLinkPresented) {
                PlaidLinkView(
                    linkToken: linkToken,
                    onSuccess: { publicToken in
                        exchangePublicToken(publicToken) { token in
                            if let token = token {
                                // save and refresh
                                self.accessToken = token
                                viewModel.fetchAccounts()
                            }
                            isLinkPresented = false
                        }
                    },
                    onExit: { _ in isLinkPresented = false }
                )
            }
        }
    }
    
    // MARK: – Actions
    
    private func logout() {
        do {
            try Auth.auth().signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func fetchLinkToken() {
        guard let url = URL(string: "\(Constants.serverBaseURL)/api/create_link_token") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard
                let data = data,
                let result = try? JSONDecoder().decode([String: String].self, from: data),
                let token = result["link_token"]
            else { return }
            
            DispatchQueue.main.async {
                self.linkToken = token
                self.isLinkPresented = true
            }
        }
        .resume()
    }
    
    private func exchangePublicToken(_ publicToken: String, completion: @escaping (String?) -> Void) {
        guard
            let url = URL(string: "\(Constants.serverBaseURL)/api/exchange_public_token"),
            let userId = Auth.auth().currentUser?.uid
        else {
            completion(nil); return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "public_token": publicToken,
            "user_id": userId
        ])
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard
                let data = data,
                let result = try? JSONDecoder().decode([String:String].self, from: data),
                let token = result["access_token"]
            else {
                completion(nil); return
            }
            
            // **Persist the new bank account in Firestore**
            let db = Firestore.firestore()
            let acctRef = db
                .collection("users")
                .document(userId)
                .collection("bank_accounts")
                .document("primary")   // you can generate an ID or use "primary"
            acctRef.setData([
                "accessToken": token,
                "linkedAt": Timestamp(date: Date())
            ]) { err in
                DispatchQueue.main.async {
                    if let err = err {
                        print("Firestore write failed:", err)
                    } else {
                        print("✅ BankAccount saved in Firestore")
                        self.accessToken = token
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
