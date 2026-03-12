import SwiftUI

struct TrackRow: View {
    let track: Track
    let baseURL: String
    let onPlay: () -> Void
    let onAddToQueue: () -> Void
    let isFavorite: Bool
    let onToggleFavorite: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            CachedAsyncImage(url: thumbURL, contentMode: .fill)
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(track.title).font(.headline).lineLimit(1)
                Text(track.artist).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }

            Spacer()

            Button(action: onToggleFavorite) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .foregroundStyle(isFavorite ? .red : .secondary)
            }
            Button(action: onAddToQueue) {
                Image(systemName: "text.badge.plus")
            }
            Button(action: onPlay) {
                Image(systemName: "play.fill")
            }
            .accessibilityIdentifier("playButton")
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onPlay)
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
