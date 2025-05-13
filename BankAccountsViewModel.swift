import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
class BankAccountsViewModel: ObservableObject {
    @Published var accounts: [BankAccount] = []
    @Published var transactions: [String: [PlaidTransaction]] = [:]
    @Published var errorMessage: String?

    private let db = Firestore.firestore()

    private var uid: String? {
        Auth.auth().currentUser?.uid
    }

    init() {
        Task { await fetchAccounts() }
    }

    func fetchAccounts() async {
        guard let uid = uid else { return }
        do {
            let snapshot = try await db.collection("users").document(uid)
                .collection("bank_accounts").getDocuments()

            let loaded: [BankAccount] = snapshot.documents.compactMap { doc in
                let data = doc.data()
                guard let token = data["access_token"] as? String else { return nil }
                return BankAccount(id: doc.documentID, accessToken: token)
            }

            self.accounts = loaded
            await fetchAllTransactions()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func fetchAllTransactions() async {
        guard let uid = uid else { return }
        var updated: [String: [PlaidTransaction]] = [:]

        for acct in accounts {
            do {
                let snapshot = try await db.collection("users").document(uid)
                    .collection("bank_accounts").document(acct.id)
                    .collection("transactions").getDocuments()

                let txns = snapshot.documents.compactMap {
                    try? $0.data(as: PlaidTransaction.self)
                }
                updated[acct.id] = txns
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }

        self.transactions = updated
    }

    // MARK: - Data Helpers

    /// Summarize a flat list of transactions into (category, sum)
    func summarize(transactions: [PlaidTransaction]) -> [(category: String, sum: Double)] {
        let grouped = Dictionary(grouping: transactions, by: { $0.category?.first ?? "Uncategorized" })
        return grouped.map { key, txns in
            (category: key, sum: txns.map { $0.amount }.reduce(0, +))
        }
    }

    /// All unique categories across every account
    var uniqueCategories: [String] {
        let allTxns = transactions.values.flatMap { $0 }
        let cats = allTxns.flatMap { $0.category ?? [] }
        return Array(Set(cats)).sorted()
    }

    /// Filter transactions by quick-select range & category
    func transactions(
        for range: DateRange,
        category: String
    ) -> [PlaidTransaction] {
        let all = transactions.values.flatMap { $0 }
        let now = Date()
        let start: Date
        switch range {
        case .last7Days:
            start = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        case .last30Days:
            start = Calendar.current.date(byAdding: .day, value: -30, to: now)!
        case .monthToDate:
            let comps = Calendar.current.dateComponents([.year, .month], from: now)
            start = Calendar.current.date(from: comps)!
        case .yearToDate:
            let comps = Calendar.current.dateComponents([.year], from: now)
            start = Calendar.current.date(from: comps)!
        case .custom:
            start = Calendar.current.date(byAdding: .day, value: -30, to: now)!
        }
        let dateFiltered = all.filter {
            let d = parseDate($0.date)
            return d >= start && d <= now
        }
        if category == "All" {
            return dateFiltered
        } else {
            return dateFiltered.filter { $0.category?.contains(category) ?? false }
        }
    }

    /// Parse ISO or yyyy-MM-dd string dates
    private func parseDate(_ s: String) -> Date {
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: s) { return d }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f.date(from: s) ?? Date()
    }
}
