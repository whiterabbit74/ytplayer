import SwiftUI

struct SearchView: View {
    @EnvironmentObject var appState: AppState
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
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "Search songs, artists...")
            .searchSuggestions {
                if !appState.searchStore.suggestions.isEmpty {
                    ForEach(appState.searchStore.suggestions, id: \.self) { suggestion in
                        Text(suggestion)
                            .searchCompletion(suggestion)
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
                    .environmentObject(appState)
            }
            .onChange(of: query) { _, newValue in
                appState.searchStore.fetchSuggestions(query: newValue)
                // Clear results when query is emptied
                if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    appState.searchStore.clearResults()
                }
            }
            .onSubmit(of: .search) {
                appState.searchStore.addRecentSearch(query)
                Task {
                    await appState.searchStore.search(query: query)
                }
            }
            .onAppear { Task { await appState.playlistsStore.loadPlaylists() } }
        }
    }

    @ViewBuilder
    private var resultsList: some View {
        let store = appState.searchStore

        if store.isSearching && store.results.isEmpty {
            // First search — show loading
            Section {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
            }
        } else if store.results.isEmpty && store.hasSearched && !store.isSearching {
            // Search completed but no results
            ContentUnavailableView.search(text: query)
        } else if store.results.isEmpty && !store.hasSearched {
            // Initial state — no search yet
            if !store.recentSearches.isEmpty && query.isEmpty {
                Section {
                    ForEach(store.recentSearches, id: \.self) { recent in
                        Button {
                            query = recent
                            store.addRecentSearch(recent)
                            Task { await store.search(query: recent) }
                        } label: {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundStyle(.secondary)
                                Text(recent)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "arrow.up.left")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Recent Searches")
                        Spacer()
                        Button("Clear") {
                            store.clearRecentSearches()
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            } else {
                ContentUnavailableView("Search YouTube", systemImage: "magnifyingglass", description: Text("Find your favorite music"))
            }
        } else {
            // Show results
            ForEach(store.results) { track in
                trackRow(track)
            }
        }
    }

    @ViewBuilder
    private func trackRow(_ track: Track) -> some View {
        TrackRow(
            track: track,
            baseURL: appState.baseURL,
            onPlay: {
                appState.playerStore.setQueue(appState.searchStore.results, index: appState.searchStore.results.firstIndex(of: track) ?? 0)
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
        .contextMenu {
            ForEach(appState.playlistsStore.playlists) { pl in
                Button("Add to \(pl.name)") {
                    Task { await appState.playlistsStore.addTrack(playlistId: pl.id, track: track) }
                }
            }
        }
    }

    @ViewBuilder
    private var loadMoreButton: some View {
        if appState.searchStore.nextPageToken != nil && !appState.searchStore.results.isEmpty {
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
