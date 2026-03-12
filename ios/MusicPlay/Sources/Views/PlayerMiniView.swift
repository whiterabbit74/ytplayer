import SwiftUI

struct PlayerMiniView: View {
    @EnvironmentObject var appState: AppState
    @Binding var showPlayer: Bool

    var body: some View {
        if let track = appState.playerStore.currentTrack {
            VStack(spacing: 0) {
                // Progress bar at the top of mini-player
                GeometryReader { geo in
                    let progress = appState.playerService.duration > 0
                        ? appState.playerService.currentTime / appState.playerService.duration
                        : 0
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
                            CachedAsyncImage(url: thumbURL(track), contentMode: .fill)
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title)
                                    .font(.subheadline.weight(.medium))
                                    .lineLimit(1)
                                Text(track.artist)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    // Playback controls — do NOT open full player
                    HStack(spacing: 16) {
                        Button {
                            appState.playerService.togglePlayPause()
                        } label: {
                            Image(systemName: appState.playerService.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title3)
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Button {
                            let hasNext = appState.playerStore.playNext()
                            if hasNext, let next = appState.playerStore.currentTrack {
                                appState.playerService.play(track: next)
                            }
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
            .padding(.bottom, 49) // Offset above tab bar — NOT tappable
        }
    }

    private func thumbURL(_ track: Track) -> URL? {
        if track.thumbnail.hasPrefix("http") {
            return URL(string: track.thumbnail)
        }
        let base = appState.baseURL
        if track.thumbnail.hasPrefix("/") {
            return URL(string: base + track.thumbnail)
        }
        return URL(string: base + "/" + track.thumbnail)
    }
}
