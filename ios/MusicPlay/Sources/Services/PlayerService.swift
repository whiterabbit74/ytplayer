import Foundation
import AVFoundation
import MediaPlayer
import Combine

@MainActor
final class PlayerService: ObservableObject {
    var currentTime: Double = 0
    var duration: Double = 0
    @Published var isBuffering: Bool = false
    @Published var isPlaying: Bool = false
    @Published var volume: Float = 1.0
    
    // Dedicated store for high-frequency UI updates
    private var progressStore: PlaybackProgressStore?
    
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

    func configure(api: APIClient, playerStore: PlayerStore, historyStore: HistoryStore, progressStore: PlaybackProgressStore, appState: AppState) {
        self.api = api
        self.playerStore = playerStore
        self.historyStore = historyStore
        self.progressStore = progressStore
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
            progressStore?.isPlaying = true
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
        
        progressStore?.duration = duration
        progressStore?.currentTime = 0
        progressStore?.isPlaying = true
        progressStore?.isBuffering = true

        statusObserver?.invalidate()
        statusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard let self else { return }
            Task { @MainActor in
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
        progressStore?.isPlaying = true
        updateNowPlaying(track: track, duration: duration)
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
        
        // Wait for secondary player to be ready before starting fade
        statusObserver?.invalidate()
        statusObserver = newItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard let self = self else { return }
            Task { @MainActor in
                if item.status == .readyToPlay {
                    newPlayer.play()
                    self.startFadeLogic(fadeId: fadeId, oldPlayer: oldPlayer, newPlayer: newPlayer, fadeDuration: fadeDuration, track: track)
                } else if item.status == .failed {
                    print("❌ Crossfade secondary track failed to load, aborting fade")
                    self.isCrossfading = false
                    self.currentCrossfadeId = nil
                }
            }
        }
    }
    
    private func startFadeLogic(fadeId: UUID, oldPlayer: AVPlayer, newPlayer: AVPlayer, fadeDuration: Double, track: Track) {
        // 2. SWAP active player IMMEDIATELY so UI/Observers track the new track
        activePlayerA.toggle()
        
        // 3. Refresh observers for the NEW active player
        reattachObservers()
        updateNowPlaying(track: track, duration: duration)
        
        // 4. Optimized and controllable fade loop
        let steps = 20
        let interval = fadeDuration / Double(steps)
        var currentStep = 0
        
        crossfadeTimer?.invalidate()
        crossfadeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            Task { @MainActor in
                guard self.currentCrossfadeId == fadeId else {
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
        
        // Optimization: if we are just preparing (e.g. app launch), don't trigger download if not in cache
        let asset: AVURLAsset
        if !autoPlay && AudioCacheService.shared.localURL(for: track.id) == nil {
            print("Preparing track (launch/restore) without auto-caching: \(track.id)")
            if let streamURL = api?.streamURL(for: track.id) {
                asset = AVURLAsset(url: streamURL)
            } else {
                asset = AVURLAsset(url: URL(string: "about:blank")!)
            }
        } else {
            asset = createAsset(for: track)
        }
        
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 10

        duration = Double(track.duration)
        currentTime = position
        progressStore?.duration = duration
        progressStore?.currentTime = position
        progressStore?.isPlaying = autoPlay
        
        if autoPlay {
            isBuffering = true
        }

        statusObserver?.invalidate()
        statusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard let self else { return }
            Task { @MainActor in
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
        progressStore?.isPlaying = false
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
        progressStore?.isPlaying = true
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
            Task { @MainActor in
                self?.currentTime = clampedTime
                self?.progressStore?.currentTime = clampedTime
                self?.updateNowPlayingPlaybackState()
            }
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
        progressStore?.duration = 0
        progressStore?.currentTime = 0
        progressStore?.isPlaying = false
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
            self.progressStore?.currentTime = self.currentTime
            self.progressStore?.isPlaying = true
            
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
        if seconds >= dur - 0.2 {
            print("🏁 Safety net: Track reached logical end at \(seconds)/\(dur)")
            self.handleEnded()
        }
    }

    private func setupGlobalObservers() {
        // Track ended
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
            .receive(on: DispatchQueue.main)
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
            .receive(on: DispatchQueue.main)
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

        // Stall detection
        stallObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemPlaybackStalled,
            object: nil, queue: .main
        ) { [weak self] notification in
            guard let self,
                  let stalledItem = notification.object as? AVPlayerItem,
                  stalledItem == self.player.currentItem else { return }
            self.isBuffering = true
        }

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
            
        // Interruptions
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .receive(on: DispatchQueue.main)
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

        // Route changes
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self,
                      let info = notification.userInfo,
                      let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
                      let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

                if reason == .oldDeviceUnavailable {
                    self.pause()
                }
            }
            .store(in: &cancellables)
    }

    private func triggerNextWithCrossfade() {
        guard let store = playerStore, !isCrossfading else { return }
        
        if store.repeatMode == "one" { return }
        
        let hasNext = store.currentIndex + 1 < store.queue.count || store.repeatMode == "all"
        guard hasNext else { return }
        
        print("Starting auto-crossfade to next track")
        let triggered = store.playNext(isAutoTrigger: true)
        if triggered, let next = store.currentTrack {
            self.playInternal(track: next)
        }
    }

    private func handleStatusChange(_ status: AVPlayer.TimeControlStatus, isPlayerA: Bool) {
        guard isPlayerA == activePlayerA else { return }
        
        switch status {
        case .playing:
            self.isBuffering = false
            self.progressStore?.isBuffering = false
        case .waitingToPlayAtSpecifiedRate:
            self.isBuffering = true
            self.progressStore?.isBuffering = true
        case .paused:
            self.isBuffering = false
            self.progressStore?.isBuffering = false
        @unknown default:
            break
        }
    }

    private func handleEnded() {
        guard !isProcessingEnd else { return }
        isProcessingEnd = true
        
        defer { self.isProcessingEnd = false }
        guard let store = self.playerStore else { return }
        
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

    private var errorCount = 0
    private func handlePlaybackError() {
        guard let store = playerStore, let current = store.currentTrack else { return }
        
        errorCount += 1
        print("Playback error count: \(errorCount). Retrying indefinitely.")
        
        let lastPosition = currentTime
        let retryTrackId = current.id
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                guard self.currentTrackId == retryTrackId else { return }
                print("Retrying playback for \(retryTrackId) at \(lastPosition)")
                self.appState?.downloadsStore.clearError(id: retryTrackId)
                self.currentTrackId = nil
                self.prepareTrack(current, at: lastPosition, autoPlay: true)
            }
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
            guard let self = self else { return .commandFailed }
            Task { @MainActor in self.resume() }
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in self.pause() }
            return .success
        }

        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in self.togglePlayPause() }
            return .success
        }

        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in self.next() }
            return .success
        }

        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in self.previous() }
            return .success
        }

        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self, let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            Task { @MainActor in self.seek(to: positionEvent.positionTime) }
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
        
        let trackDuration = Double(playerStore?.currentTrack?.duration ?? 0)
        
        if trackDuration > 0 {
            let difference = abs(newDuration - trackDuration)
            if difference > trackDuration * 0.1 {
                if self.duration != trackDuration {
                    print("⚠️ Duration mismatch. Trusting API.")
                    self.duration = trackDuration
                    self.progressStore?.duration = trackDuration
                }
                return
            }
            
            if abs(newDuration - trackDuration) > 0.5 {
                print("📝 Updating track duration to ground truth: \(newDuration)s")
                self.duration = newDuration
                self.progressStore?.duration = newDuration
                if let trackId = playerStore?.currentTrack?.id {
                    playerStore?.updateTrackDuration(id: trackId, duration: Int(newDuration))
                }
            }
        }
        
        if self.duration != newDuration {
            self.duration = newDuration
            self.progressStore?.duration = newDuration
        }
    }

    private var resourceLoaderDelegate: AudioResourceLoaderDelegate?

    private func createAsset(for track: Track) -> AVURLAsset {
        guard let api else { return AVURLAsset(url: URL(string: "about:blank")!) }
        
        if let localURL = AudioCacheService.shared.localURL(for: track.id) {
            print("Playing from cache: \(track.id)")
            appState?.downloadsStore.saveTrackInternal(track)
            return AVURLAsset(url: localURL)
        } else {
            print("Streaming via Direct Resolution: \(track.id)")
            
            // Use custom scheme to trigger resource loader
            let streamURL = URL(string: "musicplay-direct://\(track.id)")!
            
            let asset = AVURLAsset(url: streamURL)
            let delegate = AudioResourceLoaderDelegate(trackId: track.id, api: api)
            self.resourceLoaderDelegate = delegate
            asset.resourceLoader.setDelegate(delegate, queue: .main)
            
            appState?.downloadsStore.registerPotentialTrack(track)
            return asset
        }
    }
    
    func downloadTrack(_ track: Track) {
        guard let api else { return }
        
        if AudioCacheService.shared.localURL(for: track.id) != nil {
            appState?.downloadsStore.saveTrackInternal(track)
            return
        }
        
        appState?.downloadsStore.startDownload(track)
        AudioCacheService.shared.cacheTrack(id: track.id, api: api)
    }

    deinit {
        // Cleanup
    }
}

// MARK: - Audio Resource Loader Delegate

final class AudioResourceLoaderDelegate: NSObject, AVAssetResourceLoaderDelegate {
    private let trackId: String
    private let api: APIClient
    private var resolution: StreamResolution?
    private var isResolving = false
    
    private let queue = DispatchQueue(label: "com.musicplay.resource-loader")
    private var activeTasks: [AVAssetResourceLoadingRequest: ResourceLoadingTask] = [:]
    private var isCancelled = false
    
    init(trackId: String, api: APIClient) {
        self.trackId = trackId
        self.api = api
        super.init()
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        queue.async { [weak self] in
            guard let self = self, !self.isCancelled else { return }
            
            if self.resolution == nil {
                self.resolveAndHandle(loadingRequest)
            } else {
                self.startTask(for: loadingRequest)
            }
        }
        return true
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        queue.async { [weak self] in
            guard let self = self else { return }
            if let task = self.activeTasks[loadingRequest] {
                task.cancel()
                self.activeTasks.removeValue(forKey: loadingRequest)
            }
        }
    }
    
    private func resolveAndHandle(_ firstRequest: AVAssetResourceLoadingRequest) {
        guard !isResolving else {
            // Already resolving, request will be handled in startTask after resolution finishes if not already cancelled
            return 
        }
        isResolving = true
        
        Task {
            do {
                print("🌐 Resolving stream for \(trackId)...")
                let res = try await api.resolveStream(videoId: trackId)
                queue.async {
                    self.resolution = res
                    self.isResolving = false
                    // Start all pending tasks now that we have resolution
                    // The player might have queued multiple requests
                    self.startAllPendingTasks()
                }
            } catch {
                print("❌ Failed to resolve stream for \(trackId): \(error)")
                queue.async {
                    self.isResolving = false
                    firstRequest.finishLoading(with: error)
                }
            }
        }
    }
    
    private func startAllPendingTasks() {
        // In this implementation, shouldWaitForLoadingOfRequestedResource is called sequentially.
        // If we were buffering them, we'd loop here. But for now we just handle the immediate ones.
    }
    
    private func startTask(for loadingRequest: AVAssetResourceLoadingRequest) {
        guard let resolution = resolution else { return }
        
        let task = ResourceLoadingTask(
            loadingRequest: loadingRequest,
            resolution: resolution,
            trackId: trackId,
            api: api,
            onComplete: { [weak self, weak loadingRequest] in
                guard let self = self, let req = loadingRequest else { return }
                self.queue.async { self.activeTasks.removeValue(forKey: req) }
            },
            onNeedsRefresh: { [weak self] in
                guard let self = self else { return }
                self.queue.async {
                    self.resolution = nil
                    // If one task says 403, we nullify resolution so next tasks refresh
                }
            }
        )
        activeTasks[loadingRequest] = task
        task.start()
    }
    
    func cancel() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.isCancelled = true
            self.activeTasks.values.forEach { $0.cancel() }
            self.activeTasks.removeAll()
        }
    }
}

// MARK: - Internal Helper Class for Range Loading

private final class ResourceLoadingTask: NSObject, URLSessionDataDelegate {
    private let loadingRequest: AVAssetResourceLoadingRequest
    private let resolution: StreamResolution
    private let trackId: String
    private let api: APIClient
    private let onComplete: () -> Void
    private let onNeedsRefresh: () -> Void
    
    private var session: URLSession?
    private var task: URLSessionDataTask?
    private var response: HTTPURLResponse?
    
    init(loadingRequest: AVAssetResourceLoadingRequest, resolution: StreamResolution, trackId: String, api: APIClient, onComplete: @escaping () -> Void, onNeedsRefresh: @escaping () -> Void) {
        self.loadingRequest = loadingRequest
        self.resolution = resolution
        self.trackId = trackId
        self.api = api
        self.onComplete = onComplete
        self.onNeedsRefresh = onNeedsRefresh
        super.init()
    }
    
    func start() {
        // 1. Fill Content Information if requested
        if let info = loadingRequest.contentInformationRequest {
            info.contentType = resolution.contentType
            info.contentLength = resolution.contentLength
            info.isByteRangeAccessSupported = true
        }
        
        // 2. Prepare Range Data Task if requested
        guard let dataRequest = loadingRequest.dataRequest else {
            loadingRequest.finishLoading()
            onComplete()
            return
        }
        
        let requestedOffset = dataRequest.requestedOffset
        let requestedLength = dataRequest.requestedLength
        let endOffset = requestedOffset + Int64(requestedLength) - 1
        
        var request = URLRequest(url: URL(string: resolution.audioUrl)!)
        for (key, value) in resolution.httpHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Ensure User-Agent
        if request.value(forHTTPHeaderField: "User-Agent") == nil {
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        }
        
        // Set Range Header
        let rangeHeader = "bytes=\(requestedOffset)-\(endOffset)"
        request.setValue(rangeHeader, forHTTPHeaderField: "Range")
        
        print("📥 ResourceLoader Requesting Range: \(rangeHeader) for \(trackId)")
        
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        self.session = session
        
        let task = session.dataTask(with: request)
        self.task = task
        task.resume()
    }
    
    func cancel() {
        task?.cancel()
        session?.invalidateAndCancel()
    }
    
    // URLSessionDataDelegate
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 403 || httpResponse.statusCode == 410 {
                print("⚠️ Range request 403 for \(trackId), triggering refresh...")
                onNeedsRefresh()
                loadingRequest.finishLoading(with: URLError(.resourceUnavailable))
                completionHandler(.cancel)
                onComplete()
                return
            }
            self.response = httpResponse
        }
        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        loadingRequest.dataRequest?.respond(with: data)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            if (error as NSError).code != NSURLErrorCancelled {
                print("❌ ResourceLoader Task Error: \(error.localizedDescription)")
                loadingRequest.finishLoading(with: error)
            }
        } else {
            loadingRequest.finishLoading()
        }
        onComplete()
    }
}

// MARK: - Audio Cache Service

final class AudioCacheService {
    static let shared = AudioCacheService()
    
    private let fileManager = FileManager.default
    private lazy var cacheDirectory: URL = {
        let paths = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("AudioCache")
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }()

    private var oldCacheDirectory: URL {
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("AudioCache")
    }
    
    private let maxCacheSize: UInt64 = 500 * 1024 * 1024 // 500 MB limit
    private var downloadTasks: [String: Task<Void, Never>] = [:]
    private let queue = DispatchQueue(label: "com.musicplay.audiocache", qos: .userInitiated)
    private var lastCleanupDate = Date.distantPast
    
    private init() {
        migrateOldCache()
        cleanUpCacheIfNeeded()
    }

    func getCacheDirectory() -> URL {
        return cacheDirectory
    }

    private func migrateOldCache() {
        let oldDir = oldCacheDirectory
        guard fileManager.fileExists(atPath: oldDir.path) else { return }
        do {
            let files = try fileManager.contentsOfDirectory(at: oldDir, includingPropertiesForKeys: nil)
            for file in files {
                let dest = cacheDirectory.appendingPathComponent(file.lastPathComponent)
                if fileManager.fileExists(atPath: dest.path) { try? fileManager.removeItem(at: dest) }
                try fileManager.moveItem(at: file, to: dest)
            }
            try fileManager.removeItem(at: oldDir)
        } catch { print("❌ Migration failed: \(error)") }
    }
    
    func localURL(for trackId: String) -> URL? {
        let fileURL = cacheDirectory.appendingPathComponent("\(trackId).m4a")
        if fileManager.fileExists(atPath: fileURL.path) {
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
    
    func cacheTrack(id trackId: String, api: APIClient) {
        queue.sync {
            if downloadTasks[trackId] != nil { return }
            if localURL(for: trackId) != nil { return }
            let task = Task { await download(trackId: trackId, api: api) }
            downloadTasks[trackId] = task
        }
    }
    
    private func download(trackId: String, api: APIClient) async {
        let tempURL = cacheDirectory.appendingPathComponent("\(trackId).tmp")
        let finalURL = cacheDirectory.appendingPathComponent("\(trackId).m4a")
        
        do {
            print("🌐 Resolving download URL for \(trackId)...")
            let resolution = try await api.resolveStream(videoId: trackId)
            
            var request = URLRequest(url: URL(string: resolution.audioUrl)!)
            for (key, value) in resolution.httpHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }
            
            // Ensure User-Agent
            if request.value(forHTTPHeaderField: "User-Agent") == nil {
                request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
            }

            let delegate = ProgressDownloadDelegate(trackId: trackId)
            let (downloadURL, response) = try await URLSession.shared.download(for: request, delegate: delegate)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 || httpResponse.statusCode == 206 else {
                print("❌ Download failed with status \( (response as? HTTPURLResponse)?.statusCode ?? 0 )")
                _ = queue.sync { downloadTasks.removeValue(forKey: trackId) }
                DispatchQueue.main.async { NotificationCenter.default.post(name: NSNotification.Name("TrackDownloadFailed"), object: trackId) }
                return
            }
            
            if let duration = resolution.duration {
                DispatchQueue.main.async { NotificationCenter.default.post(name: NSNotification.Name("TrackDurationUpdated"), object: trackId, userInfo: ["duration": Int(duration)]) }
            }
            if fileManager.fileExists(atPath: finalURL.path) { try? fileManager.removeItem(at: finalURL) }
            if fileManager.fileExists(atPath: tempURL.path) { try? fileManager.removeItem(at: tempURL) }
            try fileManager.moveItem(at: downloadURL, to: tempURL)
            try fileManager.moveItem(at: tempURL, to: finalURL)
            cleanUpCacheIfNeeded()
            DispatchQueue.main.async { NotificationCenter.default.post(name: NSNotification.Name("TrackDownloadFinished"), object: trackId) }
        } catch {
            print("Failed to cache track \(trackId): \(error)")
            try? fileManager.removeItem(at: tempURL)
            DispatchQueue.main.async { NotificationCenter.default.post(name: NSNotification.Name("TrackDownloadFailed"), object: trackId) }
        }
        queue.sync { _ = downloadTasks.removeValue(forKey: trackId) }
    }
    
    func clearCache() {
        queue.sync {
            for task in downloadTasks.values { task.cancel() }
            downloadTasks.removeAll()
            try? fileManager.removeItem(at: cacheDirectory)
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
        DispatchQueue.main.async { NotificationCenter.default.post(name: NSNotification.Name("CacheCleared"), object: nil) }
    }
    
    func getCacheSize() -> UInt64 {
        var totalSize: UInt64 = 0
        let files = (try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        for file in files {
            if let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                totalSize += UInt64(size)
            }
        }
        return totalSize
    }
    
    func cleanUpCacheIfNeeded() {
        let now = Date()
        guard now.timeIntervalSince(lastCleanupDate) > 60 else { return }
        lastCleanupDate = now
        queue.async { [weak self] in
            guard let self = self else { return }
            let files = (try? self.fileManager.contentsOfDirectory(at: self.cacheDirectory, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey])) ?? []
            var totalSize: UInt64 = 0
            var fileProps: [(url: URL, size: UInt64, date: Date)] = []
            for file in files where file.pathExtension == "m4a" {
                if let attrs = try? file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]), let size = attrs.fileSize, let date = attrs.contentModificationDate {
                    totalSize += UInt64(size)
                    fileProps.append((url: file, size: UInt64(size), date: date))
                }
            }
            if totalSize > self.maxCacheSize {
                fileProps.sort { $0.date < $1.date }
                var currentSize = totalSize
                for prop in fileProps where currentSize > self.maxCacheSize {
                    let trackId = prop.url.deletingPathExtension().lastPathComponent
                    try? self.fileManager.removeItem(at: prop.url)
                    currentSize -= prop.size
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: NSNotification.Name("TrackEvictedFromCache"), object: trackId)
                    }
                }
            }
        }
    }
}

final class ProgressDownloadDelegate: NSObject, URLSessionDownloadDelegate {
    let trackId: String
    private var lastUpdate: TimeInterval = 0
    init(trackId: String) { self.trackId = trackId }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let now = Date().timeIntervalSince1970
        if totalBytesExpectedToWrite > 0 && (now - lastUpdate) > 0.1 {
            let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            DispatchQueue.main.async { NotificationCenter.default.post(name: NSNotification.Name("TrackDownloadProgress"), object: self.trackId, userInfo: ["progress": progress]) }
            lastUpdate = now
        }
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        DispatchQueue.main.async { NotificationCenter.default.post(name: NSNotification.Name("TrackDownloadProgress"), object: self.trackId, userInfo: ["progress": 1.0]) }
    }
}
