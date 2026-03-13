import SwiftUI

struct PlaylistDetailView: View {
    @ObservedObject var playlistsStore: PlaylistsStore
    @ObservedObject var playerStore: PlayerStore
    @ObservedObject var playerService: PlayerService
    @ObservedObject var downloadsStore: DownloadsStore
    @ObservedObject var favoritesStore: FavoritesStore
    let baseURL: String
    let playlist: Playlist
    @Binding var showPlayer: Bool

    @State private var showRenameAlert = false
    @State private var newName = ""
    @State private var editMode: EditMode = .inactive

    var body: some View {
        List {
            if playlistsStore.isLoading && playlistsStore.activeTracks.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            } else if playlistsStore.activeTracks.isEmpty && !playlistsStore.isLoading {
                ContentUnavailableView("Empty Playlist", systemImage: "music.note.list", description: Text("Add tracks from search"))
            }
            
            ForEach(playlistsStore.activeTracks) { track in
                trackRow(track)
            }
            .onDelete { indexSet in
                for index in indexSet.sorted(by: >) {
                    let t = playlistsStore.activeTracks[index]
                    if let rowId = t.rowId {
                        Task { await playlistsStore.removeTrack(playlistId: playlist.id, trackId: rowId) }
                    }
                }
            }
            .onMove { from, to in
                var updated = playlistsStore.activeTracks
                updated.move(fromOffsets: from, toOffset: to)
                let ids = updated.compactMap { $0.rowId }
                Task { await playlistsStore.reorderTracks(playlistId: playlist.id, trackIds: ids) }
            }
        }
        .environment(\.editMode, $editMode)
        .safeAreaInset(edge: .bottom) {
            if playerStore.currentTrack != nil {
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
                Task { await playlistsStore.renamePlaylist(id: playlist.id, name: trimmed) }
            }
        }
        .onAppear { Task { await playlistsStore.selectPlaylist(id: playlist.id) } }
    }

    @ViewBuilder
    private func trackRow(_ track: Track) -> some View {
        TrackRow(
            track: track,
            baseURL: baseURL,
            downloadsStore: downloadsStore,
            playlistsStore: playlistsStore,
            playerStore: playerStore,
            playerService: playerService,
            onPlay: {
                playerService.playTrack(track, context: playlistsStore.activeTracks)
                showPlayer = true
            },
            onAddToQueue: {
                playerStore.addToQueue(track)
            },
            isFavorite: favoritesStore.isFavorite(track.id),
            onToggleFavorite: {
                Task { await favoritesStore.toggleFavorite(track) }
            },
            onRemove: {
                if let rowId = track.rowId {
                    Task { await playlistsStore.removeTrack(playlistId: playlist.id, trackId: rowId) }
                }
            }
        )
    }
}
