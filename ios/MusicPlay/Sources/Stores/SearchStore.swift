import Foundation

final class SearchStore: ObservableObject {
    @Published var results: [Track] = []
    @Published var nextPageToken: String?
    @Published var isSearching = false
    @Published var suggestions: [String] = []

    private var api: APIClient?
    private var suggestionTask: Task<Void, Never>?

    func configure(api: APIClient) {
        self.api = api
    }

    @MainActor
    func search(query: String) async {
        guard let api else { return }
        suggestions = []
        isSearching = true
        defer { isSearching = false }
        do {
            let res = try await api.search(query: query)
            results = res.tracks
            nextPageToken = res.nextPageToken
        } catch {
            print("search error", error)
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
            results.append(contentsOf: res.tracks)
            nextPageToken = res.nextPageToken
        } catch {
            print("loadMore error", error)
        }
    }

    func fetchSuggestions(query: String) {
        suggestionTask?.cancel()
        suggestionTask = Task { @MainActor in
            guard let api else { return }
            if query.count < 2 {
                suggestions = []
                return
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
            do {
                suggestions = try await api.suggestions(query: query)
            } catch {
                suggestions = []
            }
        }
    }
}
