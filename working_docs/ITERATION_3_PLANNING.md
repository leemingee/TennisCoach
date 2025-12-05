# TennisCoach Iteration 3 - HEVC Encoding & Playback Controls

> **Created:** 2025-12-04
> **Status:** Planned
> **Priority:** High
> **Estimated Effort:** 2-3 weeks

---

## Executive Summary

Iteration 3 focuses on two high-impact improvements:
1. **HEVC Encoding** - Quick win that doubles recording time (30s → 60s)
2. **Enhanced Playback Controls** - Critical for users to act on AI feedback

These features address the biggest gap in the current user experience: the **learning loop**. Users can record and get AI analysis, but cannot effectively review and learn from the feedback.

---

## Table of Contents

1. [Feature: HEVC Encoding](#feature-hevc-encoding)
2. [Feature: Enhanced Playback Controls](#feature-enhanced-playback-controls)
3. [Implementation Plan](#implementation-plan)
4. [Technical Specifications](#technical-specifications)
5. [Testing Checklist](#testing-checklist)

---

## Feature: HEVC Encoding

### Priority: P0 (Do First)
### Effort: 2-3 hours
### Impact: High (doubles recording time)

### Problem Statement

Current H.264 encoding produces ~175-200 MB/min at 60fps/1080p, limiting recordings to 30 seconds to stay under Gemini's 100MB upload limit.

### Solution

Switch to HEVC (H.265) codec which provides 40-50% file size reduction:
- H.264: ~175-200 MB/min → 30 second max
- HEVC: ~90-110 MB/min → 60 second max

### Device Support

| Device | HEVC Support |
|--------|--------------|
| iPhone 7+ (A10 chip) | ✅ Hardware accelerated |
| iPhone 6s (A9 chip) | ❌ Fallback to H.264 |
| iOS 11+ | ✅ Required |

### Implementation

#### 1. Add codec configuration to VideoRecorder.swift

```swift
// MARK: - Video Codec Configuration

/// Supported video codecs for recording
enum VideoCodec: String {
    case hevc = "HEVC"
    case h264 = "H.264"

    var avCodecType: AVVideoCodecType {
        switch self {
        case .hevc: return .hevc
        case .h264: return .h264
        }
    }

    /// Estimated MB per minute at 1080p/60fps
    var estimatedMBPerMinute: Double {
        switch self {
        case .hevc: return 100  // ~5 Mbps average
        case .h264: return 180  // ~9 Mbps average
        }
    }
}

/// Current codec being used
private(set) var activeCodec: VideoCodec = .h264

/// Check if HEVC is available on this device
var isHEVCSupported: Bool {
    movieOutput.availableVideoCodecTypes.contains(.hevc)
}

/// Configure video codec (call in configureSession after adding movieOutput)
private func configureVideoCodec() {
    guard let videoConnection = movieOutput.connection(with: .video) else {
        AppLogger.warning("No video connection for codec config", category: AppLogger.video)
        return
    }

    if movieOutput.availableVideoCodecTypes.contains(.hevc) {
        movieOutput.setOutputSettings(
            [AVVideoCodecKey: AVVideoCodecType.hevc],
            for: videoConnection
        )
        activeCodec = .hevc
        AppLogger.info("Using HEVC codec (~100MB/min)", category: AppLogger.video)
    } else {
        movieOutput.setOutputSettings(
            [AVVideoCodecKey: AVVideoCodecType.h264],
            for: videoConnection
        )
        activeCodec = .h264
        AppLogger.info("HEVC unavailable, using H.264 (~180MB/min)", category: AppLogger.video)
    }
}
```

#### 2. Update configureSession() in VideoRecorder.swift

```swift
// In configureSession(), after adding movieOutput:
if captureSession.canAddOutput(movieOutput) {
    captureSession.addOutput(movieOutput)

    // Configure HEVC codec (new line)
    configureVideoCodec()

    // Existing stabilization config...
    if let connection = movieOutput.connection(with: .video) {
        if connection.isVideoStabilizationSupported {
            connection.preferredVideoStabilizationMode = .auto
        }
    }
}
```

#### 3. Update Constants.swift for dynamic duration

```swift
enum Video {
    // Existing constants...

    /// Maximum recording duration based on codec
    static let maxDurationHEVC: TimeInterval = 60   // ~100MB at HEVC
    static let maxDurationH264: TimeInterval = 30   // ~90MB at H.264

    /// Get max duration for current codec
    static func maxDuration(for codec: VideoCodec) -> TimeInterval {
        switch codec {
        case .hevc: return maxDurationHEVC
        case .h264: return maxDurationH264
        }
    }
}
```

#### 4. Update RecordViewModel to use dynamic duration

```swift
/// Maximum recording duration based on available codec
var maxRecordingDuration: TimeInterval {
    guard let recorder = videoRecorder else {
        return Constants.Video.maxDuration  // Fallback
    }
    return Constants.Video.maxDuration(for: recorder.activeCodec)
}
```

### Gemini Compatibility

✅ Gemini File API fully supports HEVC video in MP4 container. No transcoding needed.

---

## Feature: Enhanced Playback Controls

### Priority: P1 (Critical for retention)
### Effort: 8-12 hours
### Impact: High (enables learning from AI feedback)

### Problem Statement

When Gemini says "Your backswing is too high at 0:12", users cannot:
1. Jump to that timestamp easily
2. Watch in slow motion to see the issue
3. Step through frame-by-frame to understand

This breaks the learning loop and makes AI feedback less actionable.

### Solution

Add professional-grade playback controls:
1. Variable speed playback (0.25x, 0.5x, 0.75x, 1x, 1.5x, 2x)
2. Frame-by-frame stepping (forward/backward)
3. Timestamp detection and tap-to-jump from AI analysis

### Implementation

#### 1. Create EnhancedVideoPlayerView.swift

```swift
import SwiftUI
import AVKit

struct EnhancedVideoPlayerView: View {
    let videoURL: URL
    @StateObject private var controller = VideoPlayerController()
    @State private var showControls = true

    var body: some View {
        ZStack {
            // Video layer
            VideoPlayerLayer(player: controller.player)
                .onTapGesture {
                    withAnimation { showControls.toggle() }
                }

            // Controls overlay
            if showControls {
                VStack {
                    Spacer()
                    PlaybackControlsView(controller: controller)
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            controller.loadVideo(url: videoURL)
        }
        .onDisappear {
            controller.pause()
        }
    }
}

// MARK: - Playback Controls

struct PlaybackControlsView: View {
    @ObservedObject var controller: VideoPlayerController

    var body: some View {
        VStack(spacing: 16) {
            // Progress bar with scrubbing
            VideoProgressBar(
                currentTime: controller.currentTime,
                duration: controller.duration,
                onSeek: { controller.seek(to: $0) }
            )

            HStack(spacing: 24) {
                // Frame step backward
                Button(action: { controller.stepBackward() }) {
                    Image(systemName: "backward.frame.fill")
                        .font(.title2)
                }

                // Play/Pause
                Button(action: { controller.togglePlayPause() }) {
                    Image(systemName: controller.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                }

                // Frame step forward
                Button(action: { controller.stepForward() }) {
                    Image(systemName: "forward.frame.fill")
                        .font(.title2)
                }

                Spacer()

                // Speed selector
                SpeedSelectorButton(
                    currentSpeed: controller.playbackSpeed,
                    onSelect: { controller.setSpeed($0) }
                )
            }
            .foregroundColor(.white)
            .padding()
        }
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: - Speed Selector

struct SpeedSelectorButton: View {
    let currentSpeed: Float
    let onSelect: (Float) -> Void

    @State private var showPicker = false

    private let speeds: [Float] = [0.25, 0.5, 0.75, 1.0, 1.5, 2.0]

    var body: some View {
        Button(action: { showPicker = true }) {
            Text(speedLabel)
                .font(.subheadline.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.white.opacity(0.2)))
        }
        .confirmationDialog("播放速度", isPresented: $showPicker) {
            ForEach(speeds, id: \.self) { speed in
                Button(formatSpeed(speed)) {
                    onSelect(speed)
                }
            }
        }
    }

    private var speedLabel: String {
        formatSpeed(currentSpeed)
    }

    private func formatSpeed(_ speed: Float) -> String {
        if speed == 1.0 { return "1x" }
        if speed < 1.0 { return String(format: "%.2gx", speed) }
        return String(format: "%.1gx", speed)
    }
}
```

#### 2. Create VideoPlayerController.swift

```swift
import AVFoundation
import Combine

@MainActor
final class VideoPlayerController: ObservableObject {
    @Published var player: AVPlayer?
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var playbackSpeed: Float = 1.0

    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()

    func loadVideo(url: URL) {
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)

        // Observe time
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            self?.currentTime = CMTimeGetSeconds(time)
        }

        // Get duration
        Task {
            if let duration = try? await playerItem.asset.load(.duration) {
                self.duration = CMTimeGetSeconds(duration)
            }
        }
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func play() {
        player?.rate = playbackSpeed
        isPlaying = true
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func setSpeed(_ speed: Float) {
        playbackSpeed = speed
        if isPlaying {
            player?.rate = speed
        }
    }

    // MARK: - Frame Stepping

    func stepForward() {
        guard let player = player, let item = player.currentItem else { return }

        pause()

        // Step forward by 1 frame (assuming 60fps = 1/60 second)
        let frameTime = CMTime(value: 1, timescale: 60)
        let newTime = CMTimeAdd(player.currentTime(), frameTime)
        player.seek(to: newTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func stepBackward() {
        guard let player = player else { return }

        pause()

        // Step backward by 1 frame
        let frameTime = CMTime(value: 1, timescale: 60)
        let newTime = CMTimeSubtract(player.currentTime(), frameTime)
        player.seek(to: newTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    // MARK: - Timestamp Jumping

    func jumpToTimestamp(_ seconds: TimeInterval) {
        seek(to: seconds)
        pause()  // Pause to let user see the moment
    }

    deinit {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
    }
}
```

#### 3. Add timestamp detection for AI responses

```swift
// MARK: - Timestamp Parser

struct TimestampParser {
    /// Regex to match timestamps like "0:12", "1:30", "00:45"
    private static let pattern = #"(\d{1,2}):(\d{2})"#

    /// Extract all timestamps from text
    static func extractTimestamps(from text: String) -> [(range: Range<String.Index>, seconds: TimeInterval)] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let nsRange = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: nsRange)

        return matches.compactMap { match in
            guard let minutesRange = Range(match.range(at: 1), in: text),
                  let secondsRange = Range(match.range(at: 2), in: text),
                  let minutes = Int(text[minutesRange]),
                  let seconds = Int(text[secondsRange]),
                  let fullRange = Range(match.range, in: text) else {
                return nil
            }

            let totalSeconds = TimeInterval(minutes * 60 + seconds)
            return (range: fullRange, seconds: totalSeconds)
        }
    }
}

// Usage in ChatView:
// Make timestamps tappable that jump to that point in the video
```

#### 4. Update ChatView to use enhanced player

```swift
// In VideoPreviewHeader, replace simple VideoPlayer with EnhancedVideoPlayerView
struct VideoPreviewHeader: View {
    let videoURL: URL
    @Binding var isExpanded: Bool
    @State private var showPlayer = false

    var body: some View {
        // ... existing code ...

        // Use enhanced player in sheet
        .fullScreenCover(isPresented: $showPlayer) {
            EnhancedVideoPlayerView(videoURL: videoURL)
                .ignoresSafeArea()
        }
    }
}
```

---

## Implementation Plan

### Week 1: HEVC Encoding (Days 1-2)

| Task | Status | Files | Effort |
|------|--------|-------|--------|
| Add VideoCodec enum | Pending | VideoRecorder.swift | 30 min |
| Add configureVideoCodec() | Pending | VideoRecorder.swift | 30 min |
| Update Constants for dynamic duration | Pending | Constants.swift | 15 min |
| Update RecordViewModel | Pending | RecordViewModel.swift | 15 min |
| Test on iPhone 7+ (HEVC) | Pending | - | 30 min |
| Test fallback on older device | Pending | - | 30 min |
| Test Gemini upload with HEVC | Pending | - | 30 min |

### Week 2: Playback Controls (Days 3-8)

| Task | Status | Files | Effort |
|------|--------|-------|--------|
| Create VideoPlayerController | Pending | New file | 2 hours |
| Create EnhancedVideoPlayerView | Pending | New file | 3 hours |
| Add speed selector UI | Pending | PlaybackControlsView | 1 hour |
| Implement frame stepping | Pending | VideoPlayerController | 1 hour |
| Add progress bar with scrubbing | Pending | VideoProgressBar | 1 hour |
| Implement TimestampParser | Pending | New file | 1 hour |
| Integrate with ChatView | Pending | ChatView.swift | 1 hour |
| Polish animations and UX | Pending | Various | 2 hours |

### Week 3: Testing & Polish (Days 9-10)

| Task | Status | Files | Effort |
|------|--------|-------|--------|
| Add unit tests | Pending | Tests | 2 hours |
| Test slow motion on sports video | Pending | - | 1 hour |
| Test timestamp jumping | Pending | - | 30 min |
| Final UX review | Pending | - | 1 hour |

---

## Technical Specifications

### Playback Speeds

| Speed | Use Case |
|-------|----------|
| 0.25x | Frame-by-frame analysis, racket position |
| 0.5x | Slow motion, footwork analysis |
| 0.75x | Slightly slowed, timing analysis |
| 1.0x | Normal playback |
| 1.5x | Quick review |
| 2.0x | Fast forward through setup |

### Frame Stepping

- **Frame rate:** 60fps (matches recording)
- **Step duration:** 1/60 second = ~16.67ms
- **Seek tolerance:** Zero (exact frame)

### Timestamp Format

- Supported: `M:SS`, `MM:SS` (e.g., "0:12", "01:30")
- Parsed from AI analysis text
- Rendered as tappable links in chat

---

## Testing Checklist

### HEVC Encoding

- [ ] HEVC codec selected on iPhone 7+
- [ ] H.264 fallback on iPhone 6s
- [ ] 60-second HEVC video < 100MB
- [ ] Upload to Gemini succeeds
- [ ] AI analysis quality unchanged
- [ ] Duration warning at 50 seconds (10s before limit)

### Playback Controls

- [ ] All speeds work (0.25x to 2x)
- [ ] Speed persists after seek
- [ ] Frame stepping precise (single frame)
- [ ] Progress bar scrubbing smooth
- [ ] Timestamp detection accurate
- [ ] Tap-to-jump works from chat
- [ ] Controls auto-hide after 3 seconds
- [ ] Works in fullscreen mode

---

## UI/UX Design

### Playback Controls Layout

```
┌─────────────────────────────────────┐
│                                     │
│           [Video Player]            │
│                                     │
├─────────────────────────────────────┤
│ ▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░   0:12/0:30│  ← Progress bar
├─────────────────────────────────────┤
│                                     │
│   ⏮  ◀︎  ▶/❚❚  ▶︎  ⏭      [0.5x]    │  ← Controls
│                                     │
└─────────────────────────────────────┘

⏮ = Step back 1 frame
◀︎ = Skip back 5 seconds
▶/❚❚ = Play/Pause
▶︎ = Skip forward 5 seconds
⏭ = Step forward 1 frame
[0.5x] = Speed selector
```

### Timestamp Links in Chat

```
┌─────────────────────────────────────┐
│ 🤖 AI分析:                          │
│                                     │
│ 您的正手击球整体不错。在 [0:12] 时，│  ← Tappable
│ 肘部抬得稍高，建议保持在腰部高度。  │
│ 在 [0:25] 的反手击球中...           │  ← Tappable
└─────────────────────────────────────┘
```

---

## Success Metrics

| Metric | Target |
|--------|--------|
| HEVC adoption | 95%+ of recordings use HEVC |
| Recording duration | Average increases from 25s to 45s |
| Slow motion usage | 50%+ of playbacks use < 1x speed |
| Timestamp taps | 30%+ of users tap timestamps in analysis |

---

## Dependencies

- iOS 11+ for HEVC support
- AVKit for video playback
- No third-party dependencies needed

---

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| HEVC not supported | Low | Low | Automatic H.264 fallback |
| Frame stepping imprecise | Medium | Medium | Use zero-tolerance seeking |
| Timestamp parsing fails | Low | Low | Graceful degradation (no links) |

---

*Document Version: 1.0*
*Created: 2025-12-04*
*Status: Planned*
