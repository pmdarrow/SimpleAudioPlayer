import AudioKit
import SwiftUI

@main
struct SimpleAudioPlayerApp: App {
    var audioManager = AudioManager()

    var body: some Scene {
        WindowGroup {
            ContentView(audioManager)
        }
        Settings {
            PreferencesView(audioManager)
        }
    }
}
