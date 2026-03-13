import SwiftUI

struct TrackThumbnail: View {
    let track: Track
    let size: CGFloat
    var forceSquare: Bool = true
    let cornerRadius: CGFloat
    var showStatus: Bool = true
    let baseURL: String
    @ObservedObject var downloadsStore: DownloadsStore

    var body: some View {
        ZStack {
            CachedAsyncImage(url: thumbURL, contentMode: .fill)
                .frame(width: size, height: forceSquare ? size : size * 0.5625)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .animation(.spring(), value: forceSquare)

            if showStatus {
                if let progress = downloadsStore.downloadProgresses[track.id] {
                    // Download progress overlay
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
                } else if downloadsStore.failedDownloads.contains(track.id) {
                    // Failed indicator
                    ZStack {
                        Color.black.opacity(0.4)
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                        
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: size * 0.4))
                            .foregroundStyle(.red)
                            .shadow(radius: 2)
                    }
                    .frame(width: size, height: size)
                }
            }
        }
    }

    private var thumbURL: URL? {
        let cleaned = track.thumbnail
        if cleaned.hasPrefix("http") {
            return URL(string: cleaned)
        }
        if cleaned.hasPrefix("/") {
            return URL(string: baseURL + cleaned)
        }
        return URL(string: baseURL + "/" + cleaned)
    }
}
