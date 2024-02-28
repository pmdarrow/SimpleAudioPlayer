import CoreAudio
import Foundation

public enum AudioUtils {
    // Most functions below from https://gist.github.com/rlxone/584467a63ac0ddf4d62fe1a983b42d0e

    static func getOutputDevices() -> [(AudioDeviceID, String)] {
        var result: [AudioDeviceID: String] = [:]
        let devices = getAllDevices()

        for device in devices {
            if isOutputDevice(deviceID: device) {
                result[device] = getDeviceName(deviceID: device)
            }
        }

        return result.sorted { $0.0 < $1.0 }
    }

    static func isOutputDevice(deviceID: AudioDeviceID) -> Bool {
        var propertySize: UInt32 = 256

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: AudioObjectPropertySelector(kAudioDevicePropertyStreams),
            mScope: AudioObjectPropertyScope(kAudioDevicePropertyScopeOutput),
            mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMain)
        )

        _ = AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &propertySize)

        return propertySize > 0
    }

    static func getDefaultOutputDevice() -> AudioDeviceID {
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var deviceID = kAudioDeviceUnknown

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: AudioObjectPropertySelector(kAudioHardwarePropertyDefaultOutputDevice),
            mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
            mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMain)
        )

        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceID
        )

        return deviceID
    }

    static func getNumberOfDevices() -> UInt32 {
        var propertySize: UInt32 = 0

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: AudioObjectPropertySelector(kAudioHardwarePropertyDevices),
            mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
            mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMain)
        )

        _ = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize
        )

        return propertySize / UInt32(MemoryLayout<AudioDeviceID>.size)
    }

    static func getDeviceName(deviceID: AudioDeviceID) -> String {
        var propertySize = UInt32(MemoryLayout<CFString>.size)

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: AudioObjectPropertySelector(kAudioDevicePropertyDeviceNameCFString),
            mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
            mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMain)
        )

        var result: CFString = "" as CFString

        AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &propertySize, &result)

        return result as String
    }

    static func getAllDevices() -> [AudioDeviceID] {
        let devicesCount = getNumberOfDevices()
        var devices = [AudioDeviceID](repeating: 0, count: Int(devicesCount))

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: AudioObjectPropertySelector(kAudioHardwarePropertyDevices),
            mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
            mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMain)
        )

        var devicesSize = devicesCount * UInt32(MemoryLayout<UInt32>.size)

        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &devicesSize,
            &devices
        )

        return devices
    }
}
