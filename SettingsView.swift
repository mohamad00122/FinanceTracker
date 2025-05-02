import SwiftUI
import FirebaseAuth

// MARK: – Decode structs for your API
struct LinkTokenResponse: Decodable {
    let link_token: String
}

struct ExchangeResponse: Decodable {
    let item_id: String
    let access_token: String
    let transactionCount: Int
}

struct SettingsView: View {
    @EnvironmentObject private var viewModel: BankAccountsViewModel
    @State private var linkToken = ""
    @State private var isLinkPresented = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            List {
                // — User info
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
                        Button("Connect Bank Account") {
                            fetchLinkToken()
                        }
                    } else {
                        Label("Bank Account Connected", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Button("Connect Another Bank") {
                            fetchLinkToken()
                        }
                    }
                }

                // — Log out
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
            .sheet(isPresented: $isLinkPresented) {
                PlaidLinkView(
                    linkToken: linkToken,
                    onSuccess: { publicToken in
                        print("✅ Got public token:", publicToken)
                        exchangePublicToken(publicToken)
                    },
                    onExit: { _ in
                        isLinkPresented = false
                    }
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
        var req = URLRequest(url: url)
        req.httpMethod = "POST"

        URLSession.shared.dataTask(with: req) { data, _, err in
            if let err = err {
                print("❌ Link token fetch error:", err)
                return
            }
            guard
                let data = data,
                let resp = try? JSONDecoder().decode(LinkTokenResponse.self, from: data)
            else { return }

            DispatchQueue.main.async {
                linkToken = resp.link_token
                isLinkPresented = true
            }
        }.resume()
    }

    private func exchangePublicToken(_ publicToken: String) {
        guard
            let url = URL(string: "\(Constants.serverBaseURL)/api/exchange_public_token"),
            let userId = Auth.auth().currentUser?.uid
        else {
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "public_token": publicToken,
            "userId": userId
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { data, _, err in
            if let err = err {
                print("❌ Exchange request error:", err)
                DispatchQueue.main.async {
                    errorMessage = err.localizedDescription
                    isLinkPresented = false
                }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async {
                    errorMessage = "No data from exchange"
                    isLinkPresented = false
                }
                return
            }
            do {
                let exchange = try JSONDecoder().decode(ExchangeResponse.self, from: data)
                print("✅ Exchange success:", exchange)
                DispatchQueue.main.async {
                    isLinkPresented = false
                }
            } catch {
                print("❌ Exchange decode error:", error)
                DispatchQueue.main.async {
                    errorMessage = error.localizedDescription
                    isLinkPresented = false
                }
            }
        }.resume()
    }
}
