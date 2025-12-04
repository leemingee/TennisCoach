# TennisCoach Iteration 2 - Bug Fixes & Enhancements

> **Created:** 2025-12-04
> **Status:** Completed (Phase 1-3)
> **Priority:** High
> **Last Updated:** 2025-12-04

---

## Executive Summary

This document outlines bugs discovered during initial testing and planned enhancements for Iteration 2. The issues range from critical UX problems (camera not working on first launch) to feature requests (video playback, advanced camera controls).

---

## Table of Contents

1. [Bug Reports](#bug-reports)
2. [Feature Requests](#feature-requests)
3. [Technical Analysis](#technical-analysis)
4. [Implementation Plan](#implementation-plan)
5. [UI/UX Design Recommendations](#uiux-design-recommendations)

---

## Bug Reports

### BUG-001: Recording Screen Black on First Launch (CRITICAL)

**Severity:** Critical
**Component:** RecordView, RecordViewModel, VideoRecorder
**Status:** ✅ FIXED

#### Description
When the app launches and the user goes to the Recording tab, the camera preview shows a black screen. Attempting to record shows the error message "当前没有正在进行的录制" (No recording is currently in progress). The user must dismiss this error before recording works on subsequent attempts.

#### Steps to Reproduce
1. Launch the app fresh
2. Land on the Recording tab (first tab)
3. Observe black screen
4. Tap record button
5. Error appears: "当前没有正在进行的录制"
6. Tap "确定" to dismiss
7. Now recording works

#### Root Cause Analysis

**Problem 1: Race Condition in Camera Setup**
```swift
// RecordView.swift - Line 51-53
.task {
    await viewModel.setup()
}
```
The `.task` modifier may not complete before the user taps record. The camera session starts asynchronously, but there's no indication to the user that setup is in progress.

**Problem 2: Missing Session State Check**
```swift
// RecordViewModel.swift - Line 49-53
private func startRecording() {
    guard let recorder = videoRecorder else {
        error = "录制器未初始化"  // This error is shown
        return
    }
    // ...
}
```
The check only verifies `videoRecorder` exists, not whether the session is running.

**Problem 3: No Loading State During Setup**
The UI doesn't show any loading indicator while the camera is initializing, leading to user confusion.

#### Proposed Solution

1. **Add camera setup state management:**
```swift
enum CameraState {
    case initializing
    case ready
    case recording
    case error(String)
}

@Published var cameraState: CameraState = .initializing
```

2. **Show loading indicator during setup:**
```swift
if cameraState == .initializing {
    VStack {
        ProgressView()
            .scaleEffect(1.5)
        Text("正在启动相机...")
            .foregroundColor(.white)
    }
}
```

3. **Disable record button until ready:**
```swift
RecordButton(...)
    .disabled(cameraState != .ready)
```

4. **Wait for session to be running before allowing recording:**
```swift
func setup() async {
    cameraState = .initializing
    // ... setup code ...

    // Wait for session to actually start
    while !captureSession.isRunning {
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
    }
    cameraState = .ready
}
```

---

### BUG-002: Video Playback Not Available (HIGH)

**Severity:** High
**Component:** ChatView, VideoListView
**Status:** ✅ FIXED

#### Description
Recorded videos appear in the video list with thumbnails, but users cannot:
1. Play/replay the video from within the app
2. Find the video in the iPhone Photos app
3. Access the video outside of TennisCoach

#### Current Behavior
- Videos are saved to app's Documents directory (sandboxed)
- ChatView shows chat history but no video player
- VideoListView shows thumbnail but no playback option

#### Storage Location Analysis
```swift
// VideoRecorder.swift - Line 227-228
let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
let videosPath = documentsPath.appendingPathComponent(Constants.Storage.videosDirectory)
// Saves to: /Documents/RecordedVideos/tennis_<timestamp>.mp4
```

Videos are stored in the **app's private Documents folder**, NOT in the Photos library. This is by design for privacy, but users expect to see their videos in Photos.

#### Proposed Solution

**Part A: Add In-App Video Player**

```swift
// New component: VideoPlayerView.swift
import AVKit
import SwiftUI

struct VideoPlayerView: View {
    let videoURL: URL
    @State private var player: AVPlayer?

    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                player = AVPlayer(url: videoURL)
            }
            .onDisappear {
                player?.pause()
            }
    }
}
```

**Part B: Add to ChatView Header**
```swift
// ChatView.swift - Add video preview at top
VStack(spacing: 0) {
    // Video preview (tappable to expand)
    if let url = video.localURL {
        VideoPreviewHeader(videoURL: url)
            .frame(height: 200)
    }

    // ... existing messages list
}
```

**Part C: Optional - Save to Photos Library**
```swift
import Photos

func saveVideoToPhotosLibrary(url: URL) async throws {
    let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
    guard status == .authorized else {
        throw VideoError.photoLibraryAccessDenied
    }

    try await PHPhotoLibrary.shared().performChanges {
        PHAssetCreationRequest.forAsset().addResource(
            with: .video,
            fileURL: url,
            options: nil
        )
    }
}
```

**Part D: Add "Save to Photos" button in video detail/chat view**

---

### BUG-003: Frozen Camera Preview on Tab Return (MEDIUM)

**Severity:** Medium
**Component:** RecordView, VideoRecorder
**Status:** ✅ FIXED

#### Description
After navigating away from the Recording tab (to Videos or Settings) and returning, the camera preview shows a frozen/stuck image from the last frame. The camera session appears to have stopped.

#### Root Cause Analysis
```swift
// RecordViewModel.swift - deinit
deinit {
    timerTask?.cancel()
    videoRecorder?.stopSession()  // Session stops when view disappears
}
```

The issue is that:
1. `@StateObject` keeps the ViewModel alive during tab switches
2. BUT the view's `.task` only runs on first appear
3. Camera session may stop due to iOS background restrictions

#### Proposed Solution

1. **Use `.onAppear` / `.onDisappear` for session management:**
```swift
// RecordView.swift
.onAppear {
    Task {
        await viewModel.resumeSession()
    }
}
.onDisappear {
    viewModel.pauseSession()
}
```

2. **Add pause/resume methods:**
```swift
// RecordViewModel.swift
func pauseSession() {
    // Don't stop session, just pause preview updates if needed
}

func resumeSession() async {
    guard let recorder = videoRecorder else {
        await setup()
        return
    }

    if !recorder.isSessionRunning {
        await recorder.startSession()
    }
}
```

3. **Track session state:**
```swift
// VideoRecorder.swift
var isSessionRunning: Bool {
    captureSession.isRunning
}
```

---

### BUG-004: Settings About Section Missing Contact Info (LOW)

**Severity:** Low
**Component:** ContentView (SettingsView)
**Status:** ✅ FIXED

#### Description
The Settings → About section only shows version number. User requests:
- Developer email
- GitHub repository link
- Contribution invitation

#### Proposed Solution

```swift
Section("About") {
    HStack {
        Text("Version")
        Spacer()
        Text("1.0.0")
            .foregroundColor(.secondary)
    }

    Link(destination: URL(string: "mailto:your-email@example.com")!) {
        HStack {
            Label("Contact Developer", systemImage: "envelope")
            Spacer()
            Image(systemName: "arrow.up.right")
                .foregroundColor(.secondary)
        }
    }

    Link(destination: URL(string: "https://github.com/leemingee/TennisCoach")!) {
        HStack {
            Label("GitHub Repository", systemImage: "chevron.left.forwardslash.chevron.right")
            Spacer()
            Image(systemName: "arrow.up.right")
                .foregroundColor(.secondary)
        }
    }
}

Section {
    Text("TennisCoach is open source. Contributions are welcome!")
        .font(.footnote)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
}
```

---

## Feature Requests

### FEAT-001: Advanced Camera Controls (MEDIUM)

**Priority:** Medium
**Complexity:** High
**Component:** VideoRecorder, RecordView

#### Description
Users want access to advanced camera features similar to the native iPhone Camera app:
- Lens switching (0.5x ultra-wide, 1x wide, 2x+ telephoto)
- Pinch-to-zoom
- Tap-to-focus
- Exposure control
- Recording quality presets (standard vs slow-motion)

#### Technical Research Summary

**Available iOS Frameworks:**
1. **AVFoundation** (currently used) - Full control, requires manual implementation
2. **NextLevel** (third-party) - Pre-built camera controls, lens switching, zoom
3. **UIImagePickerController** - Limited, not suitable for advanced controls

**Recommended Approach:** Enhance existing AVFoundation implementation

#### Proposed Implementation

**Phase 1: Lens Switching**
- Add `CameraLens` enum (ultraWide, wideAngle, telephoto)
- Add lens switch buttons to UI (0.5x, 1x, 2x)
- Implement `switchCamera(to:)` in VideoRecorder

**Phase 2: Zoom Controls**
- Add `MagnificationGesture` to RecordView
- Implement `setZoom(factor:)` in VideoRecorder
- Show current zoom level overlay

**Phase 3: Focus & Exposure**
- Add tap gesture for tap-to-focus
- Add exposure slider (optional)
- Visual focus indicator

**Phase 4: Recording Presets**
- Standard: 1080p @ 60fps
- Analysis: 1080p @ 120fps (slow-motion)
- Toggle in settings or recording UI

#### UI Design

```
┌─────────────────────────────────────┐
│ ┌───────────────────────────────┐   │
│ │                               │   │
│ │     Camera Preview            │   │
│ │                               │   │
│ │     [Tap to focus indicator]  │   │
│ │                               │   │
│ └───────────────────────────────┘   │
│                                     │
│  [0.5x] [1x] [2x]      [Grid] [HD]  │  ← Controls overlay
│                                     │
│         ┌─────────────┐             │
│         │   00:00     │             │  ← Timer
│         └─────────────┘             │
│                                     │
│           ◉ Record                  │  ← Record button
│                                     │
└─────────────────────────────────────┘
```

---

## Implementation Plan

### Phase 1: Critical Bug Fixes (Priority: HIGHEST) ✅ COMPLETED

| Task | Bug | Status | Files |
|------|-----|--------|-------|
| Fix camera initialization race condition | BUG-001 | ✅ Done | RecordViewModel, RecordView |
| Add loading state during camera setup | BUG-001 | ✅ Done | RecordView |
| Handle tab switching for camera session | BUG-003 | ✅ Done | RecordViewModel, VideoRecorder |

### Phase 2: Video Playback (Priority: HIGH) ✅ COMPLETED

| Task | Bug | Status | Files |
|------|-----|--------|-------|
| Create VideoPlayerView component | BUG-002 | ✅ Done | New: VideoPlayerView.swift |
| Add video header to ChatView | BUG-002 | ✅ Done | ChatView |
| Add fullscreen video player | BUG-002 | ✅ Done | VideoPlayerView |
| Implement "Save to Photos" | BUG-002 | ✅ Done | RecordViewModel, VideoPlayerView |

### Phase 3: Settings & Polish (Priority: MEDIUM) ✅ COMPLETED

| Task | Bug | Status | Files |
|------|-----|--------|-------|
| Add About section content | BUG-004 | ✅ Done | ContentView |
| Add developer contact links | BUG-004 | ✅ Done | ContentView |

### Phase 4: Advanced Camera (Priority: LOW) - PENDING

| Task | Feature | Status | Files |
|------|---------|--------|-------|
| Implement lens switching | FEAT-001 | Pending | VideoRecorder, RecordView |
| Add pinch-to-zoom | FEAT-001 | Pending | RecordView, VideoRecorder |
| Add tap-to-focus | FEAT-001 | Pending | RecordView, VideoRecorder |
| Add recording presets | FEAT-001 | Pending | Constants, VideoRecorder, Settings |

---

## UI/UX Design Recommendations

### Recording Screen Best Practices

1. **Clear Camera State Indication**
   - Show "Initializing camera..." with spinner on first load
   - Disable record button until camera is ready
   - Use visual cues (button opacity, color) for state

2. **Graceful Error Handling**
   - Don't show technical error messages
   - Provide actionable guidance ("Please allow camera access in Settings")
   - Auto-retry camera initialization on failure

3. **Professional Recording UI**
   - Minimal controls during recording (just timer + stop button)
   - Full controls before recording (lens, zoom, settings)
   - Grid overlay option for composition

### Video Gallery Best Practices

1. **Video Preview**
   - Show video thumbnail with play button overlay
   - Tap to play inline or fullscreen
   - Swipe to delete

2. **Video Detail View**
   - Video player at top (expandable)
   - AI analysis chat below
   - Share/Export options in toolbar

### Settings Best Practices

1. **Organized Sections**
   - API Configuration
   - Recording Settings (quality, fps, grid)
   - About & Contact
   - Debug/Advanced (optional)

2. **User-Friendly Links**
   - Use SF Symbols for visual clarity
   - External links should open in Safari/Mail
   - Internal settings should use NavigationLink

---

## Questions for User

Before implementation, please clarify:

1. **Email for About Section:** What email address should be displayed?
2. **Photo Library Saving:** Should videos automatically save to Photos, or offer a manual "Save to Photos" button?
3. **Camera Controls Priority:** Which camera features are most important?
   - [ ] Lens switching (0.5x, 1x, 2x)
   - [ ] Pinch-to-zoom
   - [ ] Slow-motion recording (120fps)
   - [ ] Grid overlay
   - [ ] Tap-to-focus

---

## Appendix: File Changes Summary

### Completed Changes

| File | Changes |
|------|---------|
| `RecordView.swift` | Added CameraState handling, CameraLoadingOverlay, CameraErrorOverlay, improved RecordButton with isEnabled |
| `RecordViewModel.swift` | Added CameraState enum, canRecord property, resumeSession(), pauseSession(), saveToPhotosLibrary(), fixed timer race condition |
| `VideoRecorder.swift` | Added isSessionRunning property, resumeSession() method |
| `ChatView.swift` | Added VideoPreviewHeader, fixed UIScreen.main deprecation |
| `ContentView.swift` | Enhanced Settings About section with email, GitHub link, contribution text |
| `GeminiService.swift` | Fixed 4 force unwraps with proper guard statements |
| **NEW** `Views/VideoPlayer/VideoPlayerView.swift` | VideoPlayerView, FullScreenVideoPlayer, VideoPreviewHeader components |
| **DELETED** `Item.swift` | Removed unused Xcode template file |

### P0 Code Quality Fixes

| Issue | Fix |
|-------|-----|
| Force unwraps in GeminiService | Replaced with guard let + proper error throwing |
| Timer race condition | Added @MainActor to timer Task |
| UIScreen.main deprecation | Replaced with containerRelativeFrame |
| Unused template file | Deleted Item.swift |

---

*Document Version: 2.0*
*Last Updated: 2025-12-04*
*Status: Phase 1-3 Complete, Phase 4 Pending*
