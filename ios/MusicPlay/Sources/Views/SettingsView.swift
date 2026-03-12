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
                
                Section("Playback") {
                    Picker("Audio Quality", selection: Binding(
                        get: { appState.audioQuality },
                        set: { appState.updateAudioQuality($0) }
                    )) {
                        Text("High (Best m4a)").tag("high")
                        Text("Low (Data saver)").tag("low")
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
            // Stop player and sync
            appState.playerSyncService.stop()
            appState.playerService.stop()
            appState.playerStore.clearQueue()
            
            try? await appState.apiClient.logout()
            await MainActor.run {
                appState.refreshAuthState()
                dismiss()
            }
        }
    }
}
