import SwiftUI

struct PlayerMiniView: View {
    @EnvironmentObject var appState: AppState
    @Binding var showPlayer: Bool

    var body: some View {
        if let track = appState.playerStore.currentTrack {
            HStack(spacing: 12) {
                CachedAsyncImage(url: thumbURL(track), contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title).font(.subheadline.weight(.medium)).lineLimit(1)
                    Text(track.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }

                Spacer()

                HStack(spacing: 16) {
                    Button {
                        if appState.playerService.isPlaying {
                            appState.playerService.pause()
                        } else {
                            appState.playerService.resume()
                        }
                    } label: {
                        Image(systemName: appState.playerService.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3)
                    }

                    Button {
                        appState.playerStore.playNext()
                        if let next = appState.playerStore.currentTrack {
                            appState.playerService.play(track: next)
                        }
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title3)
                    }
                }
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .shadow(radius: 5)
            .padding(.horizontal, 12)
            .onTapGesture { showPlayer = true }
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
