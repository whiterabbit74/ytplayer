import SwiftUI

struct PlaylistDetailView: View {
    @Environment(\.baseURL) var baseURL
    @ObservedObject var playlistsStore: PlaylistsStore
    @ObservedObject var playerStore: PlayerStore
    @ObservedObject var playerService: PlayerService
    @ObservedObject var downloadsStore: DownloadsStore
    @ObservedObject var favoritesStore: FavoritesStore
    
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
                ContentUnavailableView(
                    "Empty Playlist",
                    systemImage: "music.note.list",
                    description: Text("Add tracks from search")
                )
            }
            
            ForEach(Array(playlistsStore.activeTracks.enumerated()), id: \.element.id) { index, track in
                TrackRow(
                    track: track,
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
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.05), value: playlistsStore.activeTracks)
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
            MiniPlayerSpacer()
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
}
