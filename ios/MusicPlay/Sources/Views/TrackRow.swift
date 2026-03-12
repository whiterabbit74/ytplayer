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
            ZStack {
                CachedAsyncImage(url: thumbURL, contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                if let progress = appState.downloadsStore.downloadProgresses[track.id] {
                    ZStack {
                        Color.black.opacity(0.5)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 3)
                            .frame(width: 24, height: 24)
                        
                            Circle()
                                .trim(from: 0, to: CGFloat(max(0.05, progress)))
                                .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .frame(width: 24, height: 24)
                                .rotationEffect(.degrees(-90))
                                // Add a spinning effect if progress is very low (starting up)
                                .rotationEffect(.degrees(progress < 0.05 ? 360 : 0))
                                .animation(progress < 0.05 ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: progress)
                        }
                        .frame(width: 48, height: 48)
                    }
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(track.title).font(.headline).lineLimit(1)
                HStack(spacing: 4) {
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
                    
                    if let onToggleFavorite {
                        Button(action: onToggleFavorite) {
                            Label(isFavorite ? "Remove from Favorites" : "Add to Favorites", systemImage: isFavorite ? "heart.slash" : "heart")
                        }
                    }
                    
                    let isDownloaded = appState.downloadsStore.isDownloaded(id: track.id)
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
        .onTapGesture {
            if editMode?.wrappedValue != .active {
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
