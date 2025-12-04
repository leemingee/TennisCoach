# TennisCoach

An iOS app for recording tennis videos and getting AI-powered analysis using Google Gemini.

## Features

- **Video Recording**: Record tennis practice/match videos with 60fps support
- **AI Analysis**: Get professional-level tennis technique analysis powered by Gemini
- **Interactive Chat**: Ask follow-up questions about your technique
- **Video Management**: Browse and manage recorded videos
- **Secure API Key Storage**: API keys stored securely in iOS Keychain

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Google AI Studio API Key (Gemini)

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/TennisCoach.git
cd TennisCoach
```

### 2. Open in Xcode

```bash
open TennisCoach.xcodeproj
```

### 3. Build and Run

1. Select your target device or simulator
2. Press `Cmd + R` to build and run
3. On first launch, the app will prompt you to enter your Gemini API key

### 4. Get Your API Key

1. Visit [Google AI Studio](https://aistudio.google.com/apikey)
2. Create a new API key
3. Enter it in the app's Settings tab

## Project Structure

```
TennisCoach/
├── TennisCoachApp.swift          # App entry point
├── ContentView.swift             # Main TabView with Settings
├── Models/
│   ├── Video.swift               # Video entity (SwiftData)
│   ├── Conversation.swift        # Chat conversation entity
│   └── Message.swift             # Chat message entity
├── Services/
│   ├── GeminiService.swift       # Gemini API integration
│   ├── VideoRecorder.swift       # AVFoundation video recording
│   ├── VideoCompressor.swift     # Video compression
│   └── Prompts.swift             # AI analysis prompts
├── Views/
│   ├── Recording/
│   │   ├── RecordView.swift
│   │   └── RecordViewModel.swift
│   ├── VideoList/
│   │   └── VideoListView.swift
│   └── Chat/
│       ├── ChatView.swift
│       └── ChatViewModel.swift
└── Utilities/
    ├── Constants.swift           # App constants & API config
    ├── SecureKeyManager.swift    # Keychain API key storage
    ├── APIKeySetupView.swift     # API key configuration UI
    ├── APIKeyValidator.swift     # API key validation
    ├── RetryPolicy.swift         # Network retry logic
    └── AppLogger.swift           # Structured logging

TennisCoachTests/
├── RecordViewModelTests.swift
├── VideoRecorderTests.swift
├── GeminiServiceTests.swift
├── SecureKeyManagerTests.swift
├── RetryPolicyTests.swift
└── ...
```

## Architecture

- **MVVM Pattern**: Clear separation of Views, ViewModels, and Models
- **Protocol-Oriented**: Services use protocols for testability
- **SwiftData**: Modern persistence using Apple's SwiftData framework
- **Async/Await**: Modern Swift concurrency throughout
- **Keychain Security**: Secure storage for sensitive API keys

## Key Features Implementation

### Video Recording
- Uses AVFoundation for high-quality 60fps video capture
- Automatic thumbnail generation
- Background file management

### AI Analysis
- Streaming responses for real-time feedback
- Exponential backoff retry logic for reliability
- Progress tracking for video uploads

### Security
- API keys stored in iOS Keychain (not in code or UserDefaults)
- Keys are device-only, not backed up to iCloud
- Connection validation before use

## Testing

Run tests using `Cmd + U` or via Product → Test.

```bash
# Run tests from command line
xcodebuild test -scheme TennisCoach -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Documentation

- `DESIGN.md` - Detailed design document
- `best-practice/` - Development guidelines
- `Documentation/` - Additional docs and examples

## Privacy

The app requires the following permissions:
- **Camera**: To record tennis practice videos
- **Microphone**: To capture audio with videos
- **Photo Library**: To save and access videos

## License

This project is for personal/educational use.

## Contributing

Contributions welcome! Please read the design document before submitting PRs.
