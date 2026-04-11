import AuthenticationServices
import SwiftUI

struct LoginView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isSigningIn = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.systemBackground), Color.green.opacity(0.12)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Branding
                VStack(spacing: 16) {
                    Image(systemName: "figure.run.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.green.gradient)

                    Text("Dashboard Fitness")
                        .font(.system(size: 28, weight: .bold, design: .rounded))

                    Text("Protocols, training & daily habits\nin one place.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                // Sign in
                VStack(spacing: 20) {
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }

                    if isSigningIn {
                        ProgressView("Signing in...")
                            .font(.subheadline)
                    } else {
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            handleSignIn(result)
                        }
                        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                        .frame(height: 50)
                        .frame(maxWidth: 280)
                    }
                }

                Spacer()
                    .frame(height: 80)
            }
            .padding()
        }
    }

    private func handleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            isSigningIn = true
            errorMessage = nil
            Task {
                do {
                    try await AuthService.shared.signInWithApple(authorization: authorization)
                } catch {
                    errorMessage = error.localizedDescription
                }
                isSigningIn = false
            }
        case .failure(let error):
            // Don't show error for user cancellation
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    LoginView()
}
