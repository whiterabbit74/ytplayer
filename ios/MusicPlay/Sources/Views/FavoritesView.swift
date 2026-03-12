import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSettings = false
    @Binding var showPlayer: Bool

    var body: some View {
        NavigationStack {
            List {
                ForEach(appState.favoritesStore.favorites) { track in
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
                        isFavorite: true,
                        onToggleFavorite: {
                            Task { await appState.favoritesStore.toggleFavorite(track) }
                        }
                    )
                }
            }
            .listStyle(.plain)
            .navigationTitle("Favorites")
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
            .onAppear { Task { await appState.favoritesStore.loadFavorites() } }
        }
    }
}
