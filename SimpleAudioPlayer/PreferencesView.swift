import CoreAudio
import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject private var audioPlayer: AudioPlayer
    @State private var outputDevices: [(AudioDeviceID, String)] = []
    @State private var selectedDeviceID: AudioDeviceID = 0

    var body: some View {
        VStack {
            Text("Select Audio Output Device")
                .font(.headline)

            Picker("Output Device", selection: $selectedDeviceID) {
                ForEach(outputDevices, id: \.0) { device in
                    Text(device.1).tag(device.0)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .onAppear {
                outputDevices = AudioUtils.getOutputDevices()
                print("Available output devices: \(outputDevices)")
                selectedDeviceID = audioPlayer.outputDeviceID
            }

            Button("Apply") {
                audioPlayer.outputDeviceID = selectedDeviceID
                print("Saved selected device ID: \(selectedDeviceID)")
            }
        }
        .padding()
    }
}

#Preview {
    PreferencesView().environmentObject(AudioPlayer())
}
