import Foundation

final class PlayerStore: ObservableObject {
    @Published var currentTrack: Track?
    @Published var queue: [Track] = []
    @Published var currentIndex: Int = -1
    @Published var isPlaying: Bool = false
    @Published var repeatMode: String = "off" // "off", "one", "all"
    @Published var position: Double = 0

    private var api: APIClient?

    func configure(api: APIClient) {
        self.api = api
    }

    /// Play a track — adds it to queue if not already there.
    func play(_ track: Track) {
        if let idx = queue.firstIndex(of: track) {
            currentIndex = idx
        } else {
            // Track not in queue — set entire queue to just this track
            queue.append(track)
            currentIndex = queue.count - 1
        }
        currentTrack = track
        isPlaying = true
    }

    /// Play a track from queue and also set the whole queue context.
    func playTrackInContext(_ track: Track, queue newQueue: [Track]) {
        queue = newQueue
        if let idx = newQueue.firstIndex(of: track) {
            currentIndex = idx
        } else {
            currentIndex = 0
        }
        currentTrack = track
        isPlaying = true
    }

    func playFromQueue(index: Int) {
        guard index >= 0 && index < queue.count else { return }
        currentIndex = index
        currentTrack = queue[index]
        isPlaying = true
    }

    func addToQueue(_ track: Track) {
        queue.append(track)
    }

    func removeFromQueue(index: Int) {
        guard index >= 0 && index < queue.count else { return }
        queue.remove(at: index)
        if queue.isEmpty {
            currentIndex = -1
            currentTrack = nil
            isPlaying = false
            return
        }
        if index < currentIndex {
            currentIndex -= 1
        } else if index == currentIndex {
            // Current track was removed
            if currentIndex >= queue.count {
                currentIndex = queue.count - 1
            }
            currentTrack = currentIndex >= 0 ? queue[currentIndex] : nil
        }
    }

    func moveQueue(from: IndexSet, to: Int) {
        queue.move(fromOffsets: from, toOffset: to)
        if let current = currentTrack, let newIndex = queue.firstIndex(of: current) {
            currentIndex = newIndex
            return
        }
        if currentIndex >= queue.count {
            currentIndex = queue.count - 1
        }
    }

    func setQueue(_ tracks: [Track], index: Int = 0) {
        queue = tracks
        currentIndex = index
        currentTrack = tracks.indices.contains(index) ? tracks[index] : nil
    }

    func clearQueue() {
        queue = []
        currentIndex = -1
        currentTrack = nil
        isPlaying = false
    }

    /// Returns true if a next track was found, false if playback should stop.
    @discardableResult
    func playNext() -> Bool {
        guard !queue.isEmpty else {
            isPlaying = false
            return false
        }
        let next = currentIndex + 1
        if next >= queue.count {
            if repeatMode == "all" {
                playFromQueue(index: 0)
                return true
            }
            isPlaying = false
            return false
        }
        playFromQueue(index: next)
        return true
    }

    func playPrev() {
        guard !queue.isEmpty else { return }
        let prev = currentIndex - 1
        if prev < 0 {
            if repeatMode == "all" {
                playFromQueue(index: queue.count - 1)
                return
            }
            return
        }
        playFromQueue(index: prev)
    }
}
