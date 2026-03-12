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
                    NavigationLink {
                        DownloadsView(showPlayer: $showPlayer)
                    } label: {
                        Label("Downloads", systemImage: "arrow.down.circle")
                            .font(.headline)
                    }

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
                    .environmentObject(appState)
            }
            .onAppear { Task { await appState.playlistsStore.loadPlaylists() } }
        }
    }
}

struct DownloadsView: View {
    @EnvironmentObject var appState: AppState
    @Binding var showPlayer: Bool

    var body: some View {
        List {
            if appState.downloadsStore.downloadedTracks.isEmpty {
                ContentUnavailableView("No Downloads", systemImage: "arrow.down.to.line.circle", description: Text("Download tracks to listen offline"))
            }

            ForEach(appState.downloadsStore.downloadedTracks) { track in
                trackRow(track)
            }
            .onDelete { indexSet in
                for index in indexSet.sorted(by: >) {
                    let t = appState.downloadsStore.downloadedTracks[index]
                    appState.downloadsStore.removeTrack(t.id)
                    AudioCacheService.shared.removeTrack(id: t.id)
                }
            }
            .onMove { from, to in
                appState.downloadsStore.moveTracks(from: from, to: to)
            }
        }
        .navigationTitle("Downloads")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
    }

    @ViewBuilder
    private func trackRow(_ track: Track) -> some View {
        TrackRow(
            track: track,
            baseURL: appState.baseURL,
            onPlay: {
                let tracks = appState.downloadsStore.downloadedTracks
                let index = tracks.firstIndex(of: track) ?? 0
                appState.playerStore.setQueue(tracks, index: index)
                appState.playerService.play(track: track)
                showPlayer = true
            },
            onAddToQueue: {
                appState.playerStore.addToQueue(track)
            },
            isFavorite: appState.favoritesStore.isFavorite(track.id),
            onToggleFavorite: {
                Task { await appState.favoritesStore.toggleFavorite(track) }
            }
        )
    }
}
