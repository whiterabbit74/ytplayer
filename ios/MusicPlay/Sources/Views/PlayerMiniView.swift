import SwiftUI

struct PlayerMiniView: View {
    @ObservedObject var playerStore: PlayerStore
    @ObservedObject var playerService: PlayerService
    @ObservedObject var downloadsStore: DownloadsStore
    @ObservedObject var progressStore: PlaybackProgressStore
    let baseURL: String
    @Binding var showPlayer: Bool

    var body: some View {
        if let track = playerStore.currentTrack {
            VStack(spacing: 0) {
                // Progress bar at the top of mini-player
                GeometryReader { geo in
                    let progress = progressStore.progress
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: geo.size.width * min(max(progress, 0), 1))
                }
                .frame(height: 2)

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
                                baseURL: baseURL,
                                downloadsStore: downloadsStore
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title)
                                    .font(.subheadline.weight(.medium))
                                    .lineLimit(1)
                                HStack(spacing: 4) {
                                    if downloadsStore.isDownloaded(id: track.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                            .font(.system(size: 10))
                                    }
                                    Text(track.artist)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    // Playback controls — do NOT open full player
                    HStack(spacing: 16) {
                        Button {
                            HapticManager.shared.trigger(.light)
                            playerService.togglePlayPause()
                        } label: {
                            Image(systemName: playerService.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title3)
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Button {
                            HapticManager.shared.trigger(.medium)
                            playerService.next()
                        } label: {
                            Image(systemName: "forward.fill")
                                    .font(.title3)
                                    .frame(width: 36, height: 36)
                                    .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.15), radius: 8, y: -2)
            .padding(.horizontal, 8)
            .padding(.bottom, 4) // Small gap from whatever is below
        }
    }
}
