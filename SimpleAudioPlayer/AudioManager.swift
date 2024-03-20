import AudioKit
import Foundation

struct Song: Identifiable, Hashable {
    let id: UUID = .init()
    let url: URL

    var title: String {
        url.lastPathComponent
    }
}

class AudioManager: ObservableObject {
    private var audioEngine: AudioEngine
    private let mixer: Mixer
    private var prevAudioPlayer: AudioPlayer?
    private var currentAudioPlayer: AudioPlayer?

    private var prevFadeTimer: Timer? = nil
    private var currentFadeTimer: Timer? = nil
    private var updatePositionTimer: Timer?

    private let queueKey = "audioQueue"
    private let savedDeviceKey = "savedDeviceID"
    private let crossfadeDuration = 5.0

    @Published public var queue: [Song] = []
    @Published public var isPlaying: Bool = false
    @Published public var currentSong: Song?
    @Published public var currentTime = TimeInterval(0)

    public var outputDevices: [Device] {
        AudioEngine.outputDevices
    }

    public var currentDevice: Device {
        audioEngine.device
    }

    public var currentSongDuration: TimeInterval {
        currentAudioPlayer?.duration ?? 0
    }

    public var firstSong: Song? {
        queue.first
    }

    public var nextSong: Song? {
        guard let currentSong else {
            print("Can't determine next song - no song currently playing.")
            return nil
        }

        guard let currentIndex = queue.firstIndex(of: currentSong) else {
            print("Can't determine next song - couldn't find current song in queue.")
            return nil
        }

        let nextIndex = currentIndex + 1
        guard queue.indices.contains(nextIndex) else {
            // There is no next song in the queue
            return nil
        }

        return queue[nextIndex]
    }

    public init() {
        mixer = Mixer()
        audioEngine = AudioEngine()
        audioEngine.output = mixer
        loadDevice()
        loadQueue()
    }

    public func terminate() {
        print("Terminating")
        prevAudioPlayer?.stop()
        currentAudioPlayer?.stop()
        audioEngine.stop()
    }

    private func songCompletionHandler() {
        DispatchQueue.main.async {
            print("Song completed.")
            if let currentAudioPlayer = self.currentAudioPlayer, !currentAudioPlayer.isPlaying {
                self.currentSong = nil
                self.isPlaying = false
                self.stopUpdatingCurrentTime()
            }
        }
    }

    public func play(_ song: Song) {
        let audioPlayer = AudioPlayer()
        audioPlayer.completionHandler = songCompletionHandler
        mixer.addInput(audioPlayer)

        do {
            try audioPlayer.load(url: song.url)
        } catch {
            print("Error loading file: \(error)")
        }

        do {
            try audioEngine.start()
        } catch {
            print("Error starting audio engine: \(error)")
            return
        }

        if isPlaying {
            print("Crossfading into next song...")
            audioPlayer.volume = 0
            prevAudioPlayer = currentAudioPlayer
            if let prevAudioPlayer {
                prevFadeTimer = fade(audioPlayer: prevAudioPlayer, targetVolume: 0, duration: crossfadeDuration)
                currentFadeTimer = fade(audioPlayer: audioPlayer, targetVolume: 1, duration: crossfadeDuration)
            }
        }

        stopUpdatingCurrentTime()
        audioPlayer.play()
        isPlaying = true
        currentAudioPlayer = audioPlayer
        currentSong = song
        startUpdatingCurrentTime()
    }

    public func pause() {
        prevAudioPlayer?.pause()
        currentAudioPlayer?.pause()
        isPlaying = false
        stopUpdatingCurrentTime()
    }

    public func resume() {
        if currentSong == nil {
            print("Nothing to resume, aborting")
        } else {
            print("Resuming playback")
            prevAudioPlayer?.resume()
            currentAudioPlayer?.resume()
            isPlaying = true
            startUpdatingCurrentTime()
        }
    }

    public func seek(_ time: TimeInterval) {
        if let currentAudioPlayer {
            currentAudioPlayer.seek(time: time - currentAudioPlayer.currentTime)
        }
    }

    private func fade(audioPlayer: AudioPlayer, targetVolume: AUValue, duration: TimeInterval) -> Timer {
        let totalChangeInVolume = targetVolume - audioPlayer.volume
        let steps = Int(duration * 10)
        let timeInterval = duration / Double(steps)
        let volumeChangePerStep = totalChangeInVolume / Float(steps)
        var currentStep = 0

        let fadeTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: true) { timer in
            if currentStep < steps {
                audioPlayer.volume += volumeChangePerStep
                currentStep += 1
            } else {
                print("Fade complete")
                timer.invalidate()
                audioPlayer.volume = targetVolume // Ensure final volume is exactly as intended
            }
        }
        return fadeTimer
    }

    private func startUpdatingCurrentTime() {
        guard let currentAudioPlayer else { return }
        currentTime = currentAudioPlayer.currentTime
        updatePositionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                self.currentTime = currentAudioPlayer.currentTime
                let remainingTime = self.currentSongDuration - self.currentTime
                if remainingTime <= self.crossfadeDuration, let nextSong = self.nextSong {
                    self.play(nextSong)
                }
            }
        }
    }

    private func stopUpdatingCurrentTime() {
        print("Stopped updating current time")
        updatePositionTimer?.invalidate()
        updatePositionTimer = nil
    }

    public func setDevice(device: Device) {
        UserDefaults.standard.set(device.deviceID, forKey: savedDeviceKey)
        do {
            print("Setting device to \(device)")
            isPlaying = false
            currentSong = nil
            audioEngine.stop()
            prevAudioPlayer?.stop()
            currentAudioPlayer?.stop()
            try audioEngine.setDevice(device)
        } catch {
            print("Error changing output device: \(error)")
        }
    }

    public func loadDevice() {
        guard let deviceID = UserDefaults.standard.object(forKey: savedDeviceKey) as? DeviceID else {
            print("No saved device found, using system default")
            return
        }
        guard let outputDevice = AudioEngine.devices.first(where: { $0.deviceID == deviceID }) else {
            print("Saved device no longer valid, using system default")
            return
        }

        do {
            print("Setting device to \(outputDevice)")
            try audioEngine.setDevice(outputDevice)
        } catch {
            print("Error setting output device: \(error)")
        }
    }

    public func loadQueue() {
        if let urlStrings = UserDefaults.standard.stringArray(forKey: queueKey) {
            queue = urlStrings.compactMap { urlString in
                guard let url = URL(string: urlString) else { return nil }
                return Song(url: url)
            }
        }
    }

    public func saveQueue() {
        let urlStrings = queue.map(\.url.absoluteString)
        UserDefaults.standard.set(urlStrings, forKey: queueKey)
    }

    public func addSongs(_ urls: [URL]) {
        let newSongs = urls.map { Song(url: $0) }
        queue.append(contentsOf: newSongs)
        saveQueue()
    }

    public func removeSong(_ song: Song) {
        guard let index = queue.firstIndex(of: song) else { return }
        queue.remove(at: index)
        saveQueue()
    }
}
