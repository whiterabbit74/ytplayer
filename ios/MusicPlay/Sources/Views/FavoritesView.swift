import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSettings = false
    @Binding var showPlayer: Bool

    var body: some View {
        NavigationStack {
            List {
                if appState.favoritesStore.isLoading && appState.favoritesStore.favorites.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                } else if appState.favoritesStore.favorites.isEmpty && !appState.favoritesStore.isLoading {
                    ContentUnavailableView("No Favorites", systemImage: "heart", description: Text("Tap the heart icon on any track to add it here"))
                } else {
                    let tracks = appState.favoritesStore.favorites
                    ForEach(tracks) { track in
                        TrackRow(
                            track: track,
                            baseURL: appState.baseURL,
                            onPlay: {
                                // Set all favorites as queue context
                                let index = tracks.firstIndex(of: track) ?? 0
                                appState.playerStore.setQueue(tracks, index: index)
                                appState.playerService.play(track: track)
                                showPlayer = true
                            },
                            onAddToQueue: {
                                appState.playerStore.addToQueue(track)
                            }
                        )
                    }
                    .onDelete { offsets in
                        Task { await appState.favoritesStore.removeFavorite(at: offsets) }
                    }
                    .onMove { source, destination in
                        Task { await appState.favoritesStore.reorderFavorites(from: source, to: destination) }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Favorites")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        if !appState.favoritesStore.favorites.isEmpty {
                            EditButton()
                        }
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gear")
                        }
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(appState)
            }
            .onAppear { Task { await appState.favoritesStore.loadFavorites() } }
        }
    }
}
