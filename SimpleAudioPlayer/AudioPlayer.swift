import AVFoundation
import Foundation

extension AVAudioFile {
    var duration: TimeInterval {
        let sampleRateSong = Double(processingFormat.sampleRate)
        let lengthSongSeconds = Double(length) / sampleRateSong
        return lengthSongSeconds
    }
}

class AudioPlayer: ObservableObject {
    private var audioEngine: AVAudioEngine
    private var audioPlayerNode: AVAudioPlayerNode
    private var audioFile: AVAudioFile?
    private var updatePositionTimer: Timer?
    private var seekBaseTime: TimeInterval = 0

    @Published var songDuration: TimeInterval = 0
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

    public init() {
        audioEngine = AVAudioEngine()
        audioPlayerNode = AVAudioPlayerNode()
        audioEngine.attach(audioPlayerNode)
        setOutputDevice(deviceID: outputDeviceID)
    }

    public func setOutputDevice(deviceID: AudioDeviceID) {
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

    public func loadFile(url: URL) {
        do {
            audioFile = try AVAudioFile(forReading: url)
        } catch {
            print("Error loading audio file: \(error)")
        }

        guard let audioFile else { return }
        songDuration = audioFile.duration
        audioEngine.connect(audioPlayerNode, to: audioEngine.mainMixerNode, format: audioFile.processingFormat)
    }

    private func updateCurrentPosition() {
        guard let audioFile else { return }

        let sampleRate = audioFile.processingFormat.sampleRate
        let nodeTime: AVAudioTime? = audioPlayerNode.lastRenderTime
        let playerTime: AVAudioTime? = audioPlayerNode.playerTime(forNodeTime: nodeTime!)

        if let playerTime {
            let currentFrame = playerTime.sampleTime
            let currentRelativePositionInSeconds = Double(currentFrame) / sampleRate
            currentPosition = seekBaseTime + currentRelativePositionInSeconds
        }
    }

    private func playbackCompletionCallback(callbackType: AVAudioPlayerNodeCompletionCallbackType) {
        print("Playback completion callback")
        switch callbackType {
        case .dataConsumed:
            print("Data consumed")
        case .dataRendered:
            print("Data rendered")
        case .dataPlayedBack:
            print("Data played back")
        @unknown default:
            print("Unknown completion callback type")
        }
        print("Current position \(currentPosition), song duration \(songDuration)")
    }

    public func play(url: URL?) {
        // Resume playback of existing song
        guard let url else {
            audioPlayerNode.play()
            return
        }

        // Play a new song
        loadFile(url: url)
        seekBaseTime = 0

        do {
            try audioEngine.start()
        } catch {
            print("Error starting audio engine: \(error)")
            return
        }
        guard let audioFile, audioEngine.isRunning == true else {
            print("Audio engine not started, or audio file missing.")
            return
        }

        audioPlayerNode.scheduleFile(audioFile, at: nil, completionCallbackType: .dataPlayedBack, completionHandler: playbackCompletionCallback)
        audioPlayerNode.play()
        updateCurrentPosition()

        // Update the observable playback position every second
        updatePositionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.updateCurrentPosition()
        }
    }

    public func pause() {
        audioPlayerNode.pause()
    }

    public func seek(to: TimeInterval) {
        guard let audioFile else { return }

        let sampleRate = audioFile.processingFormat.sampleRate

        // Calculate the starting frame by multiplying the desired time in seconds by the sample rate.
        // This determines the frame in the audio file where playback will begin.
        let startingFrame = AVAudioFramePosition(to * sampleRate)

        // Calculate the number of frames to play. This is the difference between the total length of the audio file
        // and the starting frame. It ensures playback continues from the desired start point to the end of the file.
        let frameCount = AVAudioFrameCount(audioFile.length - startingFrame)

        audioPlayerNode.stop() // Stop if it was playing

        // Schedule the playback of a segment of the audio file. This is where the "seeking" happens.
        // - `audioFile`: The audio file to play.
        // - `startingFrame`: The frame at which to start playback, calculated based on the desired seek time.
        // - `frameCount`: The total number of frames to play from the starting frame, effectively determining
        //   the duration of the playback segment.
        // - `at: nil`: Specifies when the playback should start. Passing nil means playback starts immediately.
        // - Completion handler: An optional closure that is called when the playback of the segment finishes.
        audioPlayerNode.scheduleSegment(audioFile, startingFrame: startingFrame, frameCount: frameCount, at: nil, completionCallbackType: .dataPlayedBack, completionHandler: playbackCompletionCallback)

        seekBaseTime = to // Update the base time with the seek position

        audioPlayerNode.play() // Resume playback
    }
}
