import SwiftUI

struct SearchView: View {
    @Environment(\.baseURL) var baseURL
    @EnvironmentObject var appState: AppState
    
    @ObservedObject var searchStore: SearchStore
    @ObservedObject var playlistsStore: PlaylistsStore
    @ObservedObject var playerStore: PlayerStore
    @ObservedObject var playerService: PlayerService
    @ObservedObject var downloadsStore: DownloadsStore
    @ObservedObject var favoritesStore: FavoritesStore
    
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
            .animation(.easeInOut, value: searchStore.results)
            .safeAreaInset(edge: .bottom) {
                MiniPlayerSpacer()
            }
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "Search songs, artists...")
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: query)
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
                    .injectEnvironment(appState: appState)
            }
            .onChange(of: query) { _, newValue in
                searchStore.fetchSuggestions(query: newValue)
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
        if searchStore.isSearching && searchStore.results.isEmpty {
            Section {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
            }
        } else if searchStore.results.isEmpty && !query.isEmpty && !searchStore.isSearching {
            ContentUnavailableView.search(text: query)
        } else if searchStore.results.isEmpty {
            Section {
                ForEach(searchStore.recentSearches, id: \.self) { recent in
                    Button {
                        query = recent
                        searchStore.addRecentSearch(recent)
                        Task { await searchStore.search(query: recent) }
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
                        let q = searchStore.recentSearches[index]
                        searchStore.removeRecentSearch(q)
                    }
                }
            } header: {
                HStack {
                    Text("Recent Searches")
                    Spacer()
                    Button("Clear") {
                        searchStore.clearRecentSearches()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        } else {
            ForEach(searchStore.results) { track in
                TrackRow(
                    track: track,
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
