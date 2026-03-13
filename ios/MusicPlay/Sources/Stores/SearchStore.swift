import Foundation

final class SearchStore: ObservableObject {
    @Published var results: [Track] = []
    @Published var nextPageToken: String?
    @Published var isSearching = false
    @Published var suggestions: [String] = []
    @Published var hasSearched = false  // Track whether a search has been performed
    @Published var recentSearches: [String] = []

    private var api: APIClient?
    private var suggestionTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var lastQuery: String = ""
    
    private let recentSearchesKey = "RecentSearches"

    func configure(api: APIClient) {
        self.api = api
        loadRecentSearches()
    }
    
    private func loadRecentSearches() {
        if let stored = UserDefaults.standard.stringArray(forKey: recentSearchesKey) {
            recentSearches = stored
        }
    }
    
    func addRecentSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        var current = recentSearches
        current.removeAll { $0.lowercased() == trimmed.lowercased() }
        current.insert(trimmed, at: 0)
        
        if current.count > 10 {
            current = Array(current.prefix(10))
        }
        
        recentSearches = current
        UserDefaults.standard.set(current, forKey: recentSearchesKey)
    }

    func removeRecentSearch(_ query: String) {
        var current = recentSearches
        current.removeAll { $0 == query }
        recentSearches = current
        UserDefaults.standard.set(current, forKey: recentSearchesKey)
    }

    func clearRecentSearches() {
        recentSearches = []
        UserDefaults.standard.removeObject(forKey: recentSearchesKey)
    }

    @MainActor
    func search(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let api else { return }

        // Cancel any in-flight suggestion task
        suggestionTask?.cancel()
        suggestions = []
        lastQuery = trimmed

        isSearching = true
        hasSearched = true
        do {
            let res = try await api.search(query: trimmed)
            // Only apply results if this is still the current query
            if lastQuery == trimmed {
                results = res.tracks.filter { $0.duration > 0 }
                nextPageToken = res.nextPageToken
            }
        } catch {
            print("search error", error)
        }
        if lastQuery == trimmed {
            isSearching = false
        }
    }

    @MainActor
    func loadMore(query: String) async {
        guard let api else { return }
        guard let token = nextPageToken, !isSearching else { return }
        isSearching = true
        defer { isSearching = false }
        do {
            let res = try await api.search(query: query, pageToken: token)
            results.append(contentsOf: res.tracks.filter { $0.duration > 0 })
            nextPageToken = res.nextPageToken
        } catch {
            print("loadMore error", error)
        }
    }

    @MainActor
    func clearResults() {
        results = []
        nextPageToken = nil
        hasSearched = false
        suggestions = []
        lastQuery = ""
    }

    func fetchSuggestions(query: String) {
        suggestionTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count < 2 {
            Task { @MainActor in
                suggestions = []
            }
            return
        }
        suggestionTask = Task { @MainActor in
            guard let api else { return }
            try? await Task.sleep(nanoseconds: 300_000_000)
            // Check cancellation after sleep
            guard !Task.isCancelled else { return }
            do {
                let result = try await api.suggestions(query: trimmed)
                guard !Task.isCancelled else { return }
                suggestions = result
            } catch {
                if !Task.isCancelled {
                    suggestions = []
                }
            }
        }
    }
}
