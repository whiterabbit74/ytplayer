import SwiftUI

struct TrackRow: View {
    let track: Track
    let baseURL: String
    let onPlay: () -> Void
    let onAddToQueue: () -> Void
    let isFavorite: Bool
    let onToggleFavorite: (() -> Void)?
    let onRemove: (() -> Void)?
    
    @Environment(\.editMode) private var editMode
    let downloadsStore: DownloadsStore
    let playlistsStore: PlaylistsStore
    let playerStore: PlayerStore
    let playerService: PlayerService
    
    let isDownloaded: Bool
    let downloadProgress: Double?
    let isFailedDownload: Bool

    init(
        track: Track,
        baseURL: String,
        downloadsStore: DownloadsStore,
        playlistsStore: PlaylistsStore,
        playerStore: PlayerStore,
        playerService: PlayerService,
        onPlay: @escaping () -> Void,
        onAddToQueue: @escaping () -> Void,
        isFavorite: Bool = false,
        isDownloaded: Bool = false,
        downloadProgress: Double? = nil,
        isFailedDownload: Bool = false,
        onToggleFavorite: (() -> Void)? = nil,
        onRemove: (() -> Void)? = nil
    ) {
        self.track = track
        self.baseURL = baseURL
        self.downloadsStore = downloadsStore
        self.playlistsStore = playlistsStore
        self.playerStore = playerStore
        self.playerService = playerService
        self.onPlay = onPlay
        self.onAddToQueue = onAddToQueue
        self.isFavorite = isFavorite
        self.isDownloaded = isDownloaded
        self.downloadProgress = downloadProgress
        self.isFailedDownload = isFailedDownload
        self.onToggleFavorite = onToggleFavorite
        self.onRemove = onRemove
    }

    var body: some View {
        HStack(spacing: 12) {
            TrackThumbnail(
                track: track,
                size: 48,
                forceSquare: true,
                cornerRadius: 8,
                baseURL: baseURL,
                downloadProgress: downloadProgress,
                isFailed: isFailedDownload
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(track.title).font(.headline).lineLimit(1)
                HStack(spacing: 4) {
                    if isDownloaded {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                            .font(.caption2)
                    }
                    Text(track.artist)
                    Text("•")
                    Text(track.formattedDuration)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer()

            if editMode?.wrappedValue != .active {
                Menu {
                    Button(action: onPlay) {
                        Label("Play", systemImage: "play")
                    }
                    
                    Button(action: onAddToQueue) {
                        Label("Add to Queue", systemImage: "text.badge.plus")
                    }
                    
                    Button {
                        playerStore.addToQueueNext(track)
                    } label: {
                        Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                    }
                    
                    if let onToggleFavorite {
                        Button(action: onToggleFavorite) {
                            Label(isFavorite ? "Remove from Favorites" : "Add to Favorites", systemImage: isFavorite ? "heart.slash" : "heart")
                        }
                    }
                    
                    let isDownloading = downloadProgress != nil
                    
                    if isDownloading {
                        Button(role: .destructive) {
                            downloadsStore.removeTrack(track.id)
                            AudioCacheService.shared.removeTrack(id: track.id)
                        } label: {
                            Label("Cancel Download", systemImage: "xmark.circle")
                        }
                    } else if isFailedDownload {
                        Button {
                            playerService.downloadTrack(track)
                        } label: {
                            Label("Retry Download", systemImage: "arrow.clockwise.circle")
                        }
                        
                        Button(role: .destructive) {
                            downloadsStore.removeTrack(track.id)
                            AudioCacheService.shared.removeTrack(id: track.id)
                        } label: {
                            Label("Remove from Downloads", systemImage: "trash")
                        }
                    } else {
                        Button {
                            if isDownloaded {
                                downloadsStore.removeTrack(track.id)
                                AudioCacheService.shared.removeTrack(id: track.id)
                            } else {
                                playerService.downloadTrack(track)
                            }
                        } label: {
                            Label(isDownloaded ? "Remove Download" : "Download", systemImage: isDownloaded ? "trash" : "arrow.down.circle")
                        }
                    }
                    
                    Menu {
                        ForEach(playlistsStore.playlists) { pl in
                            Button(pl.name) {
                                Task { await playlistsStore.addTrack(playlistId: pl.id, track: track) }
                            }
                        }
                    } label: {
                        Label("Add to Playlist", systemImage: "folder.badge.plus")
                    }

                    if let onRemove {
                        Button(role: .destructive, action: onRemove) {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .padding(8)
                }
                .buttonStyle(.plain)
            }
        }
        .contentShape(Rectangle())
        .buttonStyle(ScaleButtonStyle())
        .onTapGesture {
            if editMode?.wrappedValue != .active {
                HapticManager.shared.trigger(.selection)
                onPlay()
            }
        }
    }

    private var thumbURL: URL? {
        let cleaned = track.thumbnail
        if cleaned.hasPrefix("http") {
            return URL(string: cleaned)
        }
        if cleaned.hasPrefix("/") {
            return URL(string: baseURL + cleaned)
        }
        return URL(string: baseURL + "/" + cleaned)
    }
}
