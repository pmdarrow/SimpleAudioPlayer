import SwiftUI

@main
struct SimpleAudioPlayerApp: App {
    @StateObject var audioPlayer = AudioPlayer()

    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(audioPlayer)
        }
        Settings {
            PreferencesView().environmentObject(audioPlayer)
        }
    }
}
