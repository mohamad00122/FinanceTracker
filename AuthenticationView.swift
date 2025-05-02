import SwiftUI
import FirebaseAuth

struct AuthenticationView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var isLogin = true
    @State private var isLoading = false
    @Namespace private var animation

    var body: some View {
        ZStack {
            // Background
            LinearGradient(colors: [Color.black, Color.gray.opacity(0.2)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 40)

                    // App Title with Icon
                    HStack(spacing: 8) {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 34))
                            .foregroundColor(.green)

                        Text("Spendr")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                    .padding(.bottom, 12)

                    // Auth Toggle
                    HStack {
                        Button("Login") {
                            withAnimation { isLogin = true }
                        }
                        .foregroundColor(isLogin ? .white : .gray)
                        .fontWeight(isLogin ? .bold : .regular)
                        .padding(.horizontal)

                        Button("Register") {
                            withAnimation { isLogin = false }
                        }
                        .foregroundColor(!isLogin ? .white : .gray)
                        .fontWeight(!isLogin ? .bold : .regular)
                        .padding(.horizontal)
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
                    .padding(.bottom, 12)

                    // Form
                    VStack(spacing: 16) {
                        // Email Field
                        HStack {
                            Image(systemName: "envelope")
                            TextField("Email", text: $email)
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .autocapitalization(.none)
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)

                        // Password Field
                        HStack {
                            Image(systemName: "lock")
                            SecureField("Password", text: $password)
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)

                        // Error Message
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.footnote)
                                .multilineTextAlignment(.center)
                                .transition(.opacity)
                        }

                        // Submit Button
                        Button(action: {
                            authenticate()
                        }) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .padding()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text(isLogin ? "Login" : "Register")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            }
                        }
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .scaleEffect(isLoading ? 0.98 : 1)
                        .animation(.spring(), value: isLoading)

                        // Secure label
                        Label("Secure authentication via Firebase", systemImage: "lock.fill")
                            .font(.footnote)
                            .foregroundColor(.gray)
                            .padding(.top, 4)
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)
                    .padding(.horizontal)

                    Spacer()
                }
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: – Auth Logic
    private func authenticate() {
        errorMessage = ""
        isLoading = true

        if isLogin {
            Auth.auth().signIn(withEmail: email, password: password) { result, error in
                DispatchQueue.main.async {
                    isLoading = false
                    if let error = error {
                        withAnimation {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
            }
        } else {
            Auth.auth().createUser(withEmail: email, password: password) { result, error in
                DispatchQueue.main.async {
                    isLoading = false
                    if let error = error {
                        withAnimation {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
            }
        }
    }
}
