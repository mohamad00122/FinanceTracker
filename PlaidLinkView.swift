import SwiftUI
import LinkKit

struct PlaidLinkView: UIViewControllerRepresentable {
    let linkToken: String
    let onSuccess: (String) -> Void
    let onExit: (Error?) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        return PlaidLinkHostingViewController(linkToken: linkToken,
                                              onSuccess: onSuccess,
                                              onExit: onExit)
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

class PlaidLinkHostingViewController: UIViewController {
    let linkToken: String
    let onSuccess: (String) -> Void
    let onExit: (Error?) -> Void
    var linkHandler: Handler?

    init(linkToken: String, onSuccess: @escaping (String) -> Void, onExit: @escaping (Error?) -> Void) {
        self.linkToken = linkToken
        self.onSuccess = onSuccess
        self.onExit = onExit
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presentPlaidLink()
    }

    private func presentPlaidLink() {
        let config = LinkTokenConfiguration(token: linkToken) { success in
            self.onSuccess(success.publicToken)
        }

        let result = Plaid.create(config)
        switch result {
        case .success(let handler):
            self.linkHandler = handler
            handler.open(presentUsing: .viewController(self))
        case .failure(let error):
            self.onExit(error)
        }
    }
}
