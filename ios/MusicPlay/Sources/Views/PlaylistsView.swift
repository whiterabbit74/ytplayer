import SwiftUI

struct PlaylistsView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var playlistsStore: PlaylistsStore
    @State private var newName = ""
    @State private var showSettings = false
    @Binding var showPlayer: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack {
                    TextField("New playlist", text: $newName)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        Task {
                            let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                            if trimmed.isEmpty { return }
                            await playlistsStore.createPlaylist(name: trimmed)
                            newName = ""
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
                .padding(.horizontal, 12)

                List {
                    NavigationLink {
                        DownloadsView(
                            downloadsStore: appState.downloadsStore,
                            playlistsStore: playlistsStore,
                            playerStore: appState.playerStore,
                            playerService: appState.playerService,
                            favoritesStore: appState.favoritesStore,
                            baseURL: appState.baseURL,
                            showPlayer: $showPlayer
                        )
                    } label: {
                        PlaylistRow(
                            name: "Downloads",
                            thumbnails: appState.downloadsStore.downloadedTracks.prefix(4).map { $0.thumbnail },
                            defaultIcon: "arrow.down.circle",
                            baseURL: appState.baseURL
                        )
                    }

                    NavigationLink {
                        HistoryView(
                            historyStore: appState.historyStore,
                            downloadsStore: appState.downloadsStore,
                            playlistsStore: playlistsStore,
                            playerStore: appState.playerStore,
                            playerService: appState.playerService,
                            favoritesStore: appState.favoritesStore,
                            baseURL: appState.baseURL,
                            showPlayer: $showPlayer
                        )
                    } label: {
                        PlaylistRow(
                            name: "Recently Played",
                            thumbnails: appState.historyStore.history.prefix(4).map { $0.thumbnail },
                            defaultIcon: "clock.arrow.circlepath",
                            baseURL: appState.baseURL
                        )
                    }

                    ForEach(playlistsStore.playlists) { pl in
                        NavigationLink {
                            PlaylistDetailView(
                                playlistsStore: playlistsStore,
                                playerStore: appState.playerStore,
                                playerService: appState.playerService,
                                downloadsStore: appState.downloadsStore,
                                favoritesStore: appState.favoritesStore,
                                baseURL: appState.baseURL,
                                playlist: pl,
                                showPlayer: $showPlayer
                            )
                        } label: {
                            PlaylistRow(
                                name: pl.name,
                                thumbnails: pl.thumbnails ?? [],
                                defaultIcon: "music.note",
                                baseURL: appState.baseURL
                            )
                        }
                    }
                    .onDelete { idx in
                        for i in idx {
                            let id = playlistsStore.playlists[i].id
                            Task { await playlistsStore.deletePlaylist(id: id) }
                        }
                    }
                }
                .listStyle(.plain)
                .safeAreaInset(edge: .bottom) {
                    if appState.playerStore.currentTrack != nil {
                        Color.clear.frame(height: 70)
                    }
                }
            }
            .navigationTitle("Playlists")
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
            .onAppear { Task { await playlistsStore.loadPlaylists() } }
        }
    }
}

struct DownloadsView: View {
    @ObservedObject var downloadsStore: DownloadsStore
    @ObservedObject var playlistsStore: PlaylistsStore
    @ObservedObject var playerStore: PlayerStore
    @ObservedObject var playerService: PlayerService
    @ObservedObject var favoritesStore: FavoritesStore
    let baseURL: String
    @Binding var showPlayer: Bool
    @State private var editMode: EditMode = .inactive

    var body: some View {
        List {
            if downloadsStore.downloadedTracks.isEmpty {
                ContentUnavailableView("No Downloads", systemImage: "arrow.down.to.line.circle", description: Text("Download tracks to listen offline"))
            }

            ForEach(downloadsStore.downloadedTracks) { track in
                trackRow(track)
            }
            .onDelete { indexSet in
                for index in indexSet.sorted(by: >) {
                    let t = downloadsStore.downloadedTracks[index]
                    downloadsStore.removeTrack(t.id)
                    AudioCacheService.shared.removeTrack(id: t.id)
                }
            }
            .onMove { from, to in
                downloadsStore.moveTracks(from: from, to: to)
            }
        }
        .environment(\.editMode, $editMode)
        .safeAreaInset(edge: .bottom) {
            if playerStore.currentTrack != nil {
                Color.clear.frame(height: 70)
            }
        }
        .navigationTitle("Downloads")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
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
                playerService.playTrack(track, context: downloadsStore.downloadedTracks)
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
                downloadsStore.removeTrack(track.id)
                AudioCacheService.shared.removeTrack(id: track.id)
            }
        )
    }
}

struct HistoryView: View {
    @ObservedObject var historyStore: HistoryStore
    @ObservedObject var downloadsStore: DownloadsStore
    @ObservedObject var playlistsStore: PlaylistsStore
    @ObservedObject var playerStore: PlayerStore
    @ObservedObject var playerService: PlayerService
    @ObservedObject var favoritesStore: FavoritesStore
    let baseURL: String
    @Binding var showPlayer: Bool
    @State private var editMode: EditMode = .inactive

    var body: some View {
        List {
            if historyStore.history.isEmpty {
                ContentUnavailableView("No History", systemImage: "clock", description: Text("Tracks you listen to will appear here"))
            }

            ForEach(historyStore.history) { track in
                trackRow(track)
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let id = historyStore.history[index].id
                    historyStore.removeTrack(id: id)
                }
            }
        }
        .environment(\.editMode, $editMode)
        .safeAreaInset(edge: .bottom) {
            if playerStore.currentTrack != nil {
                Color.clear.frame(height: 70)
            }
        }
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !historyStore.history.isEmpty {
                    Button(role: .destructive) {
                        historyStore.clearHistory()
                    } label: {
                        Text("Clear")
                    }
                }
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
                playerService.playTrack(track, context: historyStore.history)
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
                historyStore.removeTrack(id: track.id)
            }
        )
    }
}

// MARK: - Components

struct PlaylistRow: View {
    let name: String
    let thumbnails: [String]
    let defaultIcon: String
    let baseURL: String
    
    var body: some View {
        HStack(spacing: 20) {
            PlaylistArtworkView(thumbnails: thumbnails, size: 60, defaultIcon: defaultIcon, baseURL: baseURL)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                if !thumbnails.isEmpty {
                    Text("\(thumbnails.count)+ tracks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct PlaylistArtworkView: View {
    let thumbnails: [String]
    let size: CGFloat
    let defaultIcon: String
    let baseURL: String
    
    var body: some View {
        ZStack {
            if thumbnails.isEmpty {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                    Image(systemName: defaultIcon)
                        .font(.system(size: size * 0.4))
                        .foregroundStyle(.secondary)
                }
                .frame(width: size, height: size)
            } else {
                // Fan style: Stack of covers with rotation
                let count = thumbnails.prefix(3).count
                ForEach(0..<count, id: \.self) { index in
                    let reverseIndex = count - 1 - index
                    let thumb = thumbnails[reverseIndex]
                    
                    CachedAsyncImage(url: thumbURL(thumb), contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.1), lineWidth: 0.5))
                        .shadow(radius: 4)
                        .rotationEffect(.degrees(Double(reverseIndex - 1) * 12))
                        .offset(x: CGFloat(reverseIndex - 1) * 12, y: CGFloat(reverseIndex) * 2)
                        .scaleEffect(1.0 - CGFloat(reverseIndex) * 0.05)
                        .zIndex(Double(count - reverseIndex))
                }
            }
        }
        .frame(width: size + 20, height: size + 10)
    }

    private func thumbURL(_ path: String) -> URL? {
        if path.hasPrefix("http") {
            return URL(string: path)
        }
        
        // Use the same robust URL construction as APIClient
        guard var components = URLComponents(string: baseURL) else {
            return nil
        }
        
        let basePath = components.path
        let cleanedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let finalPath = basePath.hasSuffix("/") ? "\(basePath)\(cleanedPath)" : "\(basePath)/\(cleanedPath)"
        
        components.path = finalPath
        return components.url
    }
}
