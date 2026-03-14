import SwiftUI

struct PlaylistsView: View {
    @Environment(\.baseURL) var baseURL
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
                            showPlayer: $showPlayer
                        )
                    } label: {
                        PlaylistRow(
                            name: "Downloads",
                            thumbnails: appState.downloadsStore.downloadedTracks.prefix(4).map { $0.thumbnail },
                            defaultIcon: "arrow.down.circle",
                            count: appState.downloadsStore.downloadedTracks.count
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
                            showPlayer: $showPlayer
                        )
                    } label: {
                        PlaylistRow(
                            name: "Recently Played",
                            thumbnails: appState.historyStore.history.prefix(4).map { $0.thumbnail },
                            defaultIcon: "clock.arrow.circlepath",
                            count: appState.historyStore.history.count
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
                                playlist: pl,
                                showPlayer: $showPlayer
                            )
                        } label: {
                            PlaylistRow(
                                name: pl.name,
                                thumbnails: pl.thumbnails ?? [],
                                defaultIcon: "music.note",
                                count: pl.trackCount ?? 0
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
                    MiniPlayerSpacer()
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
                    .injectEnvironment(appState: appState)
            }
            .onAppear { Task { await playlistsStore.loadPlaylists() } }
        }
    }
}

struct DownloadsView: View {
    @Environment(\.baseURL) var baseURL
    @ObservedObject var downloadsStore: DownloadsStore
    @ObservedObject var playlistsStore: PlaylistsStore
    @ObservedObject var playerStore: PlayerStore
    @ObservedObject var playerService: PlayerService
    @ObservedObject var favoritesStore: FavoritesStore
    @Binding var showPlayer: Bool
    @State private var editMode: EditMode = .inactive

    var body: some View {
        List {
            if downloadsStore.downloadedTracks.isEmpty {
                ContentUnavailableView(
                    "No Downloads",
                    systemImage: "arrow.down.to.line.circle",
                    description: Text("Download tracks to listen offline")
                )
            }

            ForEach(downloadsStore.downloadedTracks) { track in
                TrackRow(
                    track: track,
                    onPlay: {
                        playerService.playTrack(track, context: downloadsStore.downloadedTracks)
                        showPlayer = true
                    },
                    onAddToQueue: { playerStore.addToQueue(track) },
                    isFavorite: favoritesStore.isFavorite(track.id),
                    onToggleFavorite: { Task { await favoritesStore.toggleFavorite(track) } },
                    onRemove: {
                        downloadsStore.removeTrack(track.id)
                        AudioCacheService.shared.removeTrack(id: track.id)
                    }
                )
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
            MiniPlayerSpacer()
        }
        .navigationTitle("Navigation Example")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
    }
}

struct HistoryView: View {
    @Environment(\.baseURL) var baseURL
    @ObservedObject var historyStore: HistoryStore
    @ObservedObject var downloadsStore: DownloadsStore
    @ObservedObject var playlistsStore: PlaylistsStore
    @ObservedObject var playerStore: PlayerStore
    @ObservedObject var playerService: PlayerService
    @ObservedObject var favoritesStore: FavoritesStore
    @Binding var showPlayer: Bool
    @State private var editMode: EditMode = .inactive

    var body: some View {
        List {
            if historyStore.history.isEmpty {
                ContentUnavailableView(
                    "No History",
                    systemImage: "clock",
                    description: Text("Tracks you listen to will appear here")
                )
            }

            ForEach(historyStore.history) { track in
                TrackRow(
                    track: track,
                    onPlay: {
                        playerService.playTrack(track, context: historyStore.history)
                        showPlayer = true
                    },
                    onAddToQueue: { playerStore.addToQueue(track) },
                    isFavorite: favoritesStore.isFavorite(track.id),
                    onToggleFavorite: { Task { await favoritesStore.toggleFavorite(track) } },
                    onRemove: { historyStore.removeTrack(id: track.id) }
                )
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
            MiniPlayerSpacer()
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
}

// MARK: - Components

struct PlaylistRow: View {
    let name: String
    let thumbnails: [String]
    let defaultIcon: String
    let count: Int
    
    var body: some View {
        HStack(spacing: 20) {
            PlaylistArtworkView(thumbnails: thumbnails, size: 60, defaultIcon: defaultIcon)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(pluralizedTracks(count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func pluralizedTracks(_ count: Int) -> String {
        if count == 0 { return "No tracks" }
        return "\(count) track\(count == 1 ? "" : "s")"
    }
}

struct PlaylistArtworkView: View {
    @Environment(\.baseURL) var baseURL
    let thumbnails: [String]
    let size: CGFloat
    let defaultIcon: String
    
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
                let showThumbnails = Array(thumbnails.prefix(3))
                let total = showThumbnails.count
                
                ZStack {
                    if total > 2 {
                        thumbnailView(path: showThumbnails[2], index: 2, total: total)
                    }
                    if total > 1 {
                        thumbnailView(path: showThumbnails[1], index: 1, total: total)
                    }
                    if total > 0 {
                        thumbnailView(path: showThumbnails[0], index: 0, total: total)
                    }
                }
            }
        }
        .frame(width: size + 20, height: size + 10)
    }
    
    private func thumbnailView(path: String, index: Int, total: Int) -> some View {
        let reverseIndex = total - 1 - index
        return CachedAsyncImage(url: Track.thumbnailURL(path: path, baseURL: baseURL), contentMode: .fill)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.1), lineWidth: 0.5))
            .shadow(radius: 4)
            .rotationEffect(.degrees(Double(reverseIndex - 1) * 12.0))
            .offset(x: CGFloat(reverseIndex - 1) * 12.0, y: CGFloat(reverseIndex) * 2.0)
            .scaleEffect(1.0 - CGFloat(reverseIndex) * 0.05)
            .zIndex(Double(total - reverseIndex))
    }
}
