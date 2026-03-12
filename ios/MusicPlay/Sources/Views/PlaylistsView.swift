import SwiftUI

struct PlaylistsView: View {
    @EnvironmentObject var appState: AppState
    @State private var newName = ""
    @State private var showSettings = false
    @Binding var showPlayer: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack {
                    TextField("New playlist", text: $newName)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        Task {
                            let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                            if trimmed.isEmpty { return }
                            await appState.playlistsStore.createPlaylist(name: trimmed)
                            newName = ""
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
                .padding(.horizontal, 12)

                List {
                    ForEach(appState.playlistsStore.playlists) { pl in
                        NavigationLink(pl.name) {
                            PlaylistDetailView(playlist: pl, showPlayer: $showPlayer)
                        }
                    }
                    .onDelete { idx in
                        for i in idx {
                            let id = appState.playlistsStore.playlists[i].id
                            Task { await appState.playlistsStore.deletePlaylist(id: id) }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Playlists")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .onAppear { Task { await appState.playlistsStore.loadPlaylists() } }
        }
    }
}
