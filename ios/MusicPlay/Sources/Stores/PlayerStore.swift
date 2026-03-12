import Foundation

final class PlayerStore: ObservableObject {
    @Published var currentTrack: Track?
    @Published var queue: [Track] = []
    @Published var currentIndex: Int = -1
    @Published var isPlaying: Bool = false
    @Published var repeatMode: String = "off"
    @Published var position: Double = 0

    private var api: APIClient?

    func configure(api: APIClient) {
        self.api = api
    }

    func play(_ track: Track) {
        if let idx = queue.firstIndex(of: track) {
            currentIndex = idx
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
        if index < currentIndex { currentIndex -= 1 }
        if index == currentIndex {
            if currentIndex >= queue.count { currentIndex = queue.count - 1 }
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

    func playNext() {
        let next = currentIndex + 1
        if next >= queue.count {
            isPlaying = false
            return
        }
        playFromQueue(index: next)
    }

    func playPrev() {
        let prev = currentIndex - 1
        if prev < 0 { return }
        playFromQueue(index: prev)
    }
}
