import SwiftUI
import Combine

final class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = true
    @Published var baseURL: String
    @Published var audioQuality: String

    let tokenStore = TokenStore()
    let apiClient: APIClient
    let playerStore = PlayerStore()
    let playlistsStore = PlaylistsStore()
    let favoritesStore = FavoritesStore()
    let searchStore = SearchStore()
    let downloadsStore = DownloadsStore()
    let playerService = PlayerService()
    let playerSyncService = PlayerSyncService()

    private var cancellables = Set<AnyCancellable>()

    init() {
        let localURL = "http://192.168.1.235:3001"
        let savedQuality = UserDefaults.standard.string(forKey: "musicplay_audio_quality") ?? "high"
        
        self.baseURL = localURL
        self.audioQuality = savedQuality
        self.apiClient = APIClient(baseURL: localURL, tokenStore: tokenStore)
        self.apiClient.audioQuality = savedQuality
        self.isAuthenticated = tokenStore.accessToken != nil
        self.isLoading = false
        wireStores()
        bindNestedStores()
        
        UserDefaults.standard.set(localURL, forKey: "musicplay_base_url")
    }

    func updateBaseURL(_ url: String) {
        guard let normalized = normalizeBaseURL(url) else { return }
        baseURL = normalized.absoluteString
        UserDefaults.standard.set(baseURL, forKey: "musicplay_base_url")
        apiClient.updateBaseURL(baseURL)
    }

    func updateAudioQuality(_ quality: String) {
        audioQuality = quality
        UserDefaults.standard.set(quality, forKey: "musicplay_audio_quality")
        apiClient.audioQuality = quality
    }

    func wireStores() {
        playlistsStore.configure(api: apiClient)
        favoritesStore.configure(api: apiClient)
        searchStore.configure(api: apiClient)
        playerStore.configure(api: apiClient)
        playerService.configure(api: apiClient, playerStore: playerStore)
        playerSyncService.configure(api: apiClient, playerStore: playerStore, playerService: playerService)
    }

    /// Forward objectWillChange from all nested ObservableObjects to AppState.
    /// Without this, SwiftUI views observing AppState won't re-render when
    /// nested stores change their @Published properties.
    private func bindNestedStores() {
        playerStore.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        playerService.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        playlistsStore.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        favoritesStore.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        searchStore.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        downloadsStore.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
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
        .preferredColorScheme(.dark)
        .tint(.white)
    }
}
