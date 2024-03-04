import AudioKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject private var audioManager: AudioManager

    @State private var audioQueue: [URL] = []
    @State private var selectedSong: URL?
    @State private var isAnimating = false
    @FocusState private var focused: Bool

    let queueKey = "audioQueue"

    var body: some View {
        VStack {
            List(audioQueue, id: \.self, selection: $selectedSong) { url in
                HStack {
                    Text(url.lastPathComponent)
                        .lineLimit(1)

                    Spacer()

                    if audioManager.songPlaying == url, audioManager.isPlaying {
                        Circle()
                            .frame(width: 10, height: 10)
                            .foregroundColor(.green)
                            .scaleEffect(isAnimating ? 1.0 : 1.2)
                            .opacity(isAnimating ? 1.0 : 0.25)
                            .onAppear {
                                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                                    isAnimating.toggle() // Trigger the animation when the view appears
                                }
                            }
                    }
                }
                .contentShape(Rectangle())
                .onDoubleClick {
                    print("Double click detected on \(url)")
                    audioManager.play(url)
                }
            }

            VStack {
                HStack {
                    HStack(spacing: 8) {
                        Button(action: addSong) {
                            Image(systemName: "plus")
                        }
                        Button(action: removeSelectedSong) {
                            Image(systemName: "minus")
                        }
                    }.padding(.trailing, 10)

                    Button(action: {
                        print("Play/pause clicked, isPlaying: \(audioManager.isPlaying)")
                        if audioManager.isPlaying {
                            audioManager.pause()
                        } else {
                            audioManager.play(nil)
                        }
                    }) {
                        Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                    }

                    HStack {
                        Text(formatTimeInterval(audioManager.currentTime)).frame(width: 35, alignment: .trailing)
                        Slider(
                            value: $audioManager.currentTime,
                            in: 0 ... audioManager.currentSongDuration,
                            onEditingChanged: { editing in
                                if !editing {
                                    print("Seeking to \(audioManager.currentTime)")
                                    audioManager.seek(audioManager.currentTime)
                                }
                            }
                        )
                        Text(formatTimeInterval(audioManager.currentSongDuration)).frame(width: 35, alignment: .leading)
                    }
                }

            }.padding([.bottom, .leading, .trailing]).padding(.top, 8)
        }
        .focusable()
        .focused($focused)
        .onKeyPress(.space, phases: .down) { _ in
            print("Space pressed")
            DispatchQueue.main.async {
                if audioManager.isPlaying {
                    audioManager.pause()
                } else {
                    audioManager.play(nil)
                }
            }
            return .handled
        }
        .onAppear {
            loadQueue()
            focused = true
        }.preferredColorScheme(.dark).frame(minWidth: 300, idealWidth: 300, minHeight: 150, idealHeight: 150)
    }

    init(_ audioManager: AudioManager) {
        self.audioManager = audioManager
    }

    func formatTimeInterval(_ interval: TimeInterval) -> String {
        let interval = round(interval)
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    func addSong() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [UTType.mp3, UTType.wav, UTType.mpeg4Audio]

        if panel.runModal() == .OK {
            audioQueue.append(contentsOf: panel.urls)
            saveQueue()
        }
    }

    func removeSelectedSong() {
        guard let url = selectedSong, let index = audioQueue.firstIndex(of: url) else { return }
        audioQueue.remove(at: index)
        selectedSong = audioQueue.isEmpty ? nil : audioQueue[min(index, audioQueue.count - 1)]
        saveQueue()
    }

    func loadQueue() {
        if let savedQueue = UserDefaults.standard.stringArray(forKey: queueKey) {
            audioQueue = savedQueue.compactMap { URL(string: $0) }
        }
    }

    func saveQueue() {
        let stringArray = audioQueue.map(\.absoluteString)
        UserDefaults.standard.set(stringArray, forKey: queueKey)
    }
}

#Preview {
    ContentView(AudioManager())
}
