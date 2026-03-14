import SwiftUI

struct PlayerMiniView: View {
    @Environment(\.baseURL) var baseURL
    @ObservedObject var playerStore: PlayerStore
    @ObservedObject var playerService: PlayerService
    @ObservedObject var downloadsStore: DownloadsStore
    let progressStore: PlaybackProgressStore
    @Binding var showPlayer: Bool

    var body: some View {
        if let track = playerStore.currentTrack {
            VStack(spacing: 0) {
                // Progress bar at the top of mini-player
                MiniPlayerProgressBar(progressStore: progressStore)

                HStack(spacing: 12) {
                    // Track info — tapping opens full player
                    Button {
                        showPlayer = true
                    } label: {
                        HStack(spacing: 12) {
                            TrackThumbnail(
                                track: track,
                                size: 44,
                                forceSquare: true,
                                cornerRadius: 8,
                                showStatus: false,
                                downloadProgress: downloadsStore.progress(for: track.id),
                                isFailed: downloadsStore.isFailed(track.id),
                                isPlaying: playerService.isPlaying
                            )

                            ZStack(alignment: .leading) {
                                VStack(alignment: .leading, spacing: 2) {
                                    MarqueeText(text: track.title, font: .subheadline.weight(.medium), speed: 20)
                                        .frame(height: 18)
                                    
                                    HStack(spacing: 4) {
                                        if downloadsStore.isTrackDownloaded(track.id) {
                                            DownloadIcon(size: .small)
                                        }
                                        TrackMetadataView(track: track, showDuration: false)
                                    }
                                }
                                .id(track.id)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                            }
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: track.id)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    // Mini Controls
                    HStack(spacing: 8) {
                        PlayPauseButton(
                            isPlaying: playerService.isPlaying,
                            isBuffering: playerService.isBuffering,
                            action: { playerService.togglePlayPause() },
                            style: .mini
                        )

                        Button {
                            HapticManager.shared.trigger(.medium)
                            playerService.next()
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.title3)
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.15), radius: 8, y: -2)
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
        }
    }
}
