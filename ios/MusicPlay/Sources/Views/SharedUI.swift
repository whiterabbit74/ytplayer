import SwiftUI
import AVFoundation
import AVKit

// MARK: - Shared Views

// MARK: - AirPlay Control (Robust Implementation)

struct AudioRouteLabel: View {
    @State private var routeName: String = "iPhone"
    
    var body: some View {
        AudioRoutePickerRepresentable(routeName: $routeName)
            .frame(minWidth: 80)
            .frame(height: 26)
    }
}

private struct AudioRoutePickerRepresentable: UIViewRepresentable {
    @Binding var routeName: String
    
    func makeUIView(context: Context) -> AudioRoutePickerContainerView {
        let view = AudioRoutePickerContainerView()
        return view
    }
    
    func updateUIView(_ uiView: AudioRoutePickerContainerView, context: Context) {
        uiView.onRouteChanged = { newName in
            if routeName != newName {
                routeName = newName
            }
        }
    }
}

private final class AudioRoutePickerContainerView: UIControl {
    private let routePickerView = AVRoutePickerView(frame: .zero)
    private let stackView = UIStackView()
    private let iconView = UIImageView(image: UIImage(systemName: "airplayaudio"))
    private let titleLabel = UILabel()
    private let backgroundView = UIView()
    
    var onRouteChanged: ((String) -> Void)?
    private var timer: Timer?

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.15) {
                self.alpha = self.isHighlighted ? 0.6 : 1.0
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.95, y: 0.95) : .identity
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        // Visual container
        backgroundView.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        backgroundView.layer.cornerRadius = 13
        backgroundView.isUserInteractionEnabled = false
        addSubview(backgroundView)
        
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 6
        stackView.isUserInteractionEnabled = false
        addSubview(stackView)
        
        let config = UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        iconView.image = UIImage(systemName: "airplayaudio", withConfiguration: config)
        iconView.tintColor = .white.withAlphaComponent(0.9)
        iconView.contentMode = .scaleAspectFit
        
        titleLabel.font = .systemFont(ofSize: 11, weight: .bold)
        titleLabel.textColor = .white.withAlphaComponent(0.9)
        titleLabel.text = "iPhone"
        
        stackView.addArrangedSubview(iconView)
        stackView.addArrangedSubview(titleLabel)
        
        // The "Secret Sauce" - Hidden but functional AVRoutePickerView
        routePickerView.alpha = 0.01
        routePickerView.isUserInteractionEnabled = false 
        addSubview(routePickerView)
        
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        routePickerView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),
            
            routePickerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            routePickerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            routePickerView.widthAnchor.constraint(equalToConstant: 2),
            routePickerView.heightAnchor.constraint(equalToConstant: 2)
        ])
        
        // Add target to the container itself
        addTarget(self, action: #selector(openRoutePicker), for: .touchUpInside)
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.updateRouteName()
        }
        updateRouteName()
    }
    
    @objc private func openRoutePicker() {
        HapticManager.shared.trigger(.light)
        
        // Strategy: trigger the button inside AVRoutePickerView
        if let routeButton = routePickerView.subviews.first(where: { $0 is UIButton }) as? UIButton {
            routeButton.sendActions(for: .touchUpInside)
        } else if let someControl = routePickerView.firstDescendant(of: UIControl.self) {
            someControl.sendActions(for: .touchUpInside)
        }
    }
    
    private func updateRouteName() {
        let currentRoute = AVAudioSession.sharedInstance().currentRoute
        let name = currentRoute.outputs.first?.portName ?? "iPhone"
        
        if titleLabel.text != name {
            UIView.transition(with: titleLabel, duration: 0.2, options: .transitionCrossDissolve) {
                self.titleLabel.text = name
            }
            onRouteChanged?(name)
        }
    }

    deinit {
        timer?.invalidate()
    }
}

private extension UIView {
    func firstDescendant<T: UIView>(of type: T.Type) -> T? {
        for subview in subviews {
            if let match = subview as? T { return match }
            if let nested = subview.firstDescendant(of: type) { return nested }
        }
        return nil
    }
}

// MARK: - MiniPlayerSpacer

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
