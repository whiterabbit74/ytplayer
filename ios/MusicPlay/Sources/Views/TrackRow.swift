import SwiftUI

struct TrackRow: View {
    @Environment(\.baseURL) var baseURL
    @Environment(\.editMode) private var editMode
    
    let track: Track
    let onPlay: () -> Void
    let onAddToQueue: () -> Void
    let isFavorite: Bool
    let onToggleFavorite: (() -> Void)?
    let onRemove: (() -> Void)?
    
    @EnvironmentObject var playerStore: PlayerStore
    @EnvironmentObject var downloadsStore: DownloadsStore
    @EnvironmentObject var playerService: PlayerService

    @State private var showAddedToQueue = false

    var body: some View {
        HStack(spacing: 12) {
            TrackThumbnail(
                track: track,
                size: 48,
                cornerRadius: 8,
                downloadProgress: downloadsStore.progress(for: track.id),
                isFailed: downloadsStore.isFailed(track.id),
                isPlaying: playerStore.currentTrack?.id == track.id
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(track.title).font(.headline).lineLimit(1)
                HStack(spacing: 4) {
                    if downloadsStore.isTrackDownloaded(track.id) {
                        DownloadIcon(size: .custom(12), showShadow: true)
                            .transition(.scale.combined(with: .opacity))
                    }
                    TrackMetadataView(track: track)
                }
            }

            Spacer()

            if editMode?.wrappedValue != .active {
                if showAddedToQueue {
                    Image(systemName: "checkmark")
                        .font(.headline)
                        .foregroundStyle(.green)
                        .transition(.scale.combined(with: .opacity))
                        .padding(.trailing, 8)
                }

                Menu {
                    TrackMenuContent(
                        track: track,
                        onPlay: onPlay,
                        onAddToQueue: {
                            onAddToQueue()
                            triggerAddedAnimation()
                        },
                        onToggleFavorite: onToggleFavorite,
                        isFavorite: isFavorite,
                        onRemove: onRemove
                    )
                } label: {
                    Image(systemName: "ellipsis")
                        .padding(8)
                }
                .buttonStyle(.plain)

                if let progress = downloadsStore.progress(for: track.id) {
                    ProgressView(value: progress)
                        .progressViewStyle(CircularProgressViewStyle())
                        .frame(width: 20, height: 20)
                        .padding(.leading, 4)
                }
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

    private func triggerAddedAnimation() {
        HapticManager.shared.trigger(.success)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            showAddedToQueue = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut) {
                showAddedToQueue = false
            }
        }
    }
}
