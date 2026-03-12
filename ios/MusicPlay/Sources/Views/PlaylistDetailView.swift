import SwiftUI

struct PlaylistDetailView: View {
    @EnvironmentObject var appState: AppState
    let playlist: Playlist
    @Binding var showPlayer: Bool

    @State private var editMode: EditMode = .inactive

    var body: some View {
        List {
            if appState.playlistsStore.isLoading && appState.playlistsStore.activeTracks.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }
            
            ForEach(appState.playlistsStore.activeTracks) { track in
                TrackRow(
                    track: track,
                    baseURL: appState.baseURL,
                    onPlay: {
                        appState.playerStore.play(track)
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
            .onDelete { indexSet in
                for index in indexSet {
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
        .environment(\.editMode, $editMode)
        .navigationTitle(playlist.name)
        .toolbar {
            EditButton()
        }
        .onAppear { Task { await appState.playlistsStore.selectPlaylist(id: playlist.id) } }
    }
}
