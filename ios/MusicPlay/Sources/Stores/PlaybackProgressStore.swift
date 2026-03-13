import Foundation
import Combine

/// A dedicated, lightweight store for high-frequency playback updates.
/// By isolating these updates, we prevent entire lists (Queue, Search results) 
/// from re-rendering twice a second during active playback.
final class PlaybackProgressStore: ObservableObject {
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var isPlaying: Bool = false
    @Published var isBuffering: Bool = false
    
    // Calculated property for easy progress access
    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(currentTime / duration, 0), 1)
    }
}
