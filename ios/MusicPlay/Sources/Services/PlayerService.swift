import Foundation
import AVFoundation
import MediaPlayer
import Combine

final class PlayerService: ObservableObject {
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var isPlaying: Bool = false
    @Published var volume: Float = 1.0
    @Published var isBuffering: Bool = false
    
    // Crossfade related
    private let playerA = AVPlayer()
    private let playerB = AVPlayer()
    private var activePlayerA = true
    private var isCrossfading = false
    private var isProcessingEnd = false
    private var currentCrossfadeId: UUID?
    
    private var player: AVPlayer { activePlayerA ? playerA : playerB }
    private var secondaryPlayer: AVPlayer { activePlayerA ? playerB : playerA }
    private var timeObserver: (observer: Any, player: AVPlayer)?
    private var crossfadeTimer: Timer?
    private var statusObserver: NSKeyValueObservation?
    private var stallObserver: Any?
    private var resumeObserver: Any?
    private var cancellables = Set<AnyCancellable>()

    private var api: APIClient?
    private weak var playerStore: PlayerStore?
    private weak var historyStore: HistoryStore?
    private weak var appState: AppState?
    private var currentTrackId: String?

    func configure(api: APIClient, playerStore: PlayerStore, historyStore: HistoryStore, appState: AppState) {
        self.api = api
        self.playerStore = playerStore
        self.historyStore = historyStore
        self.appState = appState
        setupAudioSession()
        setupGlobalObservers()
        setupObservers()
        setupRemoteCommands()
    }

    func play(track: Track) {
        // Internal audio-only play method
        playInternal(track: track)
    }

    /// Primary entry point for playing a track with a specific queue context.
    func playTrack(_ track: Track, context: [Track]? = nil) {
        if let context = context {
            playerStore?.setQueue(context, index: context.firstIndex(where: { $0.id == track.id }) ?? 0)
        } else {
            playerStore?.play(track)
        }
        
        if let current = playerStore?.currentTrack {
            playInternal(track: current)
        }
    }

    func playFromQueue(index: Int) {
        playerStore?.playFromQueue(index: index)
        if let current = playerStore?.currentTrack {
            playInternal(track: current)
        }
    }

    func next() {
        guard let store = playerStore else { return }
        let hasNext = store.playNext()
        if hasNext, let nextTrack = store.currentTrack {
            playInternal(track: nextTrack)
        } else {
            stop()
        }
    }

    func previous() {
        guard let store = playerStore else { return }
        store.playPrev()
        if let prevTrack = store.currentTrack {
            playInternal(track: prevTrack)
        }
    }

    private func playInternal(track: Track) {
        guard api != nil else { return }

        // Don't reload if already playing this track and NOT crossfading to it
        if currentTrackId == track.id, player.currentItem != nil, !isCrossfading {
            player.play()
            isPlaying = true
            playerStore?.isPlaying = true
            updateNowPlayingPlaybackState()
            return
        }
        
        // Systematically interrupt any active transitions or playback on both players
        interruptAnyOngoingTransitions()
        
        currentTrackId = track.id
        historyStore?.addTrack(track)
        
        let asset = createAsset(for: track)
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 10

        duration = Double(track.duration)
        currentTime = 0
        isBuffering = true

        statusObserver?.invalidate()
        statusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard let self else { return }
            DispatchQueue.main.async {
                if item.status == .readyToPlay {
                    self.isBuffering = false
                    let dur = item.duration.seconds
                    if dur.isFinite, dur > 0 {
                        self.updateDurationIfTrustworthy(dur)
                        self.updateNowPlaying(track: track, duration: self.duration)
                    }
                } else if item.status == .failed {
                    self.isBuffering = false
                    self.handlePlaybackError()
                }
            }
        }

        try? AVAudioSession.sharedInstance().setActive(true)
        
        // If already playing and crossfade is enabled, handle it
        if isPlaying, appState?.crossfadeEnabled == true, !isCrossfading {
            performCrossfade(with: item, track: track)
        } else {
            // Standard swap/replace
            isCrossfading = false
            player.volume = volume
            player.replaceCurrentItem(with: item)
            player.play()
        }
        
        isPlaying = true
        playerStore?.isPlaying = true
        updateNowPlaying(track: track, duration: 0)
    }
    
    private func performCrossfade(with newItem: AVPlayerItem, track: Track) {
        let fadeId = UUID()
        self.currentCrossfadeId = fadeId
        self.isCrossfading = true
        
        let oldPlayer = self.player
        let newPlayer = self.secondaryPlayer
        let fadeDuration = appState?.crossfadeDuration ?? 6.0
        
        print("Starting crossfade session \(fadeId.uuidString.prefix(8)) for \(track.title)")
        
        // 1. Prepare secondary player
        newPlayer.replaceCurrentItem(with: newItem)
        newPlayer.volume = 0
        newPlayer.play()
        
        // 2. SWAP active player IMMEDIATELY so UI/Observers track the new track
        activePlayerA.toggle()
        
        // 3. Refresh observers for the NEW active player
        reattachObservers()
        updateNowPlaying(track: track, duration: 0)
        
        // 4. Optimized and controllable fade loop
        let steps = 20
        let interval = fadeDuration / Double(steps)
        var currentStep = 0
        
        crossfadeTimer?.invalidate()
        crossfadeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            guard let self = self, self.currentCrossfadeId == fadeId else {
                timer.invalidate()
                return
            }
            
            currentStep += 1
            let progress = Float(currentStep) / Float(steps)
            let currentSystemVolume = self.volume
            
            oldPlayer.volume = currentSystemVolume * (1.0 - progress)
            newPlayer.volume = currentSystemVolume * progress
            
            if currentStep >= steps {
                timer.invalidate()
                print("Crossfade session \(fadeId.uuidString.prefix(8)) completed")
                oldPlayer.pause()
                oldPlayer.replaceCurrentItem(with: nil)
                oldPlayer.volume = self.volume // Reset for next use
                if self.currentCrossfadeId == fadeId {
                    self.isCrossfading = false
                    self.currentCrossfadeId = nil
                }
            }
        }
    }
    
    private func interruptAnyOngoingTransitions() {
        currentCrossfadeId = nil
        isCrossfading = false
        crossfadeTimer?.invalidate()
        crossfadeTimer = nil
        
        // Stop both engines
        playerA.pause()
        playerB.pause()
        
        // Volume reset to prevent "ghost" audio on next start
        playerA.volume = volume
        playerB.volume = volume
    }
    
    private func reattachObservers() {
        // Remove existing observers safely
        removeTimeObserver()
        
        // Setup observers on the now-active player
        setupObservers()
    }
    
    private func removeTimeObserver() {
        if let pair = timeObserver {
            pair.player.removeTimeObserver(pair.observer)
            timeObserver = nil
        }
    }

    /// Load a track and pause at a given position. Used for restoring saved state or retrying.
    func prepareTrack(_ track: Track, at position: Double, autoPlay: Bool = false) {
        guard api != nil else { return }
        currentTrackId = track.id
        let asset = createAsset(for: track)
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 10

        duration = Double(track.duration)
        currentTime = position
        if autoPlay {
            isBuffering = true
        }

        statusObserver?.invalidate()
        statusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard let self else { return }
            DispatchQueue.main.async {
                if item.status == .readyToPlay {
                    if autoPlay { self.isBuffering = false }
                    let dur = item.duration.seconds
                    if dur.isFinite, dur > 0 {
                        self.updateDurationIfTrustworthy(dur)
                        // Seek to saved position once ready
                        if position > 0 && position < dur {
                            self.player.seek(to: CMTime(seconds: position, preferredTimescale: 600)) { _ in
                                if autoPlay { self.resume() }
                            }
                            self.currentTime = position
                        } else {
                            if autoPlay { self.resume() }
                        }
                        self.updateNowPlaying(track: track, duration: self.duration)
                    } else {
                        if autoPlay { self.resume() }
                    }
                } else if item.status == .failed && autoPlay {
                    self.isBuffering = false
                    self.handlePlaybackError()
                }
            }
        }

        try? AVAudioSession.sharedInstance().setActive(true)
        player.replaceCurrentItem(with: item)
        if !autoPlay {
            player.pause()
            isPlaying = false
            playerStore?.isPlaying = false
        }
        updateNowPlaying(track: track, duration: 0)
    }

    func pause() {
        playerA.pause()
        playerB.pause()
        isPlaying = false
        playerStore?.isPlaying = false
        updateNowPlayingPlaybackState()
    }

    func resume() {
        try? AVAudioSession.sharedInstance().setActive(true)
        if player.currentItem == nil, let track = playerStore?.currentTrack {
            play(track: track)
            return
        }
        player.volume = volume
        player.play()
        isPlaying = true
        playerStore?.isPlaying = true
        updateNowPlayingPlaybackState()
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    func seek(to time: Double) {
        let clampedTime = max(0, min(time, duration > 0 ? duration : time))
        player.seek(to: CMTime(seconds: clampedTime, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            self?.currentTime = clampedTime
            self?.playerStore?.position = clampedTime
            self?.updateNowPlayingPlaybackState()
        }
    }

    func setVolume(_ value: Float) {
        volume = value
        player.volume = value
    }

    func stop() {
        playerA.pause()
        playerB.pause()
        playerA.replaceCurrentItem(with: nil)
        playerB.replaceCurrentItem(with: nil)
        currentTrackId = nil
        isPlaying = false
        isBuffering = false
        currentTime = 0
        duration = 0
        playerStore?.isPlaying = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private var apiToken: String {
        api?.accessToken ?? ""
    }

    private func setupObservers() {
        // Remove existing observer first to prevent leaks
        removeTimeObserver()
        
        let targetPlayer = self.player
        
        // Periodic time observer on active player
        let observer = targetPlayer.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] time in
            guard let self else { return }
            
            // Do not advance the slider if the player is buffering or paused
            guard targetPlayer.timeControlStatus == .playing else { return }
            
            let seconds = time.seconds
            guard seconds.isFinite else { return }
            
            // Clamping to avoid "visual continuation" past the intentional end
            let effectiveDuration = self.duration
            self.currentTime = effectiveDuration > 0 ? min(seconds, effectiveDuration) : seconds
            self.playerStore?.position = self.currentTime
            
            // Reconcile duration from player if it becomes available/changes
            if let dur = targetPlayer.currentItem?.duration.seconds, dur.isFinite, dur > 0 {
                self.updateDurationIfTrustworthy(dur)
            }
            
            // Systemic end-of-track check (handles crossfade AND safety-net autoplay)
            self.checkPlaybackProgress(seconds: seconds)
        }
        
        timeObserver = (observer, targetPlayer)
    }

    private func checkPlaybackProgress(seconds: Double) {
        guard let appState = self.appState, let store = self.playerStore, !isCrossfading else { return }
        
        let dur = self.duration
        guard dur > 0 else { return }
        
        let remaining = dur - seconds
        
        // 1. Crossfade Logic
        if appState.crossfadeEnabled {
            if remaining <= appState.crossfadeDuration && remaining > 0 {
                // Determine if we actually have a logical next track to fade to
                let hasNext = store.currentIndex + 1 < store.queue.count || store.repeatMode == "all"
                if hasNext && store.repeatMode != "one" {
                    self.triggerNextWithCrossfade()
                    return
                }
            }
        }
        
        // 2. Safety Net for Autoplay
        // If AVPlayer misses the end notification or is confused by corrupt duration info,
        // we manually move to the next track when we reach the end of our reconciled duration.
        // We use a small threshold to avoid "jumping" too early, but guarantee transition.
        if seconds >= dur - 0.2 {
            print("🏁 Safety net: Track reached logical end at \(seconds)/\(dur)")
            self.handleEnded()
        }
    }

    private func setupGlobalObservers() {
        // Track ended
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
            .sink { [weak self] notification in
                // Verify this notification is for our current item
                guard let self,
                      let endedItem = notification.object as? AVPlayerItem,
                      endedItem == self.player.currentItem else { return }
                self.handleEnded()
            }
            .store(in: &cancellables)

        // Playback error
        NotificationCenter.default.publisher(for: .AVPlayerItemFailedToPlayToEndTime)
            .sink { [weak self] notification in
                guard let self,
                      let failedItem = notification.object as? AVPlayerItem,
                      failedItem == self.player.currentItem else { return }
                if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                    print("Playback error: \(error.localizedDescription)")
                }
                self.handlePlaybackError()
            }
            .store(in: &cancellables)

        // Stall detection — playback stalled (buffering)
        stallObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemPlaybackStalled,
            object: nil, queue: .main
        ) { [weak self] notification in
            guard let self,
                  let stalledItem = notification.object as? AVPlayerItem,
                  stalledItem == self.player.currentItem else { return }
            self.isBuffering = true
            // Player will auto-resume when buffer is sufficient
        }

        // Observe player.timeControlStatus for buffering state
        playerA.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.handleStatusChange(status, isPlayerA: true)
            }
            .store(in: &cancellables)
            
        playerB.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.handleStatusChange(status, isPlayerA: false)
            }
            .store(in: &cancellables)
            
        // Observe audio session interruptions (phone calls, etc.)

        // Observe audio session interruptions (phone calls, etc.)
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] notification in
                guard let self,
                      let info = notification.userInfo,
                      let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

                if type == .began {
                    self.isPlaying = false
                    self.playerStore?.isPlaying = false
                    self.updateNowPlayingPlaybackState()
                } else if type == .ended {
                    if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                        let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                        if options.contains(.shouldResume) {
                            self.resume()
                        }
                    }
                }
            }
            .store(in: &cancellables)

        // Handle route changes (headphones disconnected)
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .sink { [weak self] notification in
                guard let self,
                      let info = notification.userInfo,
                      let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
                      let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

                if reason == .oldDeviceUnavailable {
                    // Headphones unplugged — pause
                    DispatchQueue.main.async {
                        self.pause()
                    }
                }
            }
            .store(in: &cancellables)
    }

    private func triggerNextWithCrossfade() {
        guard let store = playerStore, !isCrossfading else { return }
        
        // If repeat one is on, or no next track (and no wrap), don't crossfade
        if store.repeatMode == "one" { return }
        
        // Peek if there is a next track (including wrap-around)
        let hasNext = store.currentIndex + 1 < store.queue.count || store.repeatMode == "all"
        guard hasNext else { return }
        
        print("Starting auto-crossfade to next track")
        let triggered = store.playNext(isAutoTrigger: true)
        if triggered, let next = store.currentTrack {
            self.playInternal(track: next)
        }
    }

    private func handleStatusChange(_ status: AVPlayer.TimeControlStatus, isPlayerA: Bool) {
        // Only care about status changes from the ACTIVE player
        guard isPlayerA == activePlayerA else { return }
        
        switch status {
        case .playing:
            self.isBuffering = false
        case .waitingToPlayAtSpecifiedRate:
            self.isBuffering = true
        case .paused:
            self.isBuffering = false
        @unknown default:
            break
        }
    }

    private func handleEnded() {
        guard !isProcessingEnd else { return }
        isProcessingEnd = true
        
        DispatchQueue.main.async { [weak self] in
            defer { self?.isProcessingEnd = false }
            guard let self, let store = self.playerStore else { return }
            
            // If crossfade is in progress, it means this "end" is from the OLD track.
            // We ALREADY triggered the next track, so we just ignore this notification.
            if self.isCrossfading {
                print("Track ended while crossfading - ignoring secondary end notification")
                return
            }
            
            if store.repeatMode == "one" {
                print("Looping track: Repeat mode is 'one'")
                self.seek(to: 0)
                self.player.play()
                self.isPlaying = true
                store.isPlaying = true
                return
            }
            
            let hasNext = store.playNext()
            if hasNext, let next = store.currentTrack {
                print("Autoplay: Transitioning to next track \(next.title)")
                self.playInternal(track: next)
            } else {
                print("Queue end: Stopping playback")
                self.stop()
            }
        }
    }

    private var errorCount = 0
    private func handlePlaybackError() {
        guard let store = playerStore, let current = store.currentTrack else { return }
        
        errorCount += 1
        print("Playback error count: \(errorCount). Retrying indefinitely as requested.")
        
        // Retry playing the same track after a brief delay
        let lastPosition = currentTime
        let retryTrackId = current.id
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self, self.currentTrackId == retryTrackId else { return }
            print("Retrying playback for \(retryTrackId) at \(lastPosition) (attempt \(self.errorCount))")
            
            // Systemic fix: Clear error state in DownloadsStore so the red icon disappears on retry
            self.appState?.downloadsStore.clearError(id: retryTrackId)
            
            // Set currentTrackId to nil to force recreation of player item
            self.currentTrackId = nil
            self.prepareTrack(current, at: lastPosition, autoPlay: true)
        }
    }

    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetooth])
            try session.setActive(true)
        } catch {
            print("Audio session setup error: \(error)")
        }
    }

    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.resume()
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }

        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }

        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.next()
            return .success
        }

        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.previous()
            return .success
        }

        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self, let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self.seek(to: positionEvent.positionTime)
            return .success
        }
    }

    private func updateNowPlaying(track: Track, duration: Double = 0) {
        let info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyPlaybackDuration: duration > 0 ? duration : self.duration,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func updateNowPlayingPlaybackState() {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        if duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func updateDurationIfTrustworthy(_ newDuration: Double) {
        guard newDuration.isFinite, newDuration > 0 else { return }
        
        // Use the duration from the track metadata (from YouTube API) as the authoritative source
        let trackDuration = Double(playerStore?.currentTrack?.duration ?? 0)
        
        if trackDuration > 0 {
            // If the player reports a duration significantly different from the API (e.g. 2x), 
            // it's likely a sample rate or VBR estimation error. We trust the API "ground truth".
            let difference = abs(newDuration - trackDuration)
            if difference > trackDuration * 0.1 { // More than 10% difference
                if self.duration != trackDuration {
                    print("⚠️ Player reported duration \(newDuration)s deviates significantly from API \(trackDuration)s. Trusting API.")
                    self.duration = trackDuration
                }
                return
            }
        }
        
        self.duration = newDuration
    }

    private func createAsset(for track: Track) -> AVURLAsset {
        guard let api else { return AVURLAsset(url: URL(string: "about:blank")!) }
        let url = api.streamURL(for: track.id)
        if let localURL = AudioCacheService.shared.localURL(for: track.id) {
            print("Playing from cache: \(track.id)")
            // Systemic fix: Ensure it's in downloads store if we play it from cache
            appState?.downloadsStore.saveTrackInternal(track)
            return AVURLAsset(url: localURL)
        } else {
            print("Streaming and caching: \(track.id)")
            let headers = ["Authorization": "Bearer \(apiToken)"]
            // Automatically cache while streaming
            AudioCacheService.shared.cacheTrack(id: track.id, remoteURL: url, token: apiToken)
            
            // Systemic fix: Tell the store to expect this track as a download
            // so that once AudioCacheService finishes, it knows WHICH track object to save.
            appState?.downloadsStore.registerPotentialTrack(track)
            
            return AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        }
    }
    func downloadTrack(_ track: Track) {
        guard let api else { return }
        
        // Systemic fix: If already cached, just ensure it's in the downloads list
        if AudioCacheService.shared.localURL(for: track.id) != nil {
            print("Track \(track.id) already cached. Adding to list.")
            appState?.downloadsStore.saveTrackInternal(track)
            return
        }
        
        let url = api.streamURL(for: track.id)
        // Add to pending immediately so it shows up in UI
        appState?.downloadsStore.startDownload(track)
        AudioCacheService.shared.cacheTrack(id: track.id, remoteURL: url, token: apiToken)
    }
}

final class AudioCacheService {
    static let shared = AudioCacheService()
    
    private let fileManager = FileManager.default
    private lazy var cacheDirectory: URL = {
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("AudioCache")
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }()
    
    private let maxCacheSize: UInt64 = UInt64.max // Effectively unlimited
    
    private var downloadTasks: [String: Task<Void, Never>] = [:]
    private let queue = DispatchQueue(label: "com.musicplay.audiocache", qos: .userInitiated)
    private var lastCleanupDate = Date.distantPast
    
    private init() {
        cleanUpCacheIfNeeded()
    }
    
    func localURL(for trackId: String) -> URL? {
        let fileURL = cacheDirectory.appendingPathComponent("\(trackId).m4a")
        if fileManager.fileExists(atPath: fileURL.path) {
            // Touch file to update modification date for LRU eviction
            try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: fileURL.path)
            return fileURL
        }
        return nil
    }
    
    func removeTrack(id trackId: String) {
        queue.sync {
            if let task = downloadTasks[trackId] {
                task.cancel()
                downloadTasks.removeValue(forKey: trackId)
            }
            let finalURL = cacheDirectory.appendingPathComponent("\(trackId).m4a")
            let tempURL = cacheDirectory.appendingPathComponent("\(trackId).tmp")
            try? fileManager.removeItem(at: finalURL)
            try? fileManager.removeItem(at: tempURL)
        }
    }
    
    func cacheTrack(id trackId: String, remoteURL: URL, token: String) {
        queue.sync {
            if downloadTasks[trackId] != nil { return }
            if localURL(for: trackId) != nil { return }
            
            let task = Task {
                await download(trackId: trackId, remoteURL: remoteURL, token: token)
            }
            downloadTasks[trackId] = task
        }
    }
    
    private func download(trackId: String, remoteURL: URL, token: String) async {
        let tempURL = cacheDirectory.appendingPathComponent("\(trackId).tmp")
        let finalURL = cacheDirectory.appendingPathComponent("\(trackId).m4a")
        
        var request = URLRequest(url: remoteURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("true", forHTTPHeaderField: "X-Full-Download")
        
        do {
            let delegate = ProgressDownloadDelegate(trackId: trackId)
            let (downloadURL, response) = try await URLSession.shared.download(for: request, delegate: delegate)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 || httpResponse.statusCode == 206 else {
                queue.sync { downloadTasks.removeValue(forKey: trackId) }
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: NSNotification.Name("TrackDownloadFailed"), object: trackId)
                }
                return
            }
            
            if fileManager.fileExists(atPath: finalURL.path) {
                try? fileManager.removeItem(at: finalURL)
            }
            if fileManager.fileExists(atPath: tempURL.path) {
                try? fileManager.removeItem(at: tempURL)
            }
            
            try fileManager.moveItem(at: downloadURL, to: tempURL)
            try fileManager.moveItem(at: tempURL, to: finalURL)
            
            cleanUpCacheIfNeeded()
            print("Successfully cached track: \(trackId)")
        } catch {
            print("Failed to cache track \(trackId): \(error)")
            try? fileManager.removeItem(at: tempURL)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("TrackDownloadFailed"), object: trackId)
            }
        }
        
        queue.sync {
            downloadTasks.removeValue(forKey: trackId)
        }
    }
    
    func clearCache() {
        queue.sync {
            for task in downloadTasks.values { task.cancel() }
            downloadTasks.removeAll()
            do {
                let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
                for file in files { try fileManager.removeItem(at: file) }
            } catch { print("Failed to clear audio cache: \(error)") }
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("CacheCleared"), object: nil)
        }
    }
    
    func getCacheSize() -> UInt64 {
        var totalSize: UInt64 = 0
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
            for file in files {
                let attrs = try file.resourceValues(forKeys: [.fileSizeKey])
                if let size = attrs.fileSize {
                    totalSize += UInt64(size)
                }
            }
        } catch {
            print("Error getting cache size: \(error)")
        }
        return totalSize
    }
    
    private func cleanUpCacheIfNeeded() {
        let now = Date()
        guard now.timeIntervalSince(lastCleanupDate) > 60 else { return }
        lastCleanupDate = now
        
        queue.async { [weak self] in
            guard let self else { return }
            do {
                let resourceKeys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
                let files = try self.fileManager.contentsOfDirectory(at: self.cacheDirectory, includingPropertiesForKeys: resourceKeys)
                
                var totalSize: UInt64 = 0
                var fileProps: [(url: URL, size: UInt64, date: Date)] = []
                
                for file in files {
                    guard file.pathExtension == "m4a" else { continue }
                    let attrs = try file.resourceValues(forKeys: Set(resourceKeys))
                    if let size = attrs.fileSize, let date = attrs.contentModificationDate {
                        totalSize += UInt64(size)
                        fileProps.append((url: file, size: UInt64(size), date: date))
                    }
                }
                
                if totalSize > self.maxCacheSize {
                    fileProps.sort { $0.date < $1.date }
                    var currentSize = totalSize
                    for prop in fileProps {
                        if currentSize <= self.maxCacheSize { break }
                        try? self.fileManager.removeItem(at: prop.url)
                        currentSize -= prop.size
                        print("Evicted track from cache: \(prop.url.lastPathComponent)")
                    }
                }
            } catch {
                print("Cache cleanup error: \(error)")
            }
        }
    }
}

final class ProgressDownloadDelegate: NSObject, URLSessionDownloadDelegate {
    let trackId: String
    private var lastUpdate: TimeInterval = 0
    
    init(trackId: String) {
        self.trackId = trackId
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let now = Date().timeIntervalSince1970
        if totalBytesExpectedToWrite > 0 && (now - lastUpdate) > 0.1 {
            let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("TrackDownloadProgress"), object: self.trackId, userInfo: ["progress": progress])
            }
            lastUpdate = now
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("TrackDownloadProgress"), object: self.trackId, userInfo: ["progress": 1.0])
        }
    }
}
