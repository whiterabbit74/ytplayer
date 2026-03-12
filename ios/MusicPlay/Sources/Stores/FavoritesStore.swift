import Foundation

final class FavoritesStore: ObservableObject {
    @Published var favorites: [Track] = []
    @Published var favoriteIds: Set<String> = []
    @Published var isLoading = false

    private var api: APIClient?

    func configure(api: APIClient) {
        self.api = api
    }

    @MainActor
    func loadFavorites() async {
        guard let api else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            favorites = try await api.fetchFavorites()
            favoriteIds = Set(favorites.map { $0.id })
        } catch {
            print("loadFavorites error", error)
        }
    }

    @MainActor
    func toggleFavorite(_ track: Track) async {
        guard let api else { return }
        let isFav = favoriteIds.contains(track.id)
        var newFavs = favorites
        if isFav {
            favoriteIds.remove(track.id)
            newFavs.removeAll { $0.id == track.id }
            favorites = newFavs
        } else {
            favoriteIds.insert(track.id)
            favorites = [track] + favorites
        }
        do {
            if isFav {
                try await api.removeFavorite(videoId: track.id)
            } else {
                try await api.addFavorite(track: track)
            }
        } catch {
            print("toggleFavorite error", error)
            await loadFavorites()
        }
    }

    func isFavorite(_ videoId: String) -> Bool {
        favoriteIds.contains(videoId)
    }
}
