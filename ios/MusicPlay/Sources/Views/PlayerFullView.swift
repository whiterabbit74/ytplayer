import SwiftUI

struct PlayerFullView: View {
    @Environment(\.baseURL) var baseURL
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    
    @ObservedObject var playerStore: PlayerStore
    @ObservedObject var playerService: PlayerService
    @ObservedObject var downloadsStore: DownloadsStore
    @ObservedObject var favoritesStore: FavoritesStore
    @ObservedObject var playlistsStore: PlaylistsStore
    let progressStore: PlaybackProgressStore

    @State private var showQueue = false

    var body: some View {
        ZStack {
            // Background
            if appState.dynamicBackgroundEnabled, let track = playerStore.currentTrack {
                DynamicBackgroundView(thumbnailURL: track.thumbnailURL(baseURL: baseURL))
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
                    // Artwork Section
                    Spacer(minLength: 20)
                    
                    Group {
                        if appState.coverStyle == .vinyl {
                            VinylRecordView(
                                track: track,
                                size: 210,
                                playerService: playerService,
                                downloadProgress: downloadsStore.progress(for: track.id),
                                isFailed: downloadsStore.isFailed(track.id)
                            )
                            .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
                        } else {
                            TrackThumbnail(
                                track: track,
                                size: 300,
                                forceSquare: appState.squareCovers,
                                cornerRadius: 12,
                                showStatus: false,
                                downloadProgress: downloadsStore.progress(for: track.id),
                                isFailed: downloadsStore.isFailed(track.id),
                                isPlaying: playerService.isPlaying,
                                showEqualizer: false
                            )
                            .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 15)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        }
                    }
                    .id(track.id)
                    .animation(.easeInOut(duration: 0.4), value: track.id)
                    
                    Spacer(minLength: 40)

                    // Info Section
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
                                if downloadsStore.isTrackDownloaded(track.id) {
                                    DownloadIcon(size: .medium)
                                }
                                TrackMetadataView(track: track, showDuration: false)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, 24)

                    // Progress Slider
                    PlayerProgressSlider(progressStore: progressStore, playerService: playerService)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 24)

                    // Playback Controls Row
                    PlaybackControlsRow(
                        isPlaying: playerService.isPlaying,
                        isBuffering: playerService.isBuffering,
                        onPrevious: { playerService.previous() },
                        onTogglePlay: { playerService.togglePlayPause() },
                        onNext: { playerService.next() },
                        style: .large
                    )
                    .foregroundStyle(.white)
                    .padding(.bottom, 32)

                    // Volume Slider
                    if appState.showVolumeSlider {
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
                    } else {
                        Spacer().frame(height: 20)
                    }

                    // Action Bar
                    HStack {
                        HStack(spacing: 24) {
                            FavoriteButton(
                                isFavorite: favoritesStore.isFavorite(track.id),
                                action: { Task { await favoritesStore.toggleFavorite(track) } },
                                size: 24,
                                style: .standard
                            )
                            
                            Menu {
                                Section {
                                    Button { playerStore.toggleShuffle() } label: {
                                        Label(playerStore.shuffleMode ? "Shuffle: On" : "Shuffle: Off", systemImage: "shuffle")
                                    }
                                    Button { playerStore.cycleRepeatMode() } label: {
                                        let modeText = playerStore.repeatMode == "one" ? "Repeat: One" : (playerStore.repeatMode == "all" ? "Repeat: All" : "Repeat: Off")
                                        Label(modeText, systemImage: playerStore.repeatMode == "one" ? "repeat.1" : "repeat")
                                    }
                                }
                                Section {
                                    TrackMenuContent(
                                        track: track,
                                        onPlay: { playerService.playTrack(track) },
                                        onAddToQueue: { playerStore.addToQueue(track) }
                                    )
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                        
                        Spacer()
                        AudioRouteLabel()
                        Spacer()
                        
                        HStack(spacing: 24) {
                            Menu {
                                ForEach(playlistsStore.playlists) { pl in
                                    Button(pl.name) { Task { await playlistsStore.addTrack(playlistId: pl.id, track: track) } }
                                }
                            } label: {
                                Image(systemName: "plus.square.on.square")
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            
                            Button { showQueue.toggle() } label: {
                                Image(systemName: "list.bullet")
                                    .foregroundStyle(showQueue ? .blue : .white.opacity(0.5))
                            }
                        }
                    }
                    .font(.body.weight(.semibold))
                    .padding(.horizontal, 40)
                    .padding(.bottom, 32)

                } else {
                    ContentUnavailableView(
                        "No track playing",
                        systemImage: "music.note",
                        description: Text("Select a track to start playback")
                    )
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
                showPlayer: .constant(true)
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}
