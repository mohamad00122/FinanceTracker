import UIKit
import LinkKit

class LinkViewController: UIViewController {
    var linkHandler: Handler?

    override func viewDidLoad() {
        super.viewDidLoad()
        fetchLinkToken()
    }

    func fetchLinkToken() {
        let linkToken = "link-sandbox-f5b8c8f9-60a0-4a61-87db-3c5205f95e66" // Replace this every time you generate a new one

        let configuration = LinkTokenConfiguration(token: linkToken) { success in
            print("Successfully linked account: \(success)")

            // Extract public_token
            let publicToken = success.publicToken

            // Send it to your backend
            self.exchangePublicToken(publicToken)
        }

        let result = Plaid.create(configuration)
        switch result {
        case .success(let handler):
            self.linkHandler = handler
            handler.open(presentUsing: .viewController(self))
        case .failure(let error):
            print("Error creating Plaid Link handler: \(error)")
        }
    }

    func exchangePublicToken(_ publicToken: String) {
        guard let url = URL(string: "\(Constants.serverBaseURL)/api/exchange_public_token") else {
            print("Invalid backend URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: String] = ["public_token": publicToken]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Token exchange error:", error)
                return
            }

            guard let data = data else {
                print("No data returned from token exchange")
                return
            }

            do {
                let result = try JSONDecoder().decode([String: String].self, from: data)
                if let accessToken = result["access_token"] {
                    print("Access token received:", accessToken)
                } else {
                    print("Access token missing in response:", result)
                }
            } catch {
                print("Failed to decode token exchange response:", error)
            }
        }.resume()
    }
}
