import Foundation
import Combine

final class DownloadsStore: ObservableObject {
    @Published var downloadedTracks: [Track] = []
    @Published var downloadProgresses: [String: Double] = [:]
    
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
                self?.pendingTracks[track.id] = track
                self?.downloadProgresses[track.id] = 0.0
            }
        }
    }
    
    func startDownload(_ track: Track) {
        // This is called by the UI to initiate the process
        pendingTracks[track.id] = track
        downloadProgresses[track.id] = 0.0
        // The actual download is triggered in PlayerService
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
        saveToDefaults()
    }
    
    func isDownloaded(id: String) -> Bool {
        downloadedTracks.contains(where: { $0.id == id })
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
    }
    
    private func saveToDefaults() {
        if let data = try? JSONEncoder().encode(downloadedTracks) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}
