import SwiftUI

struct SearchView: View {
    @ObservedObject var searchStore: SearchStore
    @ObservedObject var playlistsStore: PlaylistsStore
    @ObservedObject var playerStore: PlayerStore
    @ObservedObject var playerService: PlayerService
    @ObservedObject var downloadsStore: DownloadsStore
    @ObservedObject var favoritesStore: FavoritesStore
    let baseURL: String
    @Binding var showPlayer: Bool
    @State private var query = ""
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            List {
                errorSection
                resultsList
                loadMoreButton
            }
            .listStyle(.plain)
            .safeAreaInset(edge: .bottom) {
                if playerStore.currentTrack != nil {
                    Color.clear.frame(height: 70)
                }
            }
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "Search songs, artists...")
            .searchSuggestions {
                if !searchStore.suggestions.isEmpty {
                    Section("Suggestions") {
                        ForEach(searchStore.suggestions, id: \.self) { suggestion in
                            Text(suggestion)
                                .searchCompletion(suggestion)
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
                    .environmentObject(searchStore) // Pass something if needed, but SettingsView likely still needs AppState
            }
            .onChange(of: query) { _, newValue in
                searchStore.fetchSuggestions(query: newValue)
                // Clear results when query is emptied
                if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    searchStore.clearResults()
                }
            }
            .onSubmit(of: .search) {
                searchStore.addRecentSearch(query)
                Task {
                    await searchStore.search(query: query)
                }
            }
            .onAppear { Task { await playlistsStore.loadPlaylists() } }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ResetSearch"))) { _ in
                query = ""
                searchStore.clearResults()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PerformSearch"))) { note in
                if let artist = note.object as? String {
                    query = artist
                    searchStore.addRecentSearch(artist)
                    Task {
                        await searchStore.search(query: artist)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var resultsList: some View {
        let store = searchStore

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
        } else if store.results.isEmpty && !query.isEmpty && !store.isSearching {
            ContentUnavailableView.search(text: query)
        } else if store.results.isEmpty {
            // Show recent searches if idle
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
                .onDelete { indexSet in
                    for index in indexSet {
                        let q = store.recentSearches[index]
                        store.removeRecentSearch(q)
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
            baseURL: baseURL,
            downloadsStore: downloadsStore,
            playlistsStore: playlistsStore,
            playerStore: playerStore,
            playerService: playerService,
            onPlay: {
                playerService.playTrack(track, context: searchStore.results)
                showPlayer = true
            },
            onAddToQueue: {
                playerStore.addToQueue(track)
            },
            isFavorite: favoritesStore.isFavorite(track.id),
            onToggleFavorite: {
                Task { await favoritesStore.toggleFavorite(track) }
            },
            onRemove: nil
        )
        .contextMenu {
            ForEach(playlistsStore.playlists) { pl in
                Button("Add to \(pl.name)") {
                    Task { await playlistsStore.addTrack(playlistId: pl.id, track: track) }
                }
            }
        }
    }

    @ViewBuilder
    private var loadMoreButton: some View {
        if searchStore.nextPageToken != nil && !searchStore.results.isEmpty {
            Button {
                Task { await searchStore.loadMore(query: query) }
            } label: {
                HStack {
                    Spacer()
                    if searchStore.isSearching {
                        ProgressView()
                    } else {
                        Text("Load More")
                    }
                    Spacer()
                }
            }
        }
    @ViewBuilder
    private var errorSection: some View {
        if let error = searchStore.errorMessage {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Search Error")
                            .font(.headline)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
}
