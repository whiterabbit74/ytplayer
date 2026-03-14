import SwiftUI

struct DownloadStatusOverlay: View {
    let progress: Double?
    let isFailed: Bool
    let cornerRadius: CGFloat
    let size: CGFloat
    
    var body: some View {
        Group {
            if let progress = progress {
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
            } else if isFailed {
                ZStack {
                    Color.black.opacity(0.4)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: size * 0.4))
                        .foregroundStyle(.red)
                        .shadow(radius: 2)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

struct TrackThumbnail: View {
    @Environment(\.baseURL) var baseURL
    let track: Track
    let size: CGFloat
    var forceSquare: Bool = true
    let cornerRadius: CGFloat
    var showStatus: Bool = true
    var downloadProgress: Double? = nil
    var isFailed: Bool = false
    var isPlaying: Bool = false
    var showEqualizer: Bool = true

    var body: some View {
        ZStack {
            CachedAsyncImage(url: track.thumbnailURL(baseURL: baseURL), contentMode: .fill)
                .frame(width: size, height: forceSquare ? size : size * 0.5625)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .animation(.spring(), value: forceSquare)

            if showStatus {
                DownloadStatusOverlay(
                    progress: downloadProgress,
                    isFailed: isFailed,
                    cornerRadius: cornerRadius,
                    size: size
                )
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
}
