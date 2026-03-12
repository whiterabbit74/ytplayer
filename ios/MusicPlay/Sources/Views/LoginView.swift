import SwiftUI

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("MusicPlay")
                    .font(.largeTitle.weight(.bold))

                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("emailField")

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("passwordField")

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }

                Button {
                    Task { await login() }
                } label: {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Sign In")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading || email.isEmpty || password.isEmpty)
                .accessibilityIdentifier("signInButton")

                Spacer()
            }
            .padding(24)
        }
    }

    @MainActor
    private func login() async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await appState.apiClient.login(email: email, password: password)
            appState.refreshAuthState()
        } catch let apiError as APIErrorResponse {
            errorMessage = apiError.error.message
        } catch {
            errorMessage = "Login failed"
        }
        isLoading = false
    }
}
