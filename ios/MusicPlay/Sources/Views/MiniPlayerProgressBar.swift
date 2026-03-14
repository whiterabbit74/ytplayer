import SwiftUI

struct MiniPlayerProgressBar: View {
    @ObservedObject var progressStore: PlaybackProgressStore
    
    var body: some View {
        GeometryReader { geo in
            let progress = progressStore.progress
            Rectangle()
                .fill(Color.white)
                .frame(width: geo.size.width * min(max(progress, 0), 1))
        }
        .frame(height: 2)
    }
}
