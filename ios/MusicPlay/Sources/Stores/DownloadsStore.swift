import Foundation
import Combine

final class DownloadsStore: ObservableObject {
    @Published var downloadedTracks: [Track] = []
    @Published var downloadProgresses: [String: Double] = [:]
    @Published var failedDownloads: Set<String> = []
    
    // We store tracks being downloaded so we can save them once finished
    private var pendingTracks: [String: Track] = [:]
    
    private let defaultsKey = "musicplay_downloaded_tracks"
    
    init() {
        loadFromDefaults()
        
        // Listen for progress updates
        NotificationCenter.default.addObserver(forName: NSNotification.Name("TrackDownloadProgress"), object: nil, queue: .main) { [weak self] note in
            guard let self = self else { return }
            if let id = note.object as? String, let progress = note.userInfo?["progress"] as? Double {
                self.downloadProgresses[id] = progress
                
                // If finished, save the track properly
                if progress >= 1.0 {
                    self.failedDownloads.remove(id)
                    if let track = self.pendingTracks[id] {
                        self.saveTrackInternal(track)
                        self.pendingTracks.removeValue(forKey: id)
                    }
                    // Delay removal from progresses to let UI show 100% for a moment
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.downloadProgresses.removeValue(forKey: id)
                    }
                }
            }
        }
        
        // Listen for download started
        NotificationCenter.default.addObserver(forName: NSNotification.Name("TrackDownloadStarted"), object: nil, queue: .main) { [weak self] note in
            if let track = note.object as? Track {
                self?.startDownload(track)
            }
        }

        // Listen for download failed
        NotificationCenter.default.addObserver(forName: NSNotification.Name("TrackDownloadFailed"), object: nil, queue: .main) { [weak self] note in
            if let id = note.object as? String {
                self?.handleDownloadError(id: id)
            }
        }
    }
    
    func startDownload(_ track: Track) {
        clearError(id: track.id)
        pendingTracks[track.id] = track
        downloadProgresses[track.id] = 0.0
        
        // Add to the list immediately
        saveTrackInternal(track)
    }

    func clearError(id: String) {
        if failedDownloads.contains(id) {
            failedDownloads.remove(id)
            saveToDefaults()
        }
    }

    /// Register a track that MIGHT be cached (e.g. while streaming)
    func registerPotentialTrack(_ track: Track) {
        clearError(id: track.id)
        if pendingTracks[track.id] == nil && !downloadedTracks.contains(where: { $0.id == track.id }) {
            pendingTracks[track.id] = track
        }
    }

    func handleDownloadError(id: String) {
        failedDownloads.insert(id)
        downloadProgresses.removeValue(forKey: id)
        // Keep it in pendingTracks so we can easily retry? 
        // Actually, let's keep it in downloadedTracks so the user sees it failed.
        saveToDefaults()
    }
    
    func saveTrackInternal(_ track: Track) {
        if !downloadedTracks.contains(where: { $0.id == track.id }) {
            downloadedTracks.append(track)
            saveToDefaults()
        }
    }
    
    func removeTrack(_ id: String) {
        downloadedTracks.removeAll { $0.id == id }
        downloadProgresses.removeValue(forKey: id)
        pendingTracks.removeValue(forKey: id)
        failedDownloads.remove(id)
        saveToDefaults()
        
        // Systemic fix: Actually remove the file from disk cache
        AudioCacheService.shared.removeTrack(id: id)
    }

    func clearAll() {
        downloadedTracks = []
        downloadProgresses = [:]
        pendingTracks = [:]
        failedDownloads = []
        saveToDefaults()
    }
    
    /// Scans cache and adds tracks that exist on disk but aren't in the list
    func syncItemsWithCache(allknownTracks: [Track]) {
        // This is a bit tricky since we only have IDs in cache filenames.
        // We'll try to find metadata for them if they aren't already in downloadedTracks.
        for track in allknownTracks {
            if !downloadedTracks.contains(where: { $0.id == track.id }) {
                if AudioCacheService.shared.localURL(for: track.id) != nil {
                    saveTrackInternal(track)
                }
            }
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
        saveToDefaults()
    }
    
    private func loadFromDefaults() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey) {
            if let decoded = try? JSONDecoder().decode([Track].self, from: data) {
                downloadedTracks = decoded
            }
        }
        if let failed = UserDefaults.standard.stringArray(forKey: "musicplay_failed_downloads") {
            failedDownloads = Set(failed)
        }
    }
    
    private func saveToDefaults() {
        if let data = try? JSONEncoder().encode(downloadedTracks) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
        UserDefaults.standard.set(Array(failedDownloads), forKey: "musicplay_failed_downloads")
    }
}
