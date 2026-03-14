import Foundation

/// A wrapper for a track in the playback queue to allow multiple occurrences of the same track.
struct QueueItem: Identifiable, Equatable, Codable {
    let id: UUID
    let track: Track
    
    init(track: Track) {
        self.id = UUID()
        self.track = track
    }
    
    init(id: UUID, track: Track) {
        self.id = id
        self.track = track
    }
    
    static func == (lhs: QueueItem, rhs: QueueItem) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
final class PlayerStore: ObservableObject {
    @Published var currentTrack: Track?
    @Published var queue: [QueueItem] = []
    @Published var currentIndex: Int = -1
    @Published var isPlaying: Bool = false
    @Published var repeatMode: String = "off" // "off", "one", "all"
    @Published var shuffleMode: Bool = false

    private var api: APIClient?
    private var originalQueue: [QueueItem] = []

    func configure(api: APIClient) {
        self.api = api
    }

    /// Play a track — adds it to queue if not already there.
    func play(_ track: Track) {
        if !queue.isEmpty && currentIndex >= 0 && currentIndex < queue.count && queue[currentIndex].track.id == track.id {
            // Already playing this track at this position, just sync state
            currentTrack = track
            return
        }
        
        if let idx = queue.firstIndex(where: { $0.track.id == track.id }) {
            currentIndex = idx
        } else {
            let item = QueueItem(track: track)
            queue.append(item)
            if shuffleMode {
                originalQueue.append(item)
            }
            currentIndex = queue.count - 1
        }
        currentTrack = queue[currentIndex].track
    }

    /// Play a track from queue and also set the whole queue context.
    func playTrackInContext(_ track: Track, queue newTracks: [Track]) {
        let newQueue = newTracks.map { QueueItem(track: $0) }
        self.queue = newQueue
        self.originalQueue = newQueue
        
        if let idx = newTracks.firstIndex(of: track) {
            currentIndex = idx
        } else {
            currentIndex = 0
        }
        
        // If shuffle is on, shuffle the new queue immediately (but keep chosen track at its logical position or top)
        if shuffleMode && !queue.isEmpty {
            if queue.indices.contains(currentIndex) {
                let current = queue.remove(at: currentIndex)
                queue.shuffle()
                queue.insert(current, at: 0)
                currentIndex = 0
            } else {
                queue.shuffle()
                currentIndex = 0
            }
        }
        
        currentTrack = queue.indices.contains(currentIndex) ? queue[currentIndex].track : nil
    }

    func playFromQueue(index: Int) {
        guard index >= 0 && index < queue.count else { return }
        currentIndex = index
        currentTrack = queue[index].track
    }

    func addToQueue(_ track: Track) {
        let item = QueueItem(track: track)
        queue.append(item)
        originalQueue.append(item)
    }

    func addToQueueNext(_ track: Track) {
        let item = QueueItem(track: track)
        let insertIndex = currentIndex + 1
        if insertIndex >= 0 && insertIndex <= queue.count {
            queue.insert(item, at: insertIndex)
            // Also insert into original queue at a logical place (e.g. after current track's original position)
            if let current = currentTrack, let origIdx = originalQueue.firstIndex(where: { $0.track.id == current.id }) {
                originalQueue.insert(item, at: origIdx + 1)
            } else {
                originalQueue.append(item)
            }
        } else {
            queue.append(item)
            originalQueue.append(item)
        }
    }

    func removeFromQueue(index: Int) {
        guard index >= 0 && index < queue.count else { return }
        let removedItem = queue.remove(at: index)
        originalQueue.removeAll { $0.id == removedItem.id }
        
        if queue.isEmpty {
            currentIndex = -1
            currentTrack = nil
            return
        }
        if index < currentIndex {
            currentIndex -= 1
        } else if index == currentIndex {
            // Current track was removed
            if currentIndex >= queue.count {
                currentIndex = queue.count - 1
            }
            currentTrack = currentIndex >= 0 ? queue[currentIndex].track : nil
        }
    }

    func moveQueue(from: IndexSet, to: Int) {
        queue.move(fromOffsets: from, toOffset: to)
        if let current = currentTrack, let newIndex = queue.firstIndex(where: { $0.track.id == current.id }) {
            currentIndex = newIndex
            return
        }
        if currentIndex >= queue.count {
            currentIndex = queue.count - 1
        }
    }

    func setQueue(_ tracks: [Track], index: Int = 0) {
        let newQueue = tracks.map { QueueItem(track: $0) }
        queue = newQueue
        originalQueue = newQueue
        currentIndex = index
        currentTrack = queue.indices.contains(index) ? queue[index].track : nil
    }

    @Published var isAnticipatingNext: Bool = false

    func clearQueue() {
        queue = []
        originalQueue = []
        currentIndex = -1
        currentTrack = nil
        isAnticipatingNext = false
    }

    /// Returns true if a next track was found, false if playback should stop.
    @discardableResult
    func playNext(isAutoTrigger: Bool = false) -> Bool {
        guard !queue.isEmpty else { return false }
        
        // Systemic fix: If this is a manual skip but we already anticipated the next track via crossfade,
        // we don't need to advance the index again! We just need to sync the state.
        if !isAutoTrigger && isAnticipatingNext {
            isAnticipatingNext = false
            return true
        }
        
        let next = currentIndex + 1
        if next >= queue.count {
            if repeatMode == "all" {
                playFromQueue(index: 0)
                isAnticipatingNext = isAutoTrigger
                return true
            }
            isAnticipatingNext = false
            return false
        }
        playFromQueue(index: next)
        isAnticipatingNext = isAutoTrigger
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

    func toggleShuffle() {
        shuffleMode.toggle()
        if shuffleMode {
            if originalQueue.isEmpty && !queue.isEmpty {
                originalQueue = queue
            }
            if currentIndex >= 0 && currentIndex < queue.count {
                let current = queue.remove(at: currentIndex)
                queue.shuffle()
                queue.insert(current, at: 0)
                currentIndex = 0
            } else {
                queue.shuffle()
            }
        } else {
            if !originalQueue.isEmpty {
                let currentItem = currentIndex >= 0 && currentIndex < queue.count ? queue[currentIndex] : nil
                queue = originalQueue
                if let currentItem = currentItem, let newIdx = queue.firstIndex(where: { $0.id == currentItem.id }) {
                    currentIndex = newIdx
                }
            }
        }
    }

    func updateTrackDuration(id: String, duration: Int) {
        // Update in currentTrack
        if let updated = currentTrack, updated.id == id && updated.duration != duration {
            // We need a way to mutate Track, but it's a struct with let properties.
            // Let's create a copy with new duration.
            currentTrack = Track(
                id: updated.id,
                title: updated.title,
                artist: updated.artist,
                thumbnail: updated.thumbnail,
                duration: duration,
                viewCount: updated.viewCount,
                likeCount: updated.likeCount,
                rowId: updated.rowId
            )
        }
        
        // Update in queue
        var changed = false
        for i in 0..<queue.count {
            if queue[i].track.id == id && queue[i].track.duration != duration {
                let updated = queue[i].track
                let newTrack = Track(
                    id: updated.id,
                    title: updated.title,
                    artist: updated.artist,
                    thumbnail: updated.thumbnail,
                    duration: duration,
                    viewCount: updated.viewCount,
                    likeCount: updated.likeCount,
                    rowId: updated.rowId
                )
                queue[i] = QueueItem(id: queue[i].id, track: newTrack)
                changed = true
            }
        }
        
        // For originalQueue too
        for i in 0..<originalQueue.count {
            if originalQueue[i].track.id == id && originalQueue[i].track.duration != duration {
                let updated = originalQueue[i].track
                let newTrack = Track(
                    id: updated.id,
                    title: updated.title,
                    artist: updated.artist,
                    thumbnail: updated.thumbnail,
                    duration: duration,
                    viewCount: updated.viewCount,
                    likeCount: updated.likeCount,
                    rowId: updated.rowId
                )
                originalQueue[i] = QueueItem(id: originalQueue[i].id, track: newTrack)
            }
        }
    }

    func cycleRepeatMode() {
        let modes = ["off", "one", "all"]
        if let idx = modes.firstIndex(of: repeatMode) {
            repeatMode = modes[(idx + 1) % modes.count]
        }
    }
}
