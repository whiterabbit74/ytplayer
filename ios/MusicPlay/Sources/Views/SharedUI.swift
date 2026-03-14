import SwiftUI

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
