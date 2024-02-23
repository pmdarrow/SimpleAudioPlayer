import AVFoundation
import Foundation

extension AVAudioFile {
    var duration: TimeInterval {
        let sampleRateSong = Double(processingFormat.sampleRate)
        let lengthSongSeconds = Double(length) / sampleRateSong
        return lengthSongSeconds
    }
}

extension AVAudioPlayerNode {
    var currentPositon: TimeInterval {
        if let lastRenderTime, let playerTime = playerTime(forNodeTime: lastRenderTime) {
            let currentPlayPosition = Double(playerTime.sampleTime) / playerTime.sampleRate
            // currentPlayPosition is the current play position in seconds
            return currentPlayPosition
        }
        return 0
    }
}

class AudioPlayer: ObservableObject {
    private var audioEngine: AVAudioEngine
    private var audioPlayerNode: AVAudioPlayerNode
    private var audioFile: AVAudioFile?
    private var isLocalFile: Bool = true
    private var updatePositionTimer: Timer?

    @Published var songDuration: TimeInterval = 100
    @Published var currentPosition: TimeInterval = 0

    public var outputDeviceID: AudioDeviceID {
        get {
            UserDefaults.standard.object(forKey: "outputDeviceID") as? AudioDeviceID ?? AudioUtils
                .getDefaultOutputDevice()
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "outputDeviceID")
            setOutputDevice(deviceID: newValue)
        }
    }

    init() {
        audioEngine = AVAudioEngine()
        audioPlayerNode = AVAudioPlayerNode()
        audioEngine.attach(audioPlayerNode)
        setOutputDevice(deviceID: outputDeviceID)
    }

    func setOutputDevice(deviceID: AudioDeviceID) {
        // Attempt to access the Audio Unit of the engine's output node.
        // The audioUnit property is optional, hence the use of guard let to safely unwrap.
        guard let outputNodeAudioUnit = audioEngine.outputNode.audioUnit else {
            print("Unable to get audio unit from input node")
            return
        }

        // Attempt to set a property on an Audio Unit.
        var deviceID = deviceID
        let status = AudioUnitSetProperty(
            outputNodeAudioUnit, // The audio unit instance on which the property is to be set.
            kAudioOutputUnitProperty_CurrentDevice, // The property identifier specifying the current output device.
            kAudioUnitScope_Global, // The scope of the property. Global scope affects the audio unit as a whole.
            0, // The element ID. A value of 0 typically refers to the master element in Audio Unit contexts.
            &deviceID, // A pointer to the value that we want to set the property to. In this case, the desired output device ID.
            UInt32(MemoryLayout<AudioDeviceID>.size) // The size of the data pointed to by the previous parameter. This ensures the function knows how much memory to read.
        )

        // Check the status returned by AudioUnitSetProperty to determine if the operation was successful.
        if status != noErr {
            print("Error setting audio unit property: \(status)")
        }
    }

    func loadFile(url: URL) {
        isLocalFile = url.isFileURL
        do {
            audioFile = try AVAudioFile(forReading: url)
        } catch {
            print("Error loading audio file: \(error)")
        }

        guard let audioFile else { return }
        songDuration = audioFile.duration
        audioEngine.connect(audioPlayerNode, to: audioEngine.mainMixerNode, format: audioFile.processingFormat)
    }

    func play() {
        guard let audioFile, audioEngine.isRunning == true else {
            do {
                try audioEngine.start()
                play()
            } catch {
                print("Error starting audio engine: \(error)")
            }
            return
        }

        audioPlayerNode.stop()
        audioPlayerNode.scheduleFile(audioFile, at: nil) {
            print("Completion callback!")
        }
        audioPlayerNode.play()
        currentPosition = audioPlayerNode.currentPositon
        updatePositionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            // Update the currentPositon with the actual playback position from AVAudioPlayerNode
            guard let strongSelf = self else { return }
            strongSelf.currentPosition = strongSelf.audioPlayerNode.currentPositon
        }
    }

    func play(url: URL) {
        loadFile(url: url)
        play()
    }

    func pause() {
        audioPlayerNode.pause()
        updatePositionTimer?.invalidate()
        updatePositionTimer = nil
    }
}
