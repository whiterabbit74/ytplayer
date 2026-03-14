import SwiftUI

struct PlayerProgressSlider: View {
    @ObservedObject var progressStore: PlaybackProgressStore
    @ObservedObject var playerService: PlayerService
    
    @State private var isSeeking = false
    @State private var seekTime: Double = 0
    
    var body: some View {
        VStack(spacing: 12) {
            Slider(
                value: Binding(
                    get: { isSeeking ? seekTime : progressStore.currentTime },
                    set: { newValue in
                        isSeeking = true
                        seekTime = newValue
                    }
                ),
                in: 0...max(progressStore.duration, 1),
                onEditingChanged: { editing in
                    if !editing {
                        playerService.seek(to: seekTime)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isSeeking = false
                        }
                    }
                }
            )
            .accentColor(.white)

            HStack {
                Text(formatTime(isSeeking ? seekTime : progressStore.currentTime))
                Spacer()
                Text(formatTime(progressStore.duration))
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.white.opacity(0.5))
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        if !seconds.isFinite || seconds < 0 { return "0:00" }
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
