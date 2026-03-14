import SwiftUI

struct TrackThumbnail: View {
    let track: Track
    let size: CGFloat
    var forceSquare: Bool = true
    let cornerRadius: CGFloat
    var showStatus: Bool = true
    let baseURL: String
    var downloadProgress: Double? = nil
    var isFailed: Bool = false
    @State private var shakeAmount: CGFloat = 0

    var showEqualizer: Bool = true

    var body: some View {
        ZStack {
            CachedAsyncImage(url: thumbURL, contentMode: .fill)
                .frame(width: size, height: forceSquare ? size : size * 0.5625)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .animation(.spring(), value: forceSquare)

            if showStatus {
                if let progress = downloadProgress {
                    ZStack {
                        Color.black.opacity(0.5)
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: size * 0.06)
                            .frame(width: size * 0.5, height: size * 0.5)
                        Circle()
                            .trim(from: 0, to: CGFloat(max(0.05, progress)))
                            .stroke(Color.white, style: StrokeStyle(lineWidth: size * 0.06, lineCap: .round))
                            .frame(width: size * 0.5, height: size * 0.5)
                            .rotationEffect(.degrees(-90))
                            .animation(progress < 0.05 ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: progress)
                            .shadow(radius: 2)
                    }
                    .frame(width: size, height: size)
                } else if isFailed {
                    ZStack {
                        Color.black.opacity(0.4)
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: size * 0.4))
                            .foregroundStyle(.red)
                            .shadow(radius: 2)
                            .modifier(ShakeEffect(animatableData: shakeAmount))
                    }
                    .frame(width: size, height: size)
                    .onAppear {
                        if isFailed {
                            withAnimation(.linear(duration: 0.5)) { shakeAmount = 1 }
                        }
                    }
                }
            }
            
            if isPlaying && showEqualizer {
                ZStack {
                    Color.black.opacity(0.3)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    EqualizerIndicator()
                        .scaleEffect(size / 48.0)
                }
                .frame(width: size, height: size)
            }
        }
    }

    private var isPlaying: Bool { _isPlaying }
    private let _isPlaying: Bool

    init(
        track: Track,
        size: CGFloat,
        forceSquare: Bool = true,
        cornerRadius: CGFloat,
        showStatus: Bool = true,
        baseURL: String,
        downloadProgress: Double? = nil,
        isFailed: Bool = false,
        isPlaying: Bool = false,
        showEqualizer: Bool = true
    ) {
        self.track = track
        self.size = size
        self.forceSquare = forceSquare
        self.cornerRadius = cornerRadius
        self.showStatus = showStatus
        self.baseURL = baseURL
        self.downloadProgress = downloadProgress
        self.isFailed = isFailed
        self._isPlaying = isPlaying
        self.showEqualizer = showEqualizer
    }

    private var thumbURL: URL? {
        let cleaned = track.thumbnail
        if cleaned.hasPrefix("http") { return URL(string: cleaned) }
        if cleaned.hasPrefix("/") { return URL(string: baseURL + cleaned) }
        return URL(string: baseURL + "/" + cleaned)
    }
}
