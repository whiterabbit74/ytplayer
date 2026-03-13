import SwiftUI

struct PlayerFullView: View {
    @ObservedObject var playerStore: PlayerStore
    @ObservedObject var playerService: PlayerService
    @ObservedObject var downloadsStore: DownloadsStore
    @ObservedObject var favoritesStore: FavoritesStore
    @ObservedObject var playlistsStore: PlaylistsStore
    @ObservedObject var progressStore: PlaybackProgressStore
    let baseURL: String
    let dynamicBackgroundEnabled: Bool
    let coverStyle: AppState.CoverStyle
    let squareCovers: Bool

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var isSeeking = false
    @State private var seekTime: Double = 0
    @State private var showQueue = false

    var body: some View {
        ZStack {
            // Background
            if dynamicBackgroundEnabled, let track = playerStore.currentTrack {
                DynamicBackgroundView(thumbnailURL: thumbURL(track))
            } else {
                LinearGradient(
                    gradient: Gradient(colors: [Color(white: 0.15), .black]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        HapticManager.shared.trigger(.light)
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)

                if let track = playerStore.currentTrack {
                    // 1. Artwork Section
                    Spacer(minLength: 20)
                    
                    Group {
                        if coverStyle == .vinyl {
                            VinylRecordView(
                                track: track,
                                size: 210,
                                baseURL: baseURL,
                                playerService: playerService,
                                downloadsStore: downloadsStore
                            )
                            .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
                        } else {
                            TrackThumbnail(
                                track: track,
                                size: 300,
                                forceSquare: squareCovers,
                                cornerRadius: 12,
                                showStatus: false,
                                baseURL: baseURL,
                                downloadsStore: downloadsStore
                            )
                            .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 15)
                            .transition(.asymmetric(insertion: .scale(scale: 0.9).combined(with: .opacity), removal: .opacity))
                        }
                    }
                    // Apply animation to track changes
                    .id(track.id)
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: track.id)
                    
                    Spacer(minLength: 40)

                    // 2. Info Section (Centered)
                    VStack(spacing: 8) {
                        Text(track.title)
                            .font(.title3.weight(.bold))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .padding(.horizontal, 40)
                        
                        Button {
                            HapticManager.shared.trigger(.light)
                            // 1. Switch to Search tab
                            appState.selectedTab = 0
                            // 2. Trigger search via notification
                            NotificationCenter.default.post(name: NSNotification.Name("PerformSearch"), object: track.artist)
                            // 3. Dismiss player
                            dismiss()
                        } label: {
                            HStack(spacing: 6) {
                                if downloadsStore.isDownloaded(id: track.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                        .font(.caption)
                                }
                                Text(track.artist)
                                    .font(.body)
                                    .foregroundStyle(.blue.opacity(0.8)) // Make it look clickable
                                    .multilineTextAlignment(.center)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(.bottom, 24)

                    // 3. Progress Slider
                    VStack(spacing: 12) {
                        Slider(
                            value: Binding(
                                get: { isSeeking ? seekTime : progressStore.currentTime },
                                set: { newValue in
                                    isSeeking = true
                                    seekTime = newValue
                                }
                            ),
                            in: 0...max(progressStore.duration, 1),
                            onEditingChanged: { editing in
                                if !editing {
                                    playerService.seek(to: seekTime)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        isSeeking = false
                                    }
                                }
                            }
                        )
                        .accentColor(.white)

                        HStack {
                            Text(formatTime(isSeeking ? seekTime : progressStore.currentTime))
                            Spacer()
                            Text(formatTime(progressStore.duration))
                        }
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)

                    // 4. Playback Controls
                    HStack(spacing: 50) {
                        Button {
                            HapticManager.shared.trigger(.medium)
                            playerService.previous()
                        } label: {
                            Image(systemName: "backward.fill").font(.title)
                        }

                        Button {
                            HapticManager.shared.trigger(.light)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                playerService.togglePlayPause()
                            }
                        } label: {
                            Image(systemName: playerService.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 48, weight: .bold))
                                .frame(width: 80, height: 80)
                                .background(Circle().fill(Color.white.opacity(0.1)))
                                .scaleEffect(playerService.isPlaying ? 1.0 : 0.9)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: playerService.isPlaying)
                        }

                        Button {
                            HapticManager.shared.trigger(.medium)
                            playerService.next()
                        } label: {
                            Image(systemName: "forward.fill").font(.title)
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.bottom, 32)

                    // 5. Volume Slider
                    HStack(spacing: 16) {
                        Image(systemName: "speaker.fill").font(.system(size: 10))
                        Slider(value: Binding(
                            get: { playerService.volume },
                            set: { playerService.setVolume($0) }
                        ), in: 0...1)
                        .accentColor(.white.opacity(0.4))
                        Image(systemName: "speaker.wave.3.fill").font(.system(size: 10))
                    }
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.horizontal, 48)
                    .padding(.bottom, 40)

                    // 6. Action Bar (Bottom Tools)
                    HStack {
                        // Shuffle/Repeat/Heart on the left-ish
                        HStack(spacing: 24) {
                            Button {
                                playerStore.toggleShuffle()
                            } label: {
                                Image(systemName: "shuffle")
                                    .foregroundStyle(playerStore.shuffleMode ? .blue : .white.opacity(0.5))
                            }
                            
                            Button {
                                playerStore.cycleRepeatMode()
                            } label: {
                                Image(systemName: playerStore.repeatMode == "one" ? "repeat.1" : "repeat")
                                    .foregroundStyle(playerStore.repeatMode != "off" ? .blue : .white.opacity(0.5))
                            }
                            
                            Button {
                                HapticManager.shared.trigger(.medium)
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                                    Task { await favoritesStore.toggleFavorite(track) }
                                }
                            } label: {
                                Image(systemName: favoritesStore.isFavorite(track.id) ? "heart.fill" : "heart")
                                    .foregroundStyle(favoritesStore.isFavorite(track.id) ? .white : .white.opacity(0.5))
                                    .scaleEffect(favoritesStore.isFavorite(track.id) ? 1.2 : 1.0)
                            }
                        }
                        
                        Spacer()
                        
                        // System tools on the right
                        HStack(spacing: 24) {
                            AirPlayButton()
                                .frame(width: 24, height: 24)
                                .foregroundStyle(.white.opacity(0.5))
                            
                            Menu {
                                Button { playerStore.addToQueueNext(track) } label: {
                                    Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                                }
                                Menu("Add to Playlist...") {
                                    ForEach(playlistsStore.playlists) { pl in
                                        Button(pl.name) { Task { await playlistsStore.addTrack(playlistId: pl.id, track: track) } }
                                    }
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            
                            Button {
                                showQueue.toggle()
                            } label: {
                                Image(systemName: "list.bullet")
                                    .foregroundStyle(showQueue ? .blue : .white.opacity(0.5))
                            }
                        }
                    }
                    .font(.body.weight(.semibold))
                    .padding(.horizontal, 40)
                    .padding(.bottom, 32)

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
        }
        .onAppear {
            Task { await playlistsStore.loadPlaylists() }
        }
        .sheet(isPresented: $showQueue) {
            QueueView(
                playerStore: playerStore,
                playerService: playerService,
                downloadsStore: downloadsStore,
                baseURL: baseURL,
                showPlayer: .constant(true)
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private func thumbURL(_ track: Track) -> URL? {
        if track.thumbnail.hasPrefix("http") {
            return URL(string: track.thumbnail)
        }
        if track.thumbnail.hasPrefix("/") {
            return URL(string: baseURL + track.thumbnail)
        }
        return URL(string: baseURL + "/" + track.thumbnail)
    }

    private func formatTime(_ seconds: Double) -> String {
        if !seconds.isFinite || seconds < 0 { return "0:00" }
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
