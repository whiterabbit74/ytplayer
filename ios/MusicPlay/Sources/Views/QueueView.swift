import SwiftUI

struct QueueView: View {
    @EnvironmentObject var appState: AppState
    @Binding var showPlayer: Bool
    @State private var editMode: EditMode = .inactive

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(appState.playerStore.queue.enumerated()), id: \.element.id) { index, track in
                    TrackRow(
                        track: track,
                        baseURL: appState.baseURL,
                        onPlay: {
                            appState.playerStore.playFromQueue(index: index)
                            appState.playerService.play(track: track)
                            showPlayer = true
                        },
                        onAddToQueue: {
                            appState.playerStore.removeFromQueue(index: index)
                        },
                        isFavorite: appState.favoritesStore.isFavorite(track.id),
                        onToggleFavorite: {
                            Task { await appState.favoritesStore.toggleFavorite(track) }
                        }
                    )
                }
                .onMove { from, to in
                    appState.playerStore.moveQueue(from: from, to: to)
                }
                .onDelete { indexSet in
                    for idx in indexSet {
                        appState.playerStore.removeFromQueue(index: idx)
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .navigationTitle("Queue")
            .toolbar { EditButton() }
        }
    }
}
