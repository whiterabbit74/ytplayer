import SwiftUI

struct PlayerFullView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var isSeeking = false
    @State private var seekTime: Double = 0

    var body: some View {
        VStack(spacing: 16) {
            // Drag indicator
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            HStack {
                Button("Close") { dismiss() }
                Spacer()
            }
            .padding(.horizontal, 16)

            if let track = appState.playerStore.currentTrack {
                Spacer()

                CachedAsyncImage(url: thumbURL(track), contentMode: .fit)
                    .frame(maxWidth: 300, maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(radius: 10)

                VStack(spacing: 6) {
                    Text(track.title)
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    Text(track.artist)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)

                // Slider with seek buffering
                VStack(spacing: 8) {
                    Slider(
                        value: Binding(
                            get: { isSeeking ? seekTime : appState.playerService.currentTime },
                            set: { newValue in
                                isSeeking = true
                                seekTime = newValue
                            }
                        ),
                        in: 0...max(appState.playerService.duration, 1),
                        onEditingChanged: { editing in
                            if !editing {
                                appState.playerService.seek(to: seekTime)
                                // Small delay before resuming live updates
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    isSeeking = false
                                }
                            }
                        }
                    )

                    HStack {
                        Text(formatTime(isSeeking ? seekTime : appState.playerService.currentTime))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        Spacer()
                        Text(formatTime(appState.playerService.duration))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                .padding(.horizontal, 24)

                // Playback controls
                HStack(spacing: 40) {
                    Button {
                        appState.playerStore.playPrev()
                        if let t = appState.playerStore.currentTrack {
                            appState.playerService.play(track: t)
                        }
                    } label: {
                        Image(systemName: "backward.fill").font(.title2)
                    }

                    Button {
                        appState.playerService.togglePlayPause()
                    } label: {
                        Image(systemName: appState.playerService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 60))
                    }

                    Button {
                        let hasNext = appState.playerStore.playNext()
                        if hasNext, let t = appState.playerStore.currentTrack {
                            appState.playerService.play(track: t)
                        }
                    } label: {
                        Image(systemName: "forward.fill").font(.title2)
                    }
                }

                // Secondary controls
                HStack(spacing: 24) {
                    Button {
                        let modes = ["off", "one", "all"]
                        if let idx = modes.firstIndex(of: appState.playerStore.repeatMode) {
                            appState.playerStore.repeatMode = modes[(idx + 1) % modes.count]
                        } else {
                            appState.playerStore.repeatMode = "off"
                        }
                    } label: {
                        let mode = appState.playerStore.repeatMode
                        Image(systemName: mode == "one" ? "repeat.1" : "repeat")
                            .foregroundStyle(mode != "off" ? .white : .white.opacity(0.4))
                    }

                    Button {
                        Task {
                            if let track = appState.playerStore.currentTrack {
                                await appState.favoritesStore.toggleFavorite(track)
                            }
                        }
                    } label: {
                        Image(systemName: appState.playerStore.currentTrack.map { appState.favoritesStore.isFavorite($0.id) } == true ? "heart.fill" : "heart")
                            .foregroundStyle(.red)
                    }

                    Button {
                        if let track = appState.playerStore.currentTrack {
                            appState.playerStore.addToQueue(track)
                        }
                    } label: {
                        Image(systemName: "text.badge.plus")
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    // Add to Playlist
                    Menu {
                        if appState.playlistsStore.playlists.isEmpty {
                            Text("No playlists")
                        } else {
                            ForEach(appState.playlistsStore.playlists) { pl in
                                Button(pl.name) {
                                    if let track = appState.playerStore.currentTrack {
                                        Task { await appState.playlistsStore.addTrack(playlistId: pl.id, track: track) }
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "plus.rectangle.on.folder")
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }

                Spacer()
            } else {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "music.note")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No track playing")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .onAppear {
            Task { await appState.playlistsStore.loadPlaylists() }
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

    private func formatTime(_ seconds: Double) -> String {
        if !seconds.isFinite || seconds < 0 { return "0:00" }
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
