import SwiftUI

struct TrackRow: View {
    let track: Track
    let baseURL: String
    let onPlay: () -> Void
    let onAddToQueue: () -> Void
    let isFavorite: Bool
    let onToggleFavorite: (() -> Void)?
    
    @Environment(\.editMode) private var editMode
    @EnvironmentObject var appState: AppState

    init(
        track: Track,
        baseURL: String,
        onPlay: @escaping () -> Void,
        onAddToQueue: @escaping () -> Void,
        isFavorite: Bool = false,
        onToggleFavorite: (() -> Void)? = nil
    ) {
        self.track = track
        self.baseURL = baseURL
        self.onPlay = onPlay
        self.onAddToQueue = onAddToQueue
        self.isFavorite = isFavorite
        self.onToggleFavorite = onToggleFavorite
    }

    var body: some View {
        HStack(spacing: 12) {
            TrackThumbnail(track: track, size: 48, forceSquare: true, cornerRadius: 8)

            VStack(alignment: .leading, spacing: 4) {
                Text(track.title).font(.headline).lineLimit(1)
                HStack(spacing: 4) {
                    if appState.downloadsStore.isDownloaded(id: track.id) {
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
                        appState.playerStore.addToQueueNext(track)
                    } label: {
                        Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                    }
                    
                    if let onToggleFavorite {
                        Button(action: onToggleFavorite) {
                            Label(isFavorite ? "Remove from Favorites" : "Add to Favorites", systemImage: isFavorite ? "heart.slash" : "heart")
                        }
                    }
                    
                    let isDownloaded = appState.downloadsStore.isDownloaded(id: track.id)
                    let isFailed = appState.downloadsStore.failedDownloads.contains(track.id)
                    let isDownloading = appState.downloadsStore.downloadProgresses[track.id] != nil
                    
                    if isDownloading {
                        Button(role: .destructive) {
                            appState.downloadsStore.removeTrack(track.id)
                            AudioCacheService.shared.removeTrack(id: track.id)
                        } label: {
                            Label("Cancel Download", systemImage: "xmark.circle")
                        }
                    } else if isFailed {
                        Button {
                            appState.playerService.downloadTrack(track)
                        } label: {
                            Label("Retry Download", systemImage: "arrow.clockwise.circle")
                        }
                        
                        Button(role: .destructive) {
                            appState.downloadsStore.removeTrack(track.id)
                            AudioCacheService.shared.removeTrack(id: track.id)
                        } label: {
                            Label("Remove from Downloads", systemImage: "trash")
                        }
                    } else {
                        Button {
                            if isDownloaded {
                                appState.downloadsStore.removeTrack(track.id)
                                AudioCacheService.shared.removeTrack(id: track.id)
                            } else {
                                appState.playerService.downloadTrack(track)
                            }
                        } label: {
                            Label(isDownloaded ? "Remove Download" : "Download", systemImage: isDownloaded ? "trash" : "arrow.down.circle")
                        }
                    }
                    
                    Menu {
                        ForEach(appState.playlistsStore.playlists) { pl in
                            Button(pl.name) {
                                Task { await appState.playlistsStore.addTrack(playlistId: pl.id, track: track) }
                            }
                        }
                    } label: {
                        Label("Add to Playlist", systemImage: "folder.badge.plus")
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
