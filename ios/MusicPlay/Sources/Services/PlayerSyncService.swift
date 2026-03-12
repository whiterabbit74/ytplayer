import Foundation

final class PlayerSyncService: ObservableObject {
    private var api: APIClient?
    private weak var playerStore: PlayerStore?
    private var timer: Timer?
    private var lastSync: Date = .distantPast
    private var isSyncing = false

    func configure(api: APIClient, playerStore: PlayerStore) {
        self.api = api
        self.playerStore = playerStore
    }

    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { await self?.sync() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    @MainActor
    func loadInitialState() async {
        guard let api else { return }
        do {
            let state = try await api.fetchPlayerState()
            playerStore?.queue = state.queue
            playerStore?.currentIndex = state.currentIndex
            playerStore?.currentTrack = state.currentTrack ?? state.queue[safe: state.currentIndex]
            playerStore?.repeatMode = state.repeatMode
            playerStore?.position = state.position
        } catch {
            print("loadInitialState error", error)
        }
    }

    @MainActor
    func sync(force: Bool = false) async {
        guard let api, let store = playerStore else { return }
        if isSyncing { return }
        if !force && Date().timeIntervalSince(lastSync) < 10 { return }
        isSyncing = true
        defer {
            isSyncing = false
            lastSync = Date()
        }
        let state = PlayerState(
            queue: store.queue,
            currentIndex: store.currentIndex,
            position: store.position,
            repeatMode: store.repeatMode,
            currentTrack: store.currentTrack
        )
        do {
            try await api.savePlayerState(state)
        } catch {
            print("sync error", error)
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0 && index < count else { return nil }
        return self[index]
    }
}
