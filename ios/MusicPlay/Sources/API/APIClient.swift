import Foundation

final class APIClient {
    private var baseURL: URL
    private let tokenStore: TokenStore
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private var _isRefreshing = false
    private let refreshLock = NSLock()
    private var isRefreshing: Bool {
        refreshLock.lock(); defer { refreshLock.unlock() }
        return _isRefreshing
    }
    
    var audioQuality: String = "high"
    var onConnectionError: ((Error) -> Void)?
    var onConnectionSuccess: (() -> Void)?
    
    static let sessionEndedNotification = Notification.Name("APIClientSessionEnded")

    init(baseURL: String, tokenStore: TokenStore) {
        self.baseURL = URL(string: baseURL) ?? URL(string: "http://qs-MacBook-Air.local:3001")!
        self.tokenStore = tokenStore
        self.session = URLSession(configuration: .default)
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    func updateBaseURL(_ baseURL: String) {
        self.baseURL = URL(string: baseURL) ?? self.baseURL
    }

    var accessToken: String? {
        tokenStore.accessToken
    }

    private func makeURL(_ path: String, queryItems: [URLQueryItem] = []) -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return baseURL
        }
        let basePath = components.path
        
        let cleanedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let finalPath = basePath.hasSuffix("/") ? "\(basePath)\(cleanedPath)" : "\(basePath)/\(cleanedPath)"
        
        components.path = finalPath
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        return components.url ?? baseURL
    }

    private func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        query: [URLQueryItem] = [],
        body: Encodable? = nil,
        auth: Bool = true
    ) async throws -> T {
        let url = makeURL(path, queryItems: query)
        print("🚀 [API] Requesting: \(method) \(url.absoluteString)")
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body = body {
            req.httpBody = try encoder.encode(AnyEncodable(body))
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if auth, let token = tokenStore.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, response) = try await session.data(for: req)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [API] Error: Not an HTTP response")
                throw URLError(.badServerResponse)
            }
            
            print("✅ [API] Response: \(httpResponse.statusCode) for \(path)")
            
            if httpResponse.statusCode == 401 && !isRefreshing && auth {
                print("🔄 [API] 401 Unauthorized, attempting token refresh...")
                let refreshed = try await refreshToken()
                if refreshed {
                    return try await request(path, method: method, query: query, body: body, auth: auth)
                } else {
                    // refreshToken() already handles clearing tokens and posting notification if it's an explicit auth failure.
                    // If it returns false, it means refresh failed and we should propagate the authentication failure.
                    print("🚫 [API] Refresh failed, session likely cleared by refreshToken() or not refreshable.")
                    throw URLError(.userAuthenticationRequired)
                }
            }
            
            if !(200...299).contains(httpResponse.statusCode) {
                print("⚠️ [API] Server Error Response: \(httpResponse.statusCode)")
                if let apiErr = try? decoder.decode(APIErrorResponse.self, from: data) {
                    throw apiErr
                }
                throw URLError(.badServerResponse)
            }
            
            onConnectionSuccess?()
            return try decoder.decode(T.self, from: data)
        } catch {
            print("❌ [API] Request failed: \(req.url?.absoluteString ?? "unknown") - Error: \(error)")
            handleNetworkError(error)
            throw error
        }
    }

    private func handleNetworkError(_ error: Error) {
        let nsError = error as NSError
        // Network-level errors (connection refused, timeout, dns, etc)
        if nsError.domain == NSURLErrorDomain {
            onConnectionError?(error)
        }
    }

    private func requestVoid(
        _ path: String,
        method: String = "GET",
        query: [URLQueryItem] = [],
        body: Encodable? = nil,
        auth: Bool = true
    ) async throws {
        let url = makeURL(path, queryItems: query)
        print("🚀 [API] Void Request: \(method) \(url.absoluteString)")
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body = body {
            req.httpBody = try encoder.encode(AnyEncodable(body))
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if auth, let token = tokenStore.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await session.data(for: req)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [API] Error: Not an HTTP response")
                return
            }
            
            print("✅ [API] Void Response: \(httpResponse.statusCode) for \(path)")
            onConnectionSuccess?()
            
            if httpResponse.statusCode == 401 && !isRefreshing && auth {
                let refreshed = try await refreshToken()
                if refreshed {
                    return try await requestVoid(path, method: method, query: query, body: body, auth: auth)
                } else {
                    // Similar logic: only clear if we are sure it's an auth issue
                    // (Handled inside refreshToken normally, but as safety check here)
                    throw URLError(.userAuthenticationRequired)
                }
            }
            
            if !(200...299).contains(httpResponse.statusCode) {
                if let apiErr = try? decoder.decode(APIErrorResponse.self, from: data) {
                    throw apiErr
                }
                throw URLError(.badServerResponse)
            }
        } catch {
            print("❌ [API] Void Request failed: \(req.url?.absoluteString ?? "unknown") - Error: \(error)")
            throw error
        }
    }


    // MARK: Auth

    func login(email: String, password: String) async throws -> UserDTO {
        let resp: LoginResponse = try await request(
            "/api/v1/auth/login",
            method: "POST",
            body: ["email": email, "password": password],
            auth: false
        )
        tokenStore.accessToken = resp.accessToken
        tokenStore.refreshToken = resp.refreshToken
        return resp.user
    }

    func refreshToken() async throws -> Bool {
        guard let refresh = tokenStore.refreshToken else { return false }
        refreshLock.lock()
        guard !_isRefreshing else {
            refreshLock.unlock()
            return false
        }
        _isRefreshing = true
        refreshLock.unlock()
        
        defer {
            refreshLock.lock()
            _isRefreshing = false
            refreshLock.unlock()
        }
        do {
            let resp: RefreshResponse = try await request(
                "/api/v1/auth/refresh",
                method: "POST",
                body: ["refreshToken": refresh],
                auth: false
            )
            tokenStore.accessToken = resp.accessToken
            tokenStore.refreshToken = resp.refreshToken
            return true
        } catch {
            // Only clear tokens if the server explicitly rejects the refresh (401/400)
            // If it's a network error (URLError), we KEEP the tokens so user stays "logged in" offline.
            if let apiErr = error as? APIErrorResponse {
                print("🚫 [API] Refresh rejected by server: \(apiErr.error.message)")
                tokenStore.clear()
                NotificationCenter.default.post(name: APIClient.sessionEndedNotification, object: nil)
            } else if let urlErr = error as? URLError {
                print("📡 [API] Refresh failed due to network: \(urlErr.localizedDescription)")
                // Do NOT clear tokens
            } else {
                // For other errors, we might want to be safe or keep them. 
                // Let's keep them if it's not a clear auth failure.
                print("⚠️ [API] Refresh failed with unknown error: \(error)")
            }
            return false
        }
    }

    func logout() async throws {
        defer { tokenStore.clear() }
        guard let refresh = tokenStore.refreshToken else { return }
        try? await requestVoid(
            "/api/v1/auth/logout",
            method: "POST",
            body: ["refreshToken": refresh],
            auth: false
        )
    }

    // MARK: Search

    func search(query: String, pageToken: String? = nil) async throws -> SearchResult {
        var items = [URLQueryItem(name: "q", value: query)]
        if let pageToken {
            items.append(URLQueryItem(name: "pageToken", value: pageToken))
        }
        return try await request("/api/v1/search", query: items)
    }

    func suggestions(query: String) async throws -> [String] {
        let items = [URLQueryItem(name: "q", value: query)]
        return try await request("/api/v1/search/suggest", query: items)
    }

    // MARK: Playlists

    func fetchPlaylists() async throws -> [Playlist] {
        return try await request("/api/v1/playlists")
    }

    func createPlaylist(name: String) async throws {
        _ = try await request("/api/v1/playlists", method: "POST", body: ["name": name]) as Playlist
    }

    func deletePlaylist(id: Int) async throws {
        try await requestVoid("/api/v1/playlists/\(id)", method: "DELETE")
    }

    func renamePlaylist(id: Int, name: String) async throws {
        try await requestVoid("/api/v1/playlists/\(id)", method: "PUT", body: ["name": name])
    }

    func fetchPlaylistTracks(id: Int) async throws -> [Track] {
        return try await request("/api/v1/playlists/\(id)/tracks")
    }

    func addTrackToPlaylist(id: Int, track: Track) async throws {
        let body = AddTrackRequest(
            video_id: track.id,
            title: track.title,
            artist: track.artist,
            thumbnail: track.thumbnail,
            duration: track.duration,
            viewCount: track.viewCount ?? 0,
            likeCount: track.likeCount ?? 0
        )
        try await requestVoid("/api/v1/playlists/\(id)/tracks", method: "POST", body: body)
    }

    func removeTrackFromPlaylist(playlistId: Int, trackId: Int) async throws {
        try await requestVoid("/api/v1/playlists/\(playlistId)/tracks/\(trackId)", method: "DELETE")
    }

    func reorderPlaylistTracks(playlistId: Int, trackIds: [Int]) async throws {
        try await requestVoid(
            "/api/v1/playlists/\(playlistId)/tracks/reorder",
            method: "PUT",
            body: ["trackIds": trackIds]
        )
    }

    // MARK: Favorites

    func fetchFavorites() async throws -> [Track] {
        return try await request("/api/v1/favorites")
    }

    func fetchFavoriteIds() async throws -> [String] {
        return try await request("/api/v1/favorites/ids")
    }

    func addFavorite(track: Track) async throws {
        let body = AddFavoriteRequest(
            video_id: track.id,
            title: track.title,
            artist: track.artist,
            thumbnail: track.thumbnail,
            duration: track.duration
        )
        try await requestVoid("/api/v1/favorites", method: "POST", body: body)
    }

    func removeFavorite(videoId: String) async throws {
        try await requestVoid("/api/v1/favorites/\(videoId)", method: "DELETE")
    }

    func reorderFavorites(trackIds: [String]) async throws {
        try await requestVoid("/api/v1/favorites/reorder", method: "PUT", body: ["trackIds": trackIds])
    }

    // MARK: Player state

    func fetchPlayerState() async throws -> PlayerState {
        return try await request("/api/v1/player/state")
    }

    func savePlayerState(_ state: PlayerState) async throws {
        let payload = SavePlayerStateRequest(
            queue: state.queue,
            currentIndex: state.currentIndex,
            position: state.position,
            repeatMode: state.repeatMode,
            currentTrack: state.currentTrack
        )
        try await requestVoid(
            "/api/v1/player/state",
            method: "PUT",
            body: payload
        )
    }

    // MARK: Helpers

    func streamURL(for videoId: String) -> URL {
        makeURL("/api/v1/stream/\(videoId)", queryItems: [URLQueryItem(name: "quality", value: audioQuality)])
    }

    func thumbURL(for videoId: String) -> URL {
        makeURL("/api/v1/thumb/\(videoId)")
    }
}

struct AnyEncodable: Encodable {
    private let encodeBlock: (Encoder) throws -> Void
    init<T: Encodable>(_ value: T) {
        encodeBlock = value.encode
    }
    func encode(to encoder: Encoder) throws {
        try encodeBlock(encoder)
    }
}
