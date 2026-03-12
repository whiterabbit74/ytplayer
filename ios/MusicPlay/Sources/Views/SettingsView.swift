import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    Text("Email: \(appState.apiClient.accessToken != nil ? "Logged In" : "Not Logged In")")
                        .foregroundStyle(.secondary)
                    
                    Button(role: .destructive) {
                        logout()
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Logout")
                        }
                    }
                }
                
                Section("App Information") {
                    HStack {
                        Text("Server URL")
                        Spacer()
                        Text(appState.baseURL)
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func logout() {
        Task {
            try? await appState.apiClient.logout()
            appState.refreshAuthState()
            dismiss()
        }
    }
}
