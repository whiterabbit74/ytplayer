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

