import SwiftUI

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()
                
                Text("MusicPlay")
                    .font(.largeTitle.weight(.bold))
                
                VStack(spacing: 12) {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("emailField")

                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("passwordField")
                }
                .padding(.horizontal, 4)

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
                            .tint(.white)
                    } else {
                        Text("Sign In")
                            .frame(maxWidth: .infinity)
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isLoading || email.isEmpty || password.isEmpty)
                .accessibilityIdentifier("signInButton")

                Spacer()
            }
            .padding(24)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }

    @MainActor
    private func login() async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await appState.apiClient.login(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
            appState.refreshAuthState()
        } catch let apiError as APIErrorResponse {
            errorMessage = apiError.error.message
        } catch {
            errorMessage = "Login failed"
        }
        isLoading = false
    }
}
