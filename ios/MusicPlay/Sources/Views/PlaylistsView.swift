import SwiftUI

struct PlaylistsView: View {
    @EnvironmentObject var appState: AppState
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
                            await appState.playlistsStore.createPlaylist(name: trimmed)
                            newName = ""
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
                .padding(.horizontal, 12)

                List {
                    NavigationLink {
                        DownloadsView(showPlayer: $showPlayer)
                    } label: {
                        PlaylistRow(
                            name: "Downloads",
                            thumbnails: appState.downloadsStore.downloadedTracks.prefix(4).map { $0.thumbnail },
                            defaultIcon: "arrow.down.circle"
                        )
                    }

                    NavigationLink {
                        HistoryView(showPlayer: $showPlayer)
                    } label: {
                        PlaylistRow(
                            name: "Recently Played",
                            thumbnails: appState.historyStore.history.prefix(4).map { $0.thumbnail },
                            defaultIcon: "clock.arrow.circlepath"
                        )
                    }

                    ForEach(appState.playlistsStore.playlists) { pl in
                        NavigationLink {
                            PlaylistDetailView(playlist: pl, showPlayer: $showPlayer)
                        } label: {
                            PlaylistRow(
                                name: pl.name,
                                thumbnails: pl.thumbnails ?? [],
                                defaultIcon: "music.note"
                            )
                        }
                    }
                    .onDelete { idx in
                        for i in idx {
                            let id = appState.playlistsStore.playlists[i].id
                            Task { await appState.playlistsStore.deletePlaylist(id: id) }
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
            .onAppear { Task { await appState.playlistsStore.loadPlaylists() } }
        }
    }
}

struct DownloadsView: View {
    @EnvironmentObject var appState: AppState
    @Binding var showPlayer: Bool

    var body: some View {
        List {
            if appState.downloadsStore.downloadedTracks.isEmpty {
                ContentUnavailableView("No Downloads", systemImage: "arrow.down.to.line.circle", description: Text("Download tracks to listen offline"))
            }

            ForEach(appState.downloadsStore.downloadedTracks) { track in
                trackRow(track)
            }
            .onDelete { indexSet in
                for index in indexSet.sorted(by: >) {
                    let t = appState.downloadsStore.downloadedTracks[index]
                    appState.downloadsStore.removeTrack(t.id)
                    AudioCacheService.shared.removeTrack(id: t.id)
                }
            }
            .onMove { from, to in
                appState.downloadsStore.moveTracks(from: from, to: to)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if appState.playerStore.currentTrack != nil {
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
            baseURL: appState.baseURL,
            onPlay: {
                appState.playerService.playTrack(track, context: appState.downloadsStore.downloadedTracks)
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
    }
}

struct HistoryView: View {
    @EnvironmentObject var appState: AppState
    @Binding var showPlayer: Bool

    var body: some View {
        List {
            if appState.historyStore.history.isEmpty {
                ContentUnavailableView("No History", systemImage: "clock", description: Text("Tracks you listen to will appear here"))
            }

            ForEach(appState.historyStore.history) { track in
                trackRow(track)
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let id = appState.historyStore.history[index].id
                    appState.historyStore.removeTrack(id: id)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if appState.playerStore.currentTrack != nil {
                Color.clear.frame(height: 70)
            }
        }
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !appState.historyStore.history.isEmpty {
                    Button(role: .destructive) {
                        appState.historyStore.clearHistory()
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
            baseURL: appState.baseURL,
            onPlay: {
                appState.playerService.playTrack(track, context: appState.historyStore.history)
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
    }
}

// MARK: - Components

struct PlaylistRow: View {
    let name: String
    let thumbnails: [String]
    let defaultIcon: String
    
    var body: some View {
        HStack(spacing: 20) {
            PlaylistArtworkView(thumbnails: thumbnails, size: 60, defaultIcon: defaultIcon)
            
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
    @EnvironmentObject var appState: AppState
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
        guard var components = URLComponents(string: appState.baseURL) else {
            return nil
        }
        
        let basePath = components.path
        let cleanedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let finalPath = basePath.hasSuffix("/") ? "\(basePath)\(cleanedPath)" : "\(basePath)/\(cleanedPath)"
        
        components.path = finalPath
        return components.url
    }
}
