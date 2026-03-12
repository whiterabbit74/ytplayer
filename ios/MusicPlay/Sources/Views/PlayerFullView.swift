import SwiftUI

struct PlayerFullView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button("Close") { dismiss() }
                Spacer()
            }
            .padding(.horizontal, 16)

            if let track = appState.playerStore.currentTrack {
                CachedAsyncImage(url: thumbURL(track), contentMode: .fit)
                .frame(maxWidth: 320, maxHeight: 320)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(spacing: 6) {
                    Text(track.title)
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                    Text(track.artist)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 8) {
                    Slider(value: Binding(
                        get: { appState.playerService.currentTime },
                        set: { appState.playerService.seek(to: $0) }
                    ), in: 0...max(appState.playerService.duration, 1))

                    HStack {
                        Text(formatTime(appState.playerService.currentTime))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatTime(appState.playerService.duration))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)

                HStack(spacing: 32) {
                    Button {
                        appState.playerStore.playPrev()
                        if let t = appState.playerStore.currentTrack {
                            appState.playerService.play(track: t)
                        }
                    } label: {
                        Image(systemName: "backward.fill").font(.title2)
                    }

                    Button {
                        if appState.playerService.isPlaying {
                            appState.playerService.pause()
                        } else {
                            appState.playerService.resume()
                        }
                    } label: {
                        Image(systemName: appState.playerService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 56))
                    }

                    Button {
                        appState.playerStore.playNext()
                        if let t = appState.playerStore.currentTrack {
                            appState.playerService.play(track: t)
                        }
                    } label: {
                        Image(systemName: "forward.fill").font(.title2)
                    }
                }

                HStack(spacing: 16) {
                    Button {
                        appState.playerStore.repeatMode = appState.playerStore.repeatMode == "one" ? "off" : "one"
                    } label: {
                        Image(systemName: "repeat.1")
                            .foregroundStyle(appState.playerStore.repeatMode == "one" ? .green : .secondary)
                    }

                    Button {
                        Task { if let track = appState.playerStore.currentTrack { await appState.favoritesStore.toggleFavorite(track) } }
                    } label: {
                        Image(systemName: appState.playerStore.currentTrack.map { appState.favoritesStore.isFavorite($0.id) } == true ? "heart.fill" : "heart")
                            .foregroundStyle(.red)
                    }
                }

                Spacer()
            } else {
                Spacer()
                Text("No track playing")
                Spacer()
            }
        }
        .padding(.top, 16)
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

    private func formatTime(_ seconds: Double) -> String {
        if !seconds.isFinite { return "0:00" }
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
