import Foundation

final class PlaylistsStore: ObservableObject {
    @Published var playlists: [Playlist] = []
    @Published var activePlaylistId: Int?
    @Published var activeTracks: [Track] = []
    @Published var isLoading = false

    private var api: APIClient?

    func configure(api: APIClient) {
        self.api = api
    }

    @MainActor
    func loadPlaylists() async {
        guard let api else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            playlists = try await api.fetchPlaylists()
        } catch {
            print("loadPlaylists error", error)
        }
    }

    @MainActor
    func createPlaylist(name: String) async {
        guard let api else { return }
        do {
            try await api.createPlaylist(name: name)
            await loadPlaylists()
        } catch {
            print("createPlaylist error", error)
        }
    }

    @MainActor
    func deletePlaylist(id: Int) async {
        guard let api else { return }
        do {
            try await api.deletePlaylist(id: id)
            if activePlaylistId == id {
                activePlaylistId = nil
                activeTracks = []
            }
            await loadPlaylists()
        } catch {
            print("deletePlaylist error", error)
        }
    }

    @MainActor
    func renamePlaylist(id: Int, name: String) async {
        guard let api else { return }
        do {
            try await api.renamePlaylist(id: id, name: name)
            await loadPlaylists()
        } catch {
            print("renamePlaylist error", error)
        }
    }

    @MainActor
    func selectPlaylist(id: Int) async {
        guard let api else { return }
        isLoading = true
        defer { isLoading = false }
        if activePlaylistId != id {
            activeTracks = []
        }
        activePlaylistId = id
        do {
            activeTracks = try await api.fetchPlaylistTracks(id: id)
        } catch {
            print("selectPlaylist error", error)
        }
    }

    @MainActor
    func addTrack(playlistId: Int, track: Track) async {
        guard let api else { return }
        do {
            try await api.addTrackToPlaylist(id: playlistId, track: track)
            if activePlaylistId == playlistId {
                await selectPlaylist(id: playlistId)
            }
        } catch {
            print("addTrack error", error)
        }
    }

    @MainActor
    func removeTrack(playlistId: Int, trackId: Int) async {
        guard let api else { return }
        do {
            try await api.removeTrackFromPlaylist(playlistId: playlistId, trackId: trackId)
            if activePlaylistId == playlistId {
                await selectPlaylist(id: playlistId)
            }
        } catch {
            print("removeTrack error", error)
        }
    }

    @MainActor
    func reorderTracks(playlistId: Int, trackIds: [Int]) async {
        guard let api else { return }
        do {
            try await api.reorderPlaylistTracks(playlistId: playlistId, trackIds: trackIds)
            if activePlaylistId == playlistId {
                await selectPlaylist(id: playlistId)
            }
        } catch {
            print("reorder error", error)
        }
    }
}

final class DownloadsStore: ObservableObject {
    @Published var downloadedTracks: [Track] = []
    @Published var downloadProgresses: [String: Double] = [:]
    
    private let defaultsKey = "musicplay_downloaded_tracks"
    
    init() {
        loadFromDefaults()
        NotificationCenter.default.addObserver(forName: NSNotification.Name("TrackDownloadProgress"), object: nil, queue: .main) { [weak self] note in
            if let id = note.object as? String, let progress = note.userInfo?["progress"] as? Double {
                self?.downloadProgresses[id] = progress
                if progress >= 1.0 {
                    self?.downloadProgresses.removeValue(forKey: id)
                }
            }
        }
    }
    
    func saveTrack(_ track: Track) {
        if !downloadedTracks.contains(where: { $0.id == track.id }) {
            downloadedTracks.append(track)
            saveToDefaults()
        }
    }
    
    func removeTrack(_ id: String) {
        downloadedTracks.removeAll { $0.id == id }
        downloadProgresses.removeValue(forKey: id)
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
