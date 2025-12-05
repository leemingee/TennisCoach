# TennisCoach

An iOS app for recording tennis videos and getting AI-powered analysis using Google Gemini.

## Features

### Core Features
- **Video Recording**: Record tennis practice/match videos with 60fps support
- **AI Analysis**: Get professional-level tennis technique analysis powered by Gemini
- **Interactive Chat**: Ask follow-up questions about your technique
- **Video Management**: Browse and manage recorded videos
- **Secure API Key Storage**: API keys stored securely in iOS Keychain

### Video Playback (v1.1)
- **In-App Video Player**: Play recorded videos directly within the app
- **Full-Screen Playback**: Tap to expand videos to full screen with native controls
- **Save to Photos**: Export videos to iPhone Photos Library for backup and sharing
- **Auto-Save Option**: Videos automatically saved to Photos Library after recording

### Camera Improvements (v1.1)
- **Smart Initialization**: Loading indicator during camera setup
- **Session Management**: Camera automatically resumes when returning to Recording tab
- **State Indicators**: Clear visual feedback for camera status (initializing, ready, recording, error)
- **Error Recovery**: Retry button when camera initialization fails

### Settings & About (v1.1)
- **Developer Contact**: Email link for support
- **GitHub Repository**: Direct link to source code
- **Contribution Info**: Open source contribution invitation

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Google AI Studio API Key (Gemini)

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/leemingee/TennisCoach.git
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
4. Tap "Test Connection" to verify

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
│   ├── GeminiService.swift       # Gemini API integration with retry logic
│   ├── VideoRecorder.swift       # AVFoundation video recording
│   ├── VideoCompressor.swift     # Video compression for upload
│   └── Prompts.swift             # AI analysis prompts (Chinese)
├── Views/
│   ├── Recording/
│   │   ├── RecordView.swift      # Camera preview and controls
│   │   └── RecordViewModel.swift # Recording state management
│   ├── VideoList/
│   │   └── VideoListView.swift   # Video gallery grid
│   ├── VideoPlayer/
│   │   └── VideoPlayerView.swift # Video playback components
│   └── Chat/
│       ├── ChatView.swift        # AI chat interface
│       └── ChatViewModel.swift   # Chat state and API calls
└── Utilities/
    ├── Constants.swift           # App constants & API config
    ├── SecureKeyManager.swift    # Keychain API key storage
    ├── APIKeySetupView.swift     # API key configuration UI
    ├── APIKeyValidator.swift     # API key validation
    ├── RetryPolicy.swift         # Network retry logic
    └── AppLogger.swift           # Structured logging (OSLog)

TennisCoachTests/
├── RecordViewModelTests.swift
├── VideoRecorderTests.swift
├── GeminiServiceTests.swift
├── SecureKeyManagerTests.swift
├── RetryPolicyTests.swift
└── ...
```

## Architecture

### Design Patterns
- **MVVM Pattern**: Clear separation of Views, ViewModels, and Models
- **Protocol-Oriented**: Services use protocols for testability and dependency injection
- **Async/Await**: Modern Swift concurrency throughout (no completion handlers)
- **Combine**: Reactive state management with @Published properties

### Data Persistence
- **SwiftData**: Conversation history, messages, video metadata
- **Photos Library**: Video files (optional, user-controlled export)
- **Keychain**: Secure API key storage (encrypted, device-only)
- **FileManager**: Video files in app Documents directory

### Service Layer
- **VideoRecorder**: AVFoundation-based recording with 60fps, session state management
- **GeminiService**: Streaming API integration with exponential backoff retry
- **VideoCompressor**: H.264 compression for efficient uploads

## Key Features Implementation

### Video Recording
- Uses AVFoundation for high-quality 60fps video capture
- Automatic thumbnail generation from first frame
- Camera state machine: initializing → ready → recording → processing
- Session pause/resume for tab switching

### Video Playback
- AVKit-based VideoPlayer with native controls
- Full-screen expansion with dismiss gesture
- Photos Library integration via PHPhotoLibrary
- Thumbnail caching for smooth scrolling

### AI Analysis
- Streaming responses via AsyncThrowingStream for real-time feedback
- Exponential backoff retry logic (up to 5 attempts)
- Progress tracking for video uploads (0-100%)
- Conversation history maintained per video

### Security
- API keys stored in iOS Keychain (not in code or UserDefaults)
- Keys are device-only, not backed up to iCloud
- Connection validation before use
- No sensitive data logged

## Privacy & Permissions

The app requests the following iOS permissions:

### Camera Access (Required)
- **Purpose**: Record tennis practice and match videos
- **When Requested**: First time opening Recording tab
- **If Denied**: Camera preview shows error with instructions

### Microphone Access (Required)
- **Purpose**: Capture audio during video recording
- **When Requested**: First time opening Recording tab
- **If Denied**: Videos record without audio

### Photo Library Access (Optional)
- **Purpose**: Save recorded videos to Photos app
- **Permission Type**: "Add Photos Only" (limited access)
- **When Requested**: When tapping "Save to Photos" button
- **If Denied**: Videos remain in app, viewable within TennisCoach

### Managing Permissions

If you need to change permissions:
1. Open iOS **Settings** app
2. Scroll to **TennisCoach**
3. Toggle permissions as needed
4. Return to app and retry the action

## Testing

Run tests using `Cmd + U` or via Product → Test.

```bash
# Run tests from command line
xcodebuild test -scheme TennisCoach -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Documentation

- `DESIGN.md` - Detailed design document (Chinese)
- `ARCHITECTURE_REVIEW.md` - Storage architecture recommendations
- `working_docs/` - Iteration planning and code review findings
- `best-practice/` - iOS development guidelines
- `Documentation/` - Additional docs and examples

## Troubleshooting

### Camera Shows Black Screen
1. Check camera permission in Settings → TennisCoach
2. Close and reopen the app
3. Tap "Retry" button if shown

### "API Key Invalid" Error
1. Verify your API key at [Google AI Studio](https://aistudio.google.com/apikey)
2. Re-enter the key in Settings tab
3. Tap "Test Connection" to verify

### Video Upload Fails
1. Check internet connection
2. Ensure video file is under 100MB
3. Try again - the app has automatic retry logic

### Videos Not in Photos App
1. Tap the video thumbnail in ChatView
2. Tap "Save to Photos" button
3. Grant photo library permission if prompted

## Contributing

Contributions welcome!

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Please read the design document and code review findings before submitting PRs.

## Contact

- **Email**: leemingee1995@gmail.com
- **GitHub**: [TennisCoach Repository](https://github.com/leemingee/TennisCoach)

## License

This project is for personal/educational use.
