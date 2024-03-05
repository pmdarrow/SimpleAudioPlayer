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
    private let audioPlayer: AudioPlayer
    private var updatePositionTimer: Timer?
    private let queueKey = "audioQueue"
    private let savedDeviceKey = "savedDeviceID"

    @Published public var queue: [Song] = []
    @Published public var songPlaying: Song?
    @Published public var isPlaying: Bool = false
    @Published public var currentTime = TimeInterval(0)

    public var outputDevices: [Device] {
        AudioEngine.outputDevices
    }

    public var currentDevice: Device {
        audioEngine.device
    }

    public var currentSongDuration: TimeInterval {
        audioPlayer.duration
    }

    public init() {
        audioEngine = AudioEngine()
        audioPlayer = AudioPlayer()
        audioEngine.output = audioPlayer
        audioPlayer.completionHandler = playbackCompletionHandler
        loadDevice()
        loadQueue()
    }

    public func terminate() {
        print("Terminating")
        audioPlayer.stop()
        audioEngine.stop()
    }

    private func playbackCompletionHandler() {
        DispatchQueue.main.async {
            self.songPlaying = nil
            self.isPlaying = false
            self.stopUpdatingCurrentTime()
        }
    }

    public func play(_ song: Song?) {
        // Resume playback of existing song
        guard let song = song else {
            if songPlaying == nil {
                print("Nothing to play or resume, aborting")
            } else {
                print("Resuming playback")
                audioPlayer.resume()
                isPlaying = true
                startUpdatingCurrentTime()
            }
            return
        }

        // Otherwise, play a new song
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

        audioPlayer.play()
        isPlaying = true
        songPlaying = song
        startUpdatingCurrentTime()
    }

    public func pause() {
        audioPlayer.pause()
        isPlaying = false
        stopUpdatingCurrentTime()
    }

    public func seek(_ time: TimeInterval) {
        audioPlayer.seek(time: time - audioPlayer.currentTime)
    }

    private func startUpdatingCurrentTime() {
        currentTime = audioPlayer.currentTime
        updatePositionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                self.currentTime = self.audioPlayer.currentTime
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
            songPlaying = nil
            audioEngine.stop()
            audioPlayer.stop()
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
