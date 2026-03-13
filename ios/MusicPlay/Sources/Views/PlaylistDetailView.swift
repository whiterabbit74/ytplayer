import SwiftUI

struct PlaylistDetailView: View {
    @EnvironmentObject var appState: AppState
    let playlist: Playlist
    @Binding var showPlayer: Bool

    @State private var showRenameAlert = false
    @State private var newName = ""

    var body: some View {
        List {
            if appState.playlistsStore.isLoading && appState.playlistsStore.activeTracks.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            } else if appState.playlistsStore.activeTracks.isEmpty && !appState.playlistsStore.isLoading {
                ContentUnavailableView("Empty Playlist", systemImage: "music.note.list", description: Text("Add tracks from search"))
            }
            
            ForEach(appState.playlistsStore.activeTracks) { track in
                trackRow(track)
            }
            .onDelete { indexSet in
                for index in indexSet.sorted(by: >) {
                    let t = appState.playlistsStore.activeTracks[index]
                    if let rowId = t.rowId {
                        Task { await appState.playlistsStore.removeTrack(playlistId: playlist.id, trackId: rowId) }
                    }
                }
            }
            .onMove { from, to in
                var updated = appState.playlistsStore.activeTracks
                updated.move(fromOffsets: from, toOffset: to)
                let ids = updated.compactMap { $0.rowId }
                Task { await appState.playlistsStore.reorderTracks(playlistId: playlist.id, trackIds: ids) }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if appState.playerStore.currentTrack != nil {
                Color.clear.frame(height: 70)
            }
        }
        .navigationTitle(playlist.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        newName = playlist.name
                        showRenameAlert = true
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Rename Playlist", isPresented: $showRenameAlert) {
            TextField("Playlist name", text: $newName)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                Task { await appState.playlistsStore.renamePlaylist(id: playlist.id, name: trimmed) }
            }
        }
        .onAppear { Task { await appState.playlistsStore.selectPlaylist(id: playlist.id) } }
    }

    @ViewBuilder
    private func trackRow(_ track: Track) -> some View {
        TrackRow(
            track: track,
            baseURL: appState.baseURL,
            onPlay: {
                appState.playerService.playTrack(track, context: appState.playlistsStore.activeTracks)
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
