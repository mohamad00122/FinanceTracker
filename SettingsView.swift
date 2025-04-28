import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SettingsView: View {
    @AppStorage("accessToken") private var accessToken: String = ""
    @State private var linkToken: String = ""
    @State private var isLinkPresented = false
    @State private var errorMessage = ""
    @StateObject private var viewModel = BankAccountsViewModel()

    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
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
                }
                
                Section(header: Text("BANK CONNECTION")) {
                    if viewModel.bankAccounts.isEmpty {
                        Button {
                            fetchLinkToken()
                        } label: {
                            Label("Connect Bank Account", systemImage: "link")
                        }
                    } else {
                        HStack {
                            Label("Bank Account Connected", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                        
                        Button {
                            fetchLinkToken()
                        } label: {
                            Label("Connect Another Bank", systemImage: "link")
                        }
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        logout()
                    } label: {
                        Label("Log Out", systemImage: "arrowshape.turn.up.left")
                    }
                }
                
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
                viewModel.fetchBankAccounts()
            }
            .sheet(isPresented: $isLinkPresented) {
                PlaidLinkView(
                    linkToken: linkToken,
                    onSuccess: { publicToken in
                        exchangePublicToken(publicToken) { token in
                            if let token = token {
                                print("✅ Token exchange + Firestore save success.")
                                self.accessToken = token
                                viewModel.fetchBankAccounts()
                            }
                            isLinkPresented = false
                        }
                    },
                    onExit: { _ in
                        isLinkPresented = false
                    }
                )
            }
        }
    }

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
            if let data = data,
               let result = try? JSONDecoder().decode([String: String].self, from: data),
               let token = result["link_token"] {
                DispatchQueue.main.async {
                    self.linkToken = token
                    self.isLinkPresented = true
                }
            }
        }.resume()
    }

    private func exchangePublicToken(_ publicToken: String, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "\(Constants.serverBaseURL)/api/exchange_public_token"),
              let userId = Auth.auth().currentUser?.uid else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: String] = [
            "public_token": publicToken,
            "user_id": userId
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: request) { data, response, _ in
            if let httpRes = response as? HTTPURLResponse {
                print("HTTP Status Code:", httpRes.statusCode)
            }

            guard let data = data,
                  let result = try? JSONDecoder().decode([String: String].self, from: data),
                  let token = result["access_token"] else {
                print("❌ Token exchange failed or response was invalid.")
                completion(nil)
                return
            }

            print("✅ Access token received: \(token)")
            completion(token)
        }.resume()
    }
}
