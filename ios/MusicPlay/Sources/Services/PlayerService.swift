import Foundation
import AVFoundation
import MediaPlayer
import Combine

final class PlayerService: ObservableObject {
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var isPlaying: Bool = false
    @Published var volume: Float = 1.0

    private let player = AVPlayer()
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()

    private var api: APIClient?
    private weak var playerStore: PlayerStore?

    func configure(api: APIClient, playerStore: PlayerStore) {
        self.api = api
        self.playerStore = playerStore
        setupAudioSession()
        setupObservers()
        setupRemoteCommands()
    }

    func play(track: Track) {
        guard let api else { return }
        let url = api.streamURL(for: track.id)
        let headers = ["Authorization": "Bearer \(apiToken)"]
        let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        let item = AVPlayerItem(asset: asset)
        player.replaceCurrentItem(with: item)
        player.play()
        isPlaying = true
        playerStore?.isPlaying = true
        updateNowPlaying(track: track)
    }

    func pause() {
        player.pause()
        isPlaying = false
        playerStore?.isPlaying = false
        updateNowPlayingPlaybackState()
    }

    func resume() {
        if player.currentItem == nil, let track = playerStore?.currentTrack {
            play(track: track)
            return
        }
        player.play()
        isPlaying = true
        playerStore?.isPlaying = true
        updateNowPlayingPlaybackState()
    }

    func seek(to time: Double) {
        player.seek(to: CMTime(seconds: time, preferredTimescale: 600))
    }

    func setVolume(_ value: Float) {
        volume = value
        player.volume = value
    }

    private var apiToken: String {
        api?.accessToken ?? ""
    }

    private func setupObservers() {
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.3, preferredTimescale: 600), queue: .main) { [weak self] time in
            guard let self else { return }
            self.currentTime = time.seconds
            self.playerStore?.position = time.seconds
            if let dur = self.player.currentItem?.duration.seconds, dur.isFinite {
                self.duration = dur
            }
            self.updateNowPlayingPlaybackState()
        }

        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
            .sink { [weak self] _ in
                self?.handleEnded()
            }
            .store(in: &cancellables)
    }

    private func handleEnded() {
        guard let store = playerStore else { return }
        if store.repeatMode == "one" {
            seek(to: 0)
            resume()
            return
        }
        store.playNext()
        if let next = store.currentTrack {
            play(track: next)
        }
    }

    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetooth])
        try? session.setActive(true)
    }

    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.resume()
            return .success
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.playerStore?.playNext()
            if let track = self?.playerStore?.currentTrack {
                self?.play(track: track)
            } else {
                self?.pause()
            }
            return .success
        }
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.playerStore?.playPrev()
            if let track = self?.playerStore?.currentTrack {
                self?.play(track: track)
            } else {
                self?.pause()
            }
            return .success
        }
    }

    private func updateNowPlaying(track: Track) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func updateNowPlayingPlaybackState() {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
