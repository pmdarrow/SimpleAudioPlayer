import AudioKit
import Foundation

class AudioManager: ObservableObject {
    private var audioEngine: AudioEngine
    private let audioPlayer: AudioPlayer
    private var updatePositionTimer: Timer?

    @Published public var songPlaying: URL?
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
    }

    private func playbackCompletionHandler() {
        DispatchQueue.main.async {
            self.songPlaying = nil
            self.isPlaying = false
            self.stopUpdatingCurrentTime()
        }
    }

    public func play(_ url: URL?) {
        // Resume playback of existing song
        if url == nil {
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
            try audioPlayer.load(url: url!)
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
        songPlaying = url
        startUpdatingCurrentTime()
    }

    public func pause() {
        audioPlayer.pause()
        isPlaying = false
        songPlaying = nil
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

    public func loadDevice() {
        guard let deviceID = UserDefaults.standard.object(forKey: "savedDeviceID") as? DeviceID else {
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

    public func setDevice(device: Device) {
        UserDefaults.standard.set(device.deviceID, forKey: "savedDeviceID")
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
}
