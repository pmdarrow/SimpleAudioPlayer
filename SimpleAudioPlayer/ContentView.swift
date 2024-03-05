import AudioKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject private var audioManager: AudioManager

    @State private var selectedSong: Song?
    @State private var isAnimating = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack {
            List(audioManager.queue, id: \.self, selection: $selectedSong) { song in
                HStack {
                    Text(song.title)
                        .lineLimit(1)

                    Spacer()

                    if audioManager.songPlaying == song, audioManager.isPlaying {
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
                    print("Double click detected on \(song)")
                    audioManager.play(song)
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
            audioManager.addSongs(panel.urls)
        }
    }

    func removeSelectedSong() {
        guard let selectedSong else { return }
        audioManager.removeSong(selectedSong)
    }
}

#Preview {
    ContentView(AudioManager())
}
