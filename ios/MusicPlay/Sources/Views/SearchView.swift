import SwiftUI

struct SearchView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismissSearch) private var dismissSearch
    @State private var query = ""
    @State private var showSettings = false
    @Binding var showPlayer: Bool

    var body: some View {
        NavigationStack {
            List {
                resultsList
                loadMoreButton
            }
            .listStyle(.plain)
            .navigationTitle("Search (v1.2.1)")
            .searchable(text: $query, prompt: "Search songs, artists...") {
                ForEach(appState.searchStore.suggestions, id: \.self) { suggestion in
                    Button {
                        query = suggestion
                        Task {
                            await appState.searchStore.search(query: suggestion)
                            dismissSearch()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            Text(suggestion)
                        }
                    }
                }
            }
            .accessibilityIdentifier("searchField")
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
            .onChange(of: query) { _, newValue in
                appState.searchStore.fetchSuggestions(query: newValue)
            }
            .onSubmit(of: .search) {
                Task {
                    await appState.searchStore.search(query: query)
                    dismissSearch()
                }
            }
            .onAppear { Task { await appState.playlistsStore.loadPlaylists() } }
        }
    }

    @ViewBuilder
    private var resultsList: some View {
        if appState.searchStore.isSearching && appState.searchStore.results.isEmpty {
            Section {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
            }
        } else if appState.searchStore.results.isEmpty && !appState.searchStore.isSearching && query.isEmpty {
            ContentUnavailableView("Search YouTube", systemImage: "magnifyingglass", description: Text("Find your favorite music"))
        } else {
            ForEach(appState.searchStore.results) { track in
                TrackRow(track: track, baseURL: appState.baseURL, onPlay: {
                    appState.playerStore.play(track)
                    appState.playerService.play(track: track)
                    showPlayer = true
                }, onAddToQueue: {
                    appState.playerStore.addToQueue(track)
                }, isFavorite: appState.favoritesStore.isFavorite(track.id), onToggleFavorite: {
                    Task { await appState.favoritesStore.toggleFavorite(track) }
                })
                .contextMenu {
                    ForEach(appState.playlistsStore.playlists) { pl in
                        Button("Add to \(pl.name)") {
                            Task { await appState.playlistsStore.addTrack(playlistId: pl.id, track: track) }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var loadMoreButton: some View {
        if appState.searchStore.nextPageToken != nil {
            Button {
                Task { await appState.searchStore.loadMore(query: query) }
            } label: {
                HStack {
                    Spacer()
                    if appState.searchStore.isSearching {
                        ProgressView()
                    } else {
                        Text("Load More")
                    }
                    Spacer()
                }
            }
        }
    }
}
