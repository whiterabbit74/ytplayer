import SwiftUI

final class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = true
    @Published var baseURL: String

    let tokenStore = TokenStore()
    let apiClient: APIClient
    let playerStore = PlayerStore()
    let playlistsStore = PlaylistsStore()
    let favoritesStore = FavoritesStore()
    let searchStore = SearchStore()
    let playerService = PlayerService()

    init() {
        let localURL = "http://127.0.0.1:3001"
        
        self.baseURL = localURL
        self.apiClient = APIClient(baseURL: localURL, tokenStore: tokenStore)
        self.isAuthenticated = tokenStore.accessToken != nil
        self.isLoading = false
        wireStores()
        
        UserDefaults.standard.set(localURL, forKey: "musicplay_base_url")
    }

    func updateBaseURL(_ url: String) {
        guard let normalized = normalizeBaseURL(url) else { return }
        baseURL = normalized.absoluteString
        UserDefaults.standard.set(baseURL, forKey: "musicplay_base_url")
        apiClient.updateBaseURL(baseURL)
    }

    func wireStores() {
        playlistsStore.configure(api: apiClient)
        favoritesStore.configure(api: apiClient)
        searchStore.configure(api: apiClient)
        playerStore.configure(api: apiClient)
        playerService.configure(api: apiClient, playerStore: playerStore)
    }

    func refreshAuthState() {
        isAuthenticated = tokenStore.accessToken != nil
    }

    private func normalizeBaseURL(_ raw: String) -> URL? {
        AppState.normalizeBaseURLStatic(raw)
    }

    private static func normalizeBaseURLStatic(_ raw: String?) -> URL? {
        guard let raw else { return nil }
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        let lower = cleaned.lowercased()
        let withScheme: String
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
            withScheme = cleaned
        } else {
            withScheme = "http://\(cleaned)"
        }
        guard let url = URL(string: withScheme), url.host != nil else { return nil }
        return url
    }
}

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if appState.isLoading {
                ProgressView()
            } else if appState.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
    }
}
