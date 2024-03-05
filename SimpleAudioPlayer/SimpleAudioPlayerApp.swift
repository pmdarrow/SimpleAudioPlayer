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

    init() {
        setupTerminationObserver()
    }

    func setupTerminationObserver() {
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: nil) { _ in
            audioManager.terminate()
        }
    }
}
