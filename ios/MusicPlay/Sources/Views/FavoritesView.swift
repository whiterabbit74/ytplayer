import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var favoritesStore: FavoritesStore
    @State private var showSettings = false
    @Binding var showPlayer: Bool
    @State private var editMode: EditMode = .inactive

    var body: some View {
        NavigationStack {
            List {
                if favoritesStore.isLoading && favoritesStore.favorites.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                } else if favoritesStore.favorites.isEmpty && !favoritesStore.isLoading {
                    ContentUnavailableView("No Favorites", systemImage: "heart", description: Text("Tap the heart icon on any track to add it here"))
                } else {
                    let tracks = favoritesStore.favorites
                    ForEach(tracks) { track in
                        TrackRow(
                            track: track,
                            baseURL: appState.baseURL,
                            downloadsStore: appState.downloadsStore,
                            playlistsStore: appState.playlistsStore,
                            playerStore: appState.playerStore,
                            playerService: appState.playerService,
                            onPlay: {
                                appState.playerService.playTrack(track, context: tracks)
                                showPlayer = true
                            },
                            onAddToQueue: {
                                appState.playerStore.addToQueue(track)
                            },
                            isFavorite: true,
                            isDownloaded: appState.downloadsStore.isDownloaded(id: track.id),
                            downloadProgress: appState.downloadsStore.downloadProgresses[track.id],
                            isFailedDownload: appState.downloadsStore.failedDownloads.contains(track.id),
                            onToggleFavorite: {
                                Task { await favoritesStore.toggleFavorite(track) }
                            },
                            onRemove: {
                                Task { await favoritesStore.toggleFavorite(track) }
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
            .environment(\.editMode, $editMode)
            .listStyle(.plain)
            .safeAreaInset(edge: .bottom) {
                if appState.playerStore.currentTrack != nil {
                    Color.clear.frame(height: 70)
                }
            }
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
