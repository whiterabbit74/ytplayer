import SwiftUI

struct PlayerFullView: View {
    @ObservedObject var playerStore: PlayerStore
    @ObservedObject var playerService: PlayerService
    @ObservedObject var downloadsStore: DownloadsStore
    @ObservedObject var favoritesStore: FavoritesStore
    @ObservedObject var playlistsStore: PlaylistsStore
    let progressStore: PlaybackProgressStore // Pass by value/reference without observation
    let baseURL: String
    let dynamicBackgroundEnabled: Bool
    let coverStyle: AppState.CoverStyle
    let squareCovers: Bool

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
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
                                downloadProgress: downloadsStore.downloadProgresses[track.id],
                                isFailed: downloadsStore.failedDownloads.contains(track.id)
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
                                downloadProgress: downloadsStore.downloadProgresses[track.id],
                                isFailed: downloadsStore.failedDownloads.contains(track.id),
                                isPlaying: playerService.isPlaying,
                                showEqualizer: false
                            )
                            .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 15)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        }
                    }
                    // Apply animation to track changes
                    .id(track.id)
                    .animation(.easeInOut(duration: 0.4), value: track.id)
                    
                    Spacer(minLength: 40)

                    // 2. Info Section (Centered)
                    VStack(spacing: 8) {
                        MarqueeText(text: track.title, font: .title3.weight(.bold), speed: 20)
                            .padding(.horizontal, 40)
                        
                        Button {
                            HapticManager.shared.trigger(.light)
                            appState.selectedTab = 0
                            NotificationCenter.default.post(name: NSNotification.Name("PerformSearch"), object: track.artist)
                            dismiss()
                        } label: {
                            HStack(spacing: 6) {
                                if downloadsStore.isDownloaded(id: track.id) {
                                    DownloadIcon(size: .medium)
                                }
                                TrackMetadataView(track: track, showDuration: false)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, 24)

                    // 3. Progress Slider
                    PlayerProgressSlider(progressStore: progressStore, playerService: playerService)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 24)

                    // 4. Playback Controls
                    HStack(spacing: 50) {
                        Button {
                            HapticManager.shared.trigger(.medium)
                            playerService.previous()
                        } label: {
                            Image(systemName: "backward.fill").font(.title)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(ScaleButtonStyle())

                        PlayPauseButton(
                            isPlaying: playerService.isPlaying,
                            isBuffering: playerService.isBuffering,
                            action: { playerService.togglePlayPause() },
                            style: .large
                        )

                        Button {
                            HapticManager.shared.trigger(.medium)
                            playerService.next()
                        } label: {
                            Image(systemName: "forward.fill").font(.title)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(ScaleButtonStyle())
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
                        // Left-side: Like and More Menu
                        HStack(spacing: 24) {
                            // Like
                            FavoriteButton(
                                isFavorite: favoritesStore.isFavorite(track.id),
                                action: { Task { await favoritesStore.toggleFavorite(track) } },
                                size: 24,
                                style: .standard
                            )
                            
                            // More Menu (Ellipsis)
                            Menu {
                                Section {
                                    Button {
                                        playerStore.toggleShuffle()
                                    } label: {
                                        Label(
                                            playerStore.shuffleMode ? "Shuffle: On" : "Shuffle: Off",
                                            systemImage: "shuffle"
                                        )
                                    }
                                    
                                    Button {
                                        playerStore.cycleRepeatMode()
                                    } label: {
                                        let modeText = playerStore.repeatMode == "one" ? "Repeat: One" : (playerStore.repeatMode == "all" ? "Repeat: All" : "Repeat: Off")
                                        Label(
                                            modeText,
                                            systemImage: playerStore.repeatMode == "one" ? "repeat.1" : "repeat"
                                        )
                                    }
                                }
                                
                                Section {
                                    Button { playerStore.addToQueueNext(track) } label: {
                                        Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                                    }
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                        
                        Spacer()
                        
                        // Center-side: Current Output
                        AudioRouteLabel()
                        
                        Spacer()
                        
                        // Right-side: Playlists and Queue
                        HStack(spacing: 24) {
                            Menu {
                                ForEach(playlistsStore.playlists) { pl in
                                    Button(pl.name) { Task { await playlistsStore.addTrack(playlistId: pl.id, track: track) } }
                                }
                            } label: {
                                Image(systemName: "plus.square.on.square")
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
}
