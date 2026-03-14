import Foundation
import Combine

@MainActor
final class DownloadsStore: ObservableObject {
    @Published var downloadedTracks: [Track] = []
    @Published var pendingTracks: [String: Track] = [:]
    @Published var downloadProgresses: [String: Double] = [:]
    @Published var failedDownloads: Set<String> = []
    
    private var cancellables = Set<AnyCancellable>()
    private var observerTokens: [Any] = []
    private let ioQueue = DispatchQueue(label: "com.musicplay.downloads.io", qos: .background)
    
    private var storageURL: URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("Metadata")
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("downloads.json")
    }
    
    init() {
        loadFromDisk()
        
        // Listen for progress updates
        let pToken = NotificationCenter.default.addObserver(forName: NSNotification.Name("TrackDownloadProgress"), object: nil, queue: .main) { [weak self] note in
            guard let self = self else { return }
            if let id = note.object as? String, let progress = note.userInfo?["progress"] as? Double {
                self.downloadProgresses[id] = progress
                
                // If finished, save the track properly
                if progress >= 1.0 {
                    self.failedDownloads.remove(id)
                    // Delay removal from progresses to let UI show 100% for a moment
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.downloadProgresses.removeValue(forKey: id)
                    }
                }
            }
        }
        observerTokens.append(pToken)
        
        // Listen for download finished (verified on disk)
        let fToken = NotificationCenter.default.addObserver(forName: NSNotification.Name("TrackDownloadFinished"), object: nil, queue: .main) { [weak self] note in
            guard let self = self else { return }
            if let id = note.object as? String {
                self.failedDownloads.remove(id)
                if let track = self.pendingTracks[id] {
                    self.saveTrackInternal(track)
                    self.pendingTracks.removeValue(forKey: id)
                }
                self.saveToDisk()
            }
        }
        observerTokens.append(fToken)
        
        // Listen for download started
        let sToken = NotificationCenter.default.addObserver(forName: NSNotification.Name("TrackDownloadStarted"), object: nil, queue: .main) { [weak self] note in
            if let track = note.object as? Track {
                self?.startDownload(track)
            }
        }
        observerTokens.append(sToken)

        // Listen for download failed
        let errToken = NotificationCenter.default.addObserver(forName: NSNotification.Name("TrackDownloadFailed"), object: nil, queue: .main) { [weak self] note in
            if let id = note.object as? String {
                self?.handleDownloadError(id: id)
            }
        }
        observerTokens.append(errToken)
        
        // Listen for metadata updates discovered during streaming/downloading
        let uToken = NotificationCenter.default.addObserver(forName: NSNotification.Name("TrackDurationUpdated"), object: nil, queue: .main) { [weak self] note in
            if let id = note.object as? String, let duration = note.userInfo?["duration"] as? Int {
                self?.updateTrackDuration(id: id, duration: duration)
            }
        }
        observerTokens.append(uToken)
    }
    
    func startDownload(_ track: Track) {
        clearError(id: track.id)
        pendingTracks[track.id] = track
        downloadProgresses[track.id] = 0.0
        
        saveToDisk()
    }

    func clearError(id: String) {
        if failedDownloads.contains(id) {
            failedDownloads.remove(id)
            saveToDisk()
        }
    }

    /// Register a track that MIGHT be cached (e.g. while streaming)
    func registerPotentialTrack(_ track: Track) {
        clearError(id: track.id)
        if pendingTracks[track.id] == nil && !downloadedTracks.contains(where: { $0.id == track.id }) {
            pendingTracks[track.id] = track
            saveToDisk()
        }
    }

    func handleDownloadError(id: String) {
        failedDownloads.insert(id)
        downloadProgresses.removeValue(forKey: id)
        saveToDisk()
    }
    
    func saveTrackInternal(_ track: Track) {
        if !downloadedTracks.contains(where: { $0.id == track.id }) {
            downloadedTracks.append(track)
            saveToDisk()
        }
    }
    
    func removeTrack(_ id: String) {
        downloadedTracks.removeAll { $0.id == id }
        downloadProgresses.removeValue(forKey: id)
        pendingTracks.removeValue(forKey: id)
        failedDownloads.remove(id)
        saveToDisk()
        
        // Actually remove the file from disk cache
        AudioCacheService.shared.removeTrack(id: id)
    }

    func updateTrackDuration(id: String, duration: Int) {
        var changed = false
        // Update in downloadedTracks
        for i in 0..<downloadedTracks.count {
            if downloadedTracks[i].id == id && downloadedTracks[i].duration != duration {
                let updated = downloadedTracks[i]
                downloadedTracks[i] = Track(
                    id: updated.id,
                    title: updated.title,
                    artist: updated.artist,
                    thumbnail: updated.thumbnail,
                    duration: duration,
                    viewCount: updated.viewCount,
                    likeCount: updated.likeCount,
                    rowId: updated.rowId
                )
                changed = true
            }
        }
        
        // Update in pendingTracks
        if let updated = pendingTracks[id], updated.duration != duration {
            pendingTracks[id] = Track(
                id: updated.id,
                title: updated.title,
                artist: updated.artist,
                thumbnail: updated.thumbnail,
                duration: duration,
                viewCount: updated.viewCount,
                likeCount: updated.likeCount,
                rowId: updated.rowId
            )
            changed = true
        }
        
        if changed {
            saveToDisk()
        }
    }

    func clearAll() {
        downloadedTracks = []
        downloadProgresses = [:]
        pendingTracks = [:]
        failedDownloads = []
        saveToDisk()
    }
    
    /// Scans cache and adds tracks that exist on disk but aren't in the list
    func syncItemsWithCache(allknownTracks: [Track]) {
        var changed = false
        for track in allknownTracks {
            if !downloadedTracks.contains(where: { $0.id == track.id }) {
                if AudioCacheService.shared.localURL(for: track.id) != nil {
                    downloadedTracks.append(track)
                    changed = true
                }
            }
        }
        if changed {
            saveToDisk()
        }
    }
    
    func isDownloaded(id: String) -> Bool {
        // If it's already in the cache directory, it's effectively downloaded
        if AudioCacheService.shared.localURL(for: id) != nil {
            return true
        }
        // Fallback to tracking logic for pending/failed states
        return downloadedTracks.contains(where: { $0.id == id }) && !failedDownloads.contains(id) && downloadProgresses[id] == nil
    }

    func canRetry(id: String) -> Bool {
        failedDownloads.contains(id)
    }
    
    func moveTracks(from source: IndexSet, to destination: Int) {
        downloadedTracks.move(fromOffsets: source, toOffset: destination)
        saveToDisk()
    }

    private struct DownloadMetadata: Codable {
        let tracks: [Track]
        let failedIds: [String]
        let pending: [String: Track]?
    }
    
    private func loadFromDisk() {
        // Attempt to load from JSON first
        if let data = try? Data(contentsOf: storageURL),
           let metadata = try? JSONDecoder().decode(DownloadMetadata.self, from: data) {
            self.downloadedTracks = metadata.tracks
            self.failedDownloads = Set(metadata.failedIds)
            self.pendingTracks = metadata.pending ?? [:]
            print("💾 Loaded \(downloadedTracks.count) downloads and \(pendingTracks.count) pending from disk")
            syncPendingOnStartup()
            return
        }
        
        // Migration from UserDefaults
        print("💾 Attempting migration from UserDefaults...")
        if let data = UserDefaults.standard.data(forKey: "musicplay_downloaded_tracks") {
            if let decoded = try? JSONDecoder().decode([Track].self, from: data) {
                downloadedTracks = decoded
            }
        }
        if let failed = UserDefaults.standard.stringArray(forKey: "musicplay_failed_downloads") {
            failedDownloads = Set(failed)
        }
        
        if !downloadedTracks.isEmpty || !failedDownloads.isEmpty {
            saveToDisk()
            // Clean up old defaults
            UserDefaults.standard.removeObject(forKey: "musicplay_downloaded_tracks")
            UserDefaults.standard.removeObject(forKey: "musicplay_failed_downloads")
            print("✅ Successfully migrated downloads metadata to disk")
        }
    }
    
    private func syncPendingOnStartup() {
        var toMove: [Track] = []
        for (id, track) in pendingTracks {
            if AudioCacheService.shared.localURL(for: id) != nil {
                toMove.append(track)
            }
        }
        
        if !toMove.isEmpty {
            print("🔄 Syncing \(toMove.count) tracks that were found on disk but were pending")
            for track in toMove {
                saveTrackInternal(track)
                pendingTracks.removeValue(forKey: track.id)
            }
            saveToDisk()
        }
    }
    
    private func saveToDisk() {
        let metadata = DownloadMetadata(
            tracks: downloadedTracks,
            failedIds: Array(failedDownloads),
            pending: pendingTracks
        )
        let url = storageURL
        ioQueue.async {
            if let data = try? JSONEncoder().encode(metadata) {
                try? data.write(to: url)
            }
        }
    }

    deinit {
        for token in observerTokens {
            NotificationCenter.default.removeObserver(token)
        }
    }
}
