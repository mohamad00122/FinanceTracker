import SwiftUI
import FirebaseAuth

struct RootView: View {
    @State private var isLoggedIn = Auth.auth().currentUser != nil

    var body: some View {
        Group {
            if isLoggedIn {
                MainTabView()  // Switch to tab view
            } else {
                AuthenticationView()
            }
        }
        .onAppear {
            AuthStateObserver.observe()
        }
        .onReceive(NotificationCenter.default.publisher(for: .authStateDidChange)) { _ in
            isLoggedIn = Auth.auth().currentUser != nil
        }
    }
}
