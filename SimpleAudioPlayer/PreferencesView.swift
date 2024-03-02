import AudioKit
import SwiftUI

struct PreferencesView: View {
    private var audioManager: AudioManager
    @State private var selectedDevice: Device

    var body: some View {
        VStack {
            Text("Select Audio Output Device")
                .font(.headline)

            Picker("Output Device:", selection: $selectedDevice) {
                ForEach(audioManager.outputDevices, id: \.self) { device in
                    Text(device.name).tag(device as Device?)
                }
            }
            .onChange(of: selectedDevice) {
                audioManager.setDevice(device: selectedDevice)
            }
        }
        .padding()
    }

    init(_ audioManager: AudioManager) {
        self.audioManager = audioManager
        selectedDevice = audioManager.currentDevice
    }
}

#Preview {
    PreferencesView(AudioManager())
}
