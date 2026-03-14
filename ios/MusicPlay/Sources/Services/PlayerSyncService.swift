import Foundation
import UIKit

final class PlayerSyncService: ObservableObject {
    private var api: APIClient?
    private weak var playerStore: PlayerStore?
    private weak var playerService: PlayerService?
    private var timer: Timer?
    private var lastSync: Date = .distantPast
    private var isSyncing = false
    private var backgroundObserver: Any?
    private var terminateObserver: Any?

    func configure(api: APIClient, playerStore: PlayerStore, playerService: PlayerService) {
        self.api = api
        self.playerStore = playerStore
        self.playerService = playerService
    }

    func start() {
        stop()
        let t = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            Task { await self?.sync() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t

        // Save state when app goes to background or is about to terminate
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { await self?.sync(force: true) }
        }

        terminateObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            let taskId = UIApplication.shared.beginBackgroundTask(withName: "FinalSync") {
                // End task if it takes too long
            }
            Task {
                await self?.sync(force: true)
                UIApplication.shared.endBackgroundTask(taskId)
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let obs = backgroundObserver {
            NotificationCenter.default.removeObserver(obs)
            backgroundObserver = nil
        }
        if let obs = terminateObserver {
            NotificationCenter.default.removeObserver(obs)
            terminateObserver = nil
        }
    }

    @MainActor
    func loadInitialState() async {
        guard let api else { return }
        do {
            let state = try await api.fetchPlayerState()
            guard let store = playerStore else { return }

            store.setQueue(state.queue, index: state.currentIndex)
            store.repeatMode = state.repeatMode

            // Determine current track
            let track = state.currentTrack ?? state.queue[safe: state.currentIndex]
            store.currentTrack = track

            // If there was a track playing, prepare the player at the saved position
            // but don't auto-play — user will tap play when ready
            if let track, let service = playerService {
                service.prepareTrack(track, at: state.position)
            }
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

        // Use live position from PlayerService if available
        let position = playerService?.currentTime ?? 0

        let state = PlayerState(
            queue: store.queue.map { $0.track },
            currentIndex: store.currentIndex,
            position: position,
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
