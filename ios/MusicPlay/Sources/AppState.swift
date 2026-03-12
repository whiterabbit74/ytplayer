import SwiftUI
import Combine

final class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = true
    @Published var isServerAvailable = true
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
        let localURL = "http://qs-MacBook-Air.local:3001"
        let savedQuality = UserDefaults.standard.string(forKey: "musicplay_audio_quality") ?? "high"
        
        self.baseURL = localURL
        self.audioQuality = savedQuality
        self.apiClient = APIClient(baseURL: localURL, tokenStore: tokenStore)
        self.apiClient.audioQuality = savedQuality
        self.isAuthenticated = tokenStore.accessToken != nil
        self.isLoading = false
        
        setupAPIConnectionTracking()
        wireStores()
        bindNestedStores()
        startHealthCheck()
    }

    private func setupAPIConnectionTracking() {
        apiClient.onConnectionError = { [weak self] _ in
            DispatchQueue.main.async {
                if self?.isServerAvailable == true {
                    print("📡 Server became unreachable")
                    self?.isServerAvailable = false
                }
            }
        }
        apiClient.onConnectionSuccess = { [weak self] in
            DispatchQueue.main.async {
                if self?.isServerAvailable == false {
                    print("📡 Server back online")
                    self?.isServerAvailable = true
                }
            }
        }
    }

    private func startHealthCheck() {
        // Periodic check if server is back
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self = self, !self.isServerAvailable else { return }
            Task { await self.checkConnection() }
        }
    }

    func checkConnection() async {
        do {
            // Simple ping to /api/v1/auth/refresh (or any lightweight endpoint)
            _ = try await apiClient.fetchPlaylists() 
            DispatchQueue.main.async { self.isServerAvailable = true }
        } catch {
            // If it's a 401 or something, the server IS up. 
            // Only actual URLErrors count as "server down" in this context.
            if let nsError = error as NSError?, nsError.domain != NSURLErrorDomain {
                DispatchQueue.main.async { self.isServerAvailable = true }
            }
        }
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
        ZStack {
            Group {
                if appState.isLoading {
                    ProgressView()
                } else if appState.isAuthenticated {
                    MainTabView()
                } else {
                    LoginView()
                }
            }

            
            if !appState.isServerAvailable {
                VStack {
                    HStack(spacing: 8) {
                        Image(systemName: "wifi.slash")
                            .font(.caption)
                        Text("No Server Connection")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Button("Retry") {
                            Task { await appState.checkConnection() }
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .cornerRadius(4)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.red.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.horizontal, 10)
                    .padding(.top, 4) // Safe area will push it down
                    
                    Spacer()
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(.white)
    }
}
