import SwiftUI
import AVFoundation
import AVKit

// MARK: - Shared Views

struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.backgroundColor = .clear
        picker.tintColor = .white
        picker.activeTintColor = .white
        return picker
    }
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

struct MiniPlayerSpacer: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        if appState.playerStore.currentTrack != nil {
            Color.clear.frame(height: 70)
        }
    }
}

struct TrackMetadataView: View {
    let track: Track
    var showDuration: Bool = true
    var color: Color = .secondary
    
    var body: some View {
        HStack(spacing: 4) {
            Text(track.artist)
            if showDuration {
                Text("•")
                Text(track.formattedDuration)
            }
        }
        .font(.subheadline)
        .foregroundStyle(color)
        .lineLimit(1)
    }
}

struct DownloadIcon: View {
    enum IconSize {
        case small, medium, custom(CGFloat)
        var value: CGFloat {
            switch self {
            case .small: return 10
            case .medium: return 14
            case .custom(let size): return size
            }
        }
    }
    let size: IconSize
    var showShadow: Bool = false
    init(size: IconSize = .small, showShadow: Bool = false) {
        self.size = size
        self.showShadow = showShadow
    }
    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.green)
            .font(.system(size: size.value))
            .if(showShadow) { $0.shadow(color: .green.opacity(0.4), radius: 2) }
    }
}

struct FavoriteButton: View {
    let isFavorite: Bool
    let action: () -> Void
    var size: CGFloat = 24
    var style: Style = .standard
    enum Style { case standard, monochrome }
    var body: some View {
        Button {
            HapticManager.shared.trigger(.medium)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { action() }
        } label: {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.system(size: size))
                .foregroundStyle(isFavorite ? .red : (style == .standard ? .white.opacity(0.5) : .secondary))
                .scaleEffect(isFavorite ? 1.1 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

struct PlayPauseButton: View {
    let isPlaying: Bool
    let isBuffering: Bool
    let action: () -> Void
    var style: Style = .row
    enum Style { case large, mini, row }
    var body: some View {
        Button {
            HapticManager.shared.trigger(style == .large ? .light : .selection)
            action()
        } label: {
            ZStack {
                if style == .large {
                    Circle().fill(Color.white.opacity(0.1)).frame(width: 80, height: 80)
                }
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(style == .large ? .system(size: 48, weight: .bold) : (style == .mini ? .title2 : .caption))
                    .contentTransition(.symbolEffect(.replace))
                    .opacity(isBuffering ? 0 : 1)
                if isBuffering {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(style == .large ? 1.5 : 1.0)
                }
            }
            .if(style == .large) { $0.scaleEffect(isPlaying ? 1.0 : 0.9) }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPlaying)
        .animation(.default, value: isBuffering)
    }
}

struct AudioRouteLabel: View {
    @State private var routeName: String = "iPhone"
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    var body: some View {
        ZStack {
            // Слой-приемник касаний (AirPlayButton/AVRoutePickerView)
            // Должен быть внизу и занимать все пространство, чтобы ловить тапы.
            AirPlayButton()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(0.011) // Минимальная видимость для сохранения кликабельности
            
            // Визуальный слой
            HStack(spacing: 8) {
                Image(systemName: "airplayaudio")
                    .font(.system(size: 14))
                Text(routeName).font(.caption.weight(.medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.1))
            .clipShape(Capsule())
            .foregroundStyle(.white.opacity(0.8))
            .allowsHitTesting(false) // Пропускаем касания к нижнему слою
        }
        .fixedSize() // Важно: ZStack должен сжаться до размеров визуального слоя
        .onAppear(perform: updateRoute)
        .onReceive(timer) { _ in updateRoute() }
    }
    private func updateRoute() {
        if let output = AVAudioSession.sharedInstance().currentRoute.outputs.first {
            routeName = output.portName
        }
    }
}

// MARK: - Playback Controls

struct PlaybackControlsRow: View {
    let isPlaying: Bool
    let isBuffering: Bool
    let onPrevious: () -> Void
    let onTogglePlay: () -> Void
    let onNext: () -> Void
    var style: PlayPauseButton.Style = .row
    
    var body: some View {
        HStack(spacing: style == .large ? 40 : 12) {
            Button(action: {
                HapticManager.shared.trigger(.selection)
                onPrevious()
            }) {
                Image(systemName: "backward.fill")
                    .font(style == .large ? .title : .body)
            }
            .buttonStyle(.plain)
            
            PlayPauseButton(
                isPlaying: isPlaying,
                isBuffering: isBuffering,
                action: onTogglePlay,
                style: style
            )
            
            Button(action: {
                HapticManager.shared.trigger(.selection)
                onNext()
            }) {
                Image(systemName: "forward.fill")
                    .font(style == .large ? .title : .body)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Track Menu

struct TrackMenuContent: View {
    let track: Track
    let onPlay: () -> Void
    let onAddToQueue: () -> Void
    var onToggleFavorite: (() -> Void)? = nil
    var isFavorite: Bool = false
    var onRemove: (() -> Void)? = nil
    
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var playerStore: PlayerStore
    @EnvironmentObject var playerService: PlayerService
    @EnvironmentObject var downloadsStore: DownloadsStore
    @EnvironmentObject var playlistsStore: PlaylistsStore
    
    var body: some View {
        Group {
            Button(action: onPlay) {
                Label("Play", systemImage: "play")
            }
            
            Button(action: onAddToQueue) {
                Label("Add to Queue", systemImage: "text.badge.plus")
            }
            
            Button {
                playerStore.addToQueueNext(track)
            } label: {
                Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
            }
            
            if let onToggleFavorite {
                Button(action: onToggleFavorite) {
                    Label(isFavorite ? "Remove from Favorites" : "Add to Favorites", 
                          systemImage: isFavorite ? "heart.fill" : "heart")
                }
            }
            
            downloadSection
            
            playlistMenu
            
            if let onRemove {
                Button(role: .destructive, action: onRemove) {
                    Label("Remove", systemImage: "trash")
                }
            }
        }
    }
    
    @ViewBuilder
    private var downloadSection: some View {
        let isDownloaded = downloadsStore.isTrackDownloaded(track.id)
        let isDownloading = downloadsStore.isDownloading(track.id)
        let isFailed = downloadsStore.isFailed(track.id)
        
        if isDownloading {
            Button(role: .destructive) {
                downloadsStore.removeTrack(track.id)
                AudioCacheService.shared.removeTrack(id: track.id)
            } label: {
                Label("Cancel Download", systemImage: "xmark.circle")
            }
        } else if isFailed {
            Button {
                playerService.downloadTrack(track)
            } label: {
                Label("Retry Download", systemImage: "arrow.clockwise.circle")
            }
            
            Button(role: .destructive) {
                downloadsStore.removeTrack(track.id)
                AudioCacheService.shared.removeTrack(id: track.id)
            } label: {
                Label("Remove from Downloads", systemImage: "trash")
            }
        } else {
            Button {
                if isDownloaded {
                    downloadsStore.removeTrack(track.id)
                    AudioCacheService.shared.removeTrack(id: track.id)
                } else {
                    playerService.downloadTrack(track)
                }
            } label: {
                Label(isDownloaded ? "Remove Download" : "Download", 
                      systemImage: isDownloaded ? "trash" : "arrow.down.circle")
            }
        }
    }
    
    private var playlistMenu: some View {
        Menu {
            ForEach(playlistsStore.playlists) { pl in
                Button(pl.name) {
                    Task { await playlistsStore.addTrack(playlistId: pl.id, track: track) }
                }
            }
        } label: {
            Label("Add to Playlist", systemImage: "folder.badge.plus")
        }
    }
}

// MARK: - Extensions

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }
}

// MARK: - Environment

struct BaseURLEnvironmentKey: EnvironmentKey {
    static let defaultValue: String = "http://localhost:3001"
}

extension EnvironmentValues {
    var baseURL: String {
        get { self[BaseURLEnvironmentKey.self] }
        set { self[BaseURLEnvironmentKey.self] = newValue }
    }
}
