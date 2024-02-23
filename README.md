# Simple Audio Player

Simple Audio Player is a minimalistic audio player application built with SwiftUI for macOS. 

I wanted a super lightweight open source audio player for local audio files that could run on a severely resource constrained machine. It needed to support selecting the output device and crossfading. Nothing really fit the bill so I built one myself.

## Features

- Add and remove songs to a playback queue (supports `.mp3`, `.wav`, and `.m4a` formats)
- Play, pause, and seek functionality
- Display current and total playback time
- Select an audio output device
- Persist queue across app restarts
- Minimalistic user interface

## Installation

Clone the repository to your local machine:

```bash
git clone https://github.com/pmdarrow/SimpleAudioPlayer.git
```

Navigate to the project directory:

```bash
cd SimpleAudioPlayer
```

Open the project in Xcode:

```bash
open SimpleAudioPlayer.xcodeproj
```

Build and run the application using Xcode.

## Contributing

Contributions are welcome! Please feel free to submit a pull request or create an issue for any bugs or feature requests.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
