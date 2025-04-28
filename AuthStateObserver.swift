import Foundation
import FirebaseAuth

extension Notification.Name {
    static let authStateDidChange = Notification.Name("authStateDidChange")
}

class AuthStateObserver {
    private static var handle: AuthStateDidChangeListenerHandle?

    static func observe() {
        handle = Auth.auth().addStateDidChangeListener { _, _ in
            NotificationCenter.default.post(name: .authStateDidChange, object: nil)
        }
    }

    static func stopObserving() {
        if let handle = handle {
            Auth.auth().removeStateDidChangeListener(handle)
            self.handle = nil
        }
    }
}
