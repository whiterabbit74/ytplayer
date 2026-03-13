import SwiftUI
import Combine

final class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = true
    @Published var isServerAvailable = true
    @Published var baseURL: String
    @Published var audioQuality: String
    @Published var serverType: ServerType
    @Published var coverStyle: CoverStyle
    @Published var crossfadeEnabled: Bool
    @Published var crossfadeDuration: Double
    @Published var dynamicBackgroundEnabled: Bool

    enum CoverStyle: String, CaseIterable, Identifiable {
        case standard = "Standard"
        case square = "Square"
        case vinyl = "Vinyl"
        
        var id: String { self.rawValue }
    }

    var squareCovers: Bool {
        coverStyle != .standard
    }

    enum ServerType: String, CaseIterable, Identifiable {
        case local = "Local"
        case main = "Main"
        case custom = "Custom"
        
        var id: String { self.rawValue }
    }
    
    static let localURL = "http://qs-MacBook-Air.local:3001"
    static let mainURL = "https://tradingibs.site/music"

    let tokenStore = TokenStore()
    let apiClient: APIClient
    let playerStore = PlayerStore()
    let playlistsStore = PlaylistsStore()
    let favoritesStore = FavoritesStore()
    let searchStore = SearchStore()
    let downloadsStore = DownloadsStore()
    @Published var historyStore = HistoryStore()
    @Published var selectedTab: Int = 0
    let playerService = PlayerService()
    let playerSyncService = PlayerSyncService()

    private var cancellables = Set<AnyCancellable>()

    init() {
        let savedURL = UserDefaults.standard.string(forKey: "musicplay_base_url") ?? AppState.localURL
        let savedQuality = UserDefaults.standard.string(forKey: "musicplay_audio_quality") ?? "high"
        let savedServerType = ServerType(rawValue: UserDefaults.standard.string(forKey: "musicplay_server_type") ?? "") ?? .local
        let savedCoverStyle = CoverStyle(rawValue: UserDefaults.standard.string(forKey: "musicplay_cover_style") ?? "") ?? .standard
        let savedCrossfadeEnabled = UserDefaults.standard.bool(forKey: "musicplay_crossfade_enabled")
        let savedCrossfadeDuration = UserDefaults.standard.double(forKey: "musicplay_crossfade_duration")
        let savedDynamicBackground = UserDefaults.standard.bool(forKey: "musicplay_dynamic_background")
        
        self.baseURL = savedURL
        self.audioQuality = savedQuality
        self.serverType = savedServerType
        self.coverStyle = savedCoverStyle
        self.crossfadeEnabled = savedCrossfadeEnabled
        self.crossfadeDuration = savedCrossfadeDuration == 0 ? 6.0 : savedCrossfadeDuration
        self.dynamicBackgroundEnabled = savedDynamicBackground
        
        self.apiClient = APIClient(baseURL: savedURL, tokenStore: tokenStore)
        self.apiClient.audioQuality = savedQuality
        self.isAuthenticated = tokenStore.accessToken != nil
        self.isLoading = false
        
        setupAPIConnectionTracking()
        wireStores()
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
        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
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

    func setServerType(_ type: ServerType) {
        serverType = type
        UserDefaults.standard.set(type.rawValue, forKey: "musicplay_server_type")
        
        let newURL: String
        switch type {
        case .local: newURL = AppState.localURL
        case .main: newURL = AppState.mainURL
        case .custom: return // Do nothing, let user update via updateBaseURL
        }
        updateBaseURL(newURL)
    }

    func updateBaseURL(_ url: String) {
        guard let normalized = normalizeBaseURL(url) else { return }
        baseURL = normalized.absoluteString
        UserDefaults.standard.set(baseURL, forKey: "musicplay_base_url")
        apiClient.updateBaseURL(baseURL)
        
        // If the URL matches a predefined one, update serverType
        if baseURL.trimmingCharacters(in: .init(charactersIn: "/")) == AppState.localURL.trimmingCharacters(in: .init(charactersIn: "/")) {
            serverType = .local
        } else if baseURL.trimmingCharacters(in: .init(charactersIn: "/")) == AppState.mainURL.trimmingCharacters(in: .init(charactersIn: "/")) {
            serverType = .main
        } else {
            serverType = .custom
        }
        UserDefaults.standard.set(serverType.rawValue, forKey: "musicplay_server_type")
    }

    func updateAudioQuality(_ quality: String) {
        audioQuality = quality
        UserDefaults.standard.set(quality, forKey: "musicplay_audio_quality")
        apiClient.audioQuality = quality
    }

    func updateCoverStyle(_ style: CoverStyle) {
        coverStyle = style
        UserDefaults.standard.set(style.rawValue, forKey: "musicplay_cover_style")
    }

    func updateCrossfade(enabled: Bool, duration: Double) {
        crossfadeEnabled = enabled
        crossfadeDuration = duration
        UserDefaults.standard.set(enabled, forKey: "musicplay_crossfade_enabled")
        UserDefaults.standard.set(duration, forKey: "musicplay_crossfade_duration")
    }

    func updateDynamicBackground(enabled: Bool) {
        dynamicBackgroundEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "musicplay_dynamic_background")
    }

    func wireStores() {
        playlistsStore.configure(api: apiClient)
        favoritesStore.configure(api: apiClient)
        searchStore.configure(api: apiClient)
        playerStore.configure(api: apiClient)
        playerService.configure(api: apiClient, playerStore: playerStore, historyStore: historyStore, appState: self)
        playerSyncService.configure(api: apiClient, playerStore: playerStore, playerService: playerService)
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
                VStack(alignment: .leading) {
                    HStack(spacing: 8) {
                        Image(systemName: "wifi.slash")
                            .font(.caption)
                        Text("No Server Connection")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Button("Retry") {
                            Task { await appState.checkConnection() }
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .cornerRadius(4)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.red.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(20) // More pill-like
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    
                    Spacer()
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(.white)
    }
}
