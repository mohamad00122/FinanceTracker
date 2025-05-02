struct Constants {
    // Use your machine’s LAN IP or ngrok tunnel—no trailing slash
    static let serverBaseURL = "http://192.168.1.80:3001"

    // API route endpoints
    struct Endpoints {
        static let createLinkToken = "\(Constants.serverBaseURL)/api/create_link_token"
        static let exchangePublicToken = "\(Constants.serverBaseURL)/api/exchange_public_token"
        static let transactions = "\(Constants.serverBaseURL)/api/transactions"
    }

    // Key names your API expects
    struct APIKeys {
        static let publicToken = "public_token"
        static let userId      = "userId"
    }
}
