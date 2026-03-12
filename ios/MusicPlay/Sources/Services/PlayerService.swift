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

    private let player = AVPlayer()
    private var timeObserver: Any?
    private var statusObserver: NSKeyValueObservation?
    private var stallObserver: Any?
    private var resumeObserver: Any?
    private var cancellables = Set<AnyCancellable>()

    private var api: APIClient?
    private weak var playerStore: PlayerStore?
    private var currentTrackId: String?

    func configure(api: APIClient, playerStore: PlayerStore) {
        self.api = api
        self.playerStore = playerStore
        setupAudioSession()
        setupObservers()
        setupRemoteCommands()
    }

    func play(track: Track) {
        guard let api else { return }

        // Don't reload if already playing this track
        if currentTrackId == track.id, player.currentItem != nil {
            player.play()
            isPlaying = true
            playerStore?.isPlaying = true
            updateNowPlayingPlaybackState()
            return
        }

        currentTrackId = track.id
        let asset = createAsset(for: track)
        let item = AVPlayerItem(asset: asset)

        // Set preferred buffer duration for smoother streaming
        item.preferredForwardBufferDuration = 10

        // Reset duration before loading new track
        duration = Double(track.duration)
        currentTime = 0
        isBuffering = true

        // Observe status to get duration when ready
        statusObserver?.invalidate()
        statusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard let self else { return }
            DispatchQueue.main.async {
                if item.status == .readyToPlay {
                    self.isBuffering = false
                    let dur = item.duration.seconds
                    if dur.isFinite, dur > 0 {
                        self.duration = dur
                        self.updateNowPlaying(track: track, duration: dur)
                    }
                } else if item.status == .failed {
                    self.isBuffering = false
                    print("PlayerItem failed: \(item.error?.localizedDescription ?? "unknown")")
                    self.handlePlaybackError()
                }
            }
        }

        try? AVAudioSession.sharedInstance().setActive(true)
        player.volume = volume
        player.replaceCurrentItem(with: item)
        player.play()
        isPlaying = true
        playerStore?.isPlaying = true
        updateNowPlaying(track: track, duration: 0)
    }

    /// Load a track and pause at a given position. Used for restoring saved state or retrying.
    func prepareTrack(_ track: Track, at position: Double, autoPlay: Bool = false) {
        guard let api else { return }
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
                        self.duration = dur
                        // Seek to saved position once ready
                        if position > 0 && position < dur {
                            self.player.seek(to: CMTime(seconds: position, preferredTimescale: 600)) { _ in
                                if autoPlay { self.resume() }
                            }
                            self.currentTime = position
                        } else {
                            if autoPlay { self.resume() }
                        }
                        self.updateNowPlaying(track: track, duration: dur)
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
        player.pause()
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
        player.pause()
        player.replaceCurrentItem(with: nil)
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
        // Periodic time observer
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] time in
            guard let self else { return }
            
            // Do not advance the slider if the player is buffering or paused
            guard self.player.timeControlStatus == .playing else { return }
            
            let seconds = time.seconds
            guard seconds.isFinite else { return }
            self.currentTime = seconds
            self.playerStore?.position = seconds
            if let dur = self.player.currentItem?.duration.seconds, dur.isFinite, dur > 0 {
                self.duration = dur
            }
        }

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
        player.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self else { return }
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
            .store(in: &cancellables)

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

    private func handleEnded() {
        guard let store = playerStore else { return }
        if store.repeatMode == "one" {
            seek(to: 0)
            player.play()
            isPlaying = true
            store.isPlaying = true
            return
        }
        let hasNext = store.playNext()
        if hasNext, let next = store.currentTrack {
            play(track: next)
        } else {
            // Queue ended — stop playback
            isPlaying = false
            store.isPlaying = false
            currentTime = 0
            updateNowPlayingPlaybackState()
        }
    }

    private func handlePlaybackError() {
        guard let store = playerStore, let current = store.currentTrack else { return }
        
        // Retry playing the same track after a brief delay
        let lastPosition = currentTime
        let retryTrackId = current.id
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self, self.currentTrackId == retryTrackId else { return }
            print("Retrying playback for \(retryTrackId) at \(lastPosition)")
            
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
            guard let self, let store = self.playerStore else { return .commandFailed }
            let hasNext = store.playNext()
            if hasNext, let track = store.currentTrack {
                self.play(track: track)
            } else {
                self.stop()
            }
            return .success
        }

        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            guard let self, let store = self.playerStore else { return .commandFailed }
            store.playPrev()
            if let track = store.currentTrack {
                self.play(track: track)
            }
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

    private func createAsset(for track: Track) -> AVURLAsset {
        guard let api else { return AVURLAsset(url: URL(string: "about:blank")!) }
        let url = api.streamURL(for: track.id)
        if let localURL = AudioCacheService.shared.localURL(for: track.id) {
            print("Playing from cache: \(track.id)")
            return AVURLAsset(url: localURL)
        } else {
            print("Streaming and caching: \(track.id)")
            let headers = ["Authorization": "Bearer \(apiToken)"]
            AudioCacheService.shared.cacheTrack(id: track.id, remoteURL: url, token: apiToken)
            return AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        }
    }
    func downloadTrack(_ track: Track) {
        guard let api else { return }
        let url = api.streamURL(for: track.id)
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
    
    private let maxCacheSize: UInt64 = 500 * 1024 * 1024 // 500 MB
    
    private var downloadTasks: [String: Task<Void, Never>] = [:]
    private let queue = DispatchQueue(label: "com.musicplay.audiocache")
    
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
    }
    
    private func cleanUpCacheIfNeeded() {
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
