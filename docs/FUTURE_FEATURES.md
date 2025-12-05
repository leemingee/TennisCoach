# Future Features: Video Splitting & HEVC Encoding

## Overview

This document outlines the implementation plan for two key features that will enable longer recording sessions while staying within Gemini's 100MB upload limit.

---

## Feature 1: HEVC Encoding

### Goal
Reduce video file sizes by 40-50% using HEVC (H.265) codec, enabling longer recordings.

### Current State
- Codec: H.264
- File size: ~175-200 MB/min at 60fps/1080p
- Max recording: 30 seconds

### Target State
- Codec: HEVC (H.265)
- File size: ~90-110 MB/min at 60fps/1080p (45-50% reduction)
- Max recording: 60 seconds

### Implementation

#### Device Support
- iOS 11+ and A10 chip or newer (iPhone 7+)
- Hardware acceleration via VideoToolbox
- Automatic fallback to H.264 on older devices

#### Code Changes (Minimal)

**VideoRecorder.swift** - Add codec configuration:
```swift
private func configureVideoCodec() {
    guard let videoConnection = movieOutput.connection(with: .video) else { return }

    if movieOutput.availableVideoCodecTypes.contains(.hevc) {
        movieOutput.setOutputSettings(
            [AVVideoCodecKey: AVVideoCodecType.hevc],
            for: videoConnection
        )
        AppLogger.info("Using HEVC (H.265) codec", category: AppLogger.video)
    } else {
        // Fallback for older devices
        movieOutput.setOutputSettings(
            [AVVideoCodecKey: AVVideoCodecType.h264],
            for: videoConnection
        )
        AppLogger.info("HEVC not available, using H.264", category: AppLogger.video)
    }
}
```

**Constants.swift** - Update duration limits:
```swift
enum Video {
    static let maxDurationHEVC: TimeInterval = 60  // ~70MB
    static let maxDurationH264: TimeInterval = 30  // ~100MB
}
```

#### Gemini Compatibility
- Gemini File API fully supports HEVC video
- No transcoding needed before upload
- Container: MP4 with HEVC codec

#### Testing Checklist
- [ ] Test on iPhone 7+ (HEVC supported)
- [ ] Test fallback on iPhone 6s (H.264 only)
- [ ] Verify 60-second HEVC video < 100MB
- [ ] Upload HEVC video to Gemini
- [ ] Compare AI analysis quality

### Estimated Effort
- Implementation: 1-2 hours
- Testing: 1-2 hours
- Priority: High (quick win, minimal changes)

---

## Feature 2: Video Splitting

### Goal
Enable recording sessions of 2-5 minutes by automatically splitting into segments.

### Current State
- Single continuous video
- Max 30 seconds (100MB limit)
- Single Gemini upload

### Target State
- Multiple 25-second segments
- Up to 5 minutes total (12 segments)
- Parallel segment uploads
- Combined analysis with context

### Implementation Strategy

#### Option A: Post-Recording Splitting (Phase 1 - Recommended First)
- Easiest to implement
- Use AVAssetExportSession to split after recording
- Deploy first to validate approach

```swift
func splitVideo(sourceURL: URL, segmentDuration: TimeInterval) async throws -> [URL] {
    let asset = AVAsset(url: sourceURL)
    var segments: [URL] = []
    var currentTime: CMTime = .zero

    while CMTimeGetSeconds(currentTime) < totalDuration {
        let segmentURL = try await extractSegment(
            from: asset,
            startTime: currentTime,
            duration: segmentDuration
        )
        segments.append(segmentURL)
        currentTime = CMTimeAdd(currentTime, CMTime(seconds: segmentDuration, preferredTimescale: 600))
    }

    return segments
}
```

#### Option B: During-Recording Segmentation (Phase 2)
- Better UX with real-time segment indication
- More efficient (no post-processing)
- Uses AVCaptureMovieFileOutput.maxRecordedDuration

### Segment Length Recommendation

**25 seconds per segment**
- At 60fps H.264: ~73 MB (27 MB safety margin)
- At 60fps HEVC: ~45 MB (55 MB safety margin)
- 12 segments for 5-minute session

### Data Model

```swift
@Model
final class VideoSegment {
    var id: UUID
    var segmentIndex: Int
    var localPath: String
    var geminiFileUri: String?
    var duration: TimeInterval
    var startTime: TimeInterval
    var fileSize: Int64
}

@Model
final class SegmentedVideo {
    var id: UUID
    var totalDuration: TimeInterval
    var createdAt: Date
    @Relationship var segments: [VideoSegment]
}
```

### Gemini Integration

#### Multi-Segment Analysis Strategy
1. **Parallel Upload**: Upload all segments concurrently
2. **Context Preservation**: Include segment position in prompts
3. **Combined Analysis**: Aggregate insights across segments

```swift
// Contextual prompt for each segment
let prompt = """
这是一段网球训练视频的第 \(index + 1)/\(total) 部分。
时间范围: \(startTime)-\(endTime) 秒

请分析这一段的技术表现...
"""
```

### UI Updates

#### Recording Screen
- Segment progress bar showing completed/current/remaining
- Dual time display: current segment + total duration
- Visual segment transition indicator

#### Analysis Screen
- Timeline view with segment thumbnails
- Tap to jump to segment
- Combined analysis with timestamp links
- Upload progress per segment

### Testing Checklist
- [ ] 5-minute recording splits into 12 segments
- [ ] Parallel upload of all segments
- [ ] Context maintained across segments
- [ ] UI shows segment progress
- [ ] Cleanup of segment files after processing

### Estimated Effort
- Phase 1 (Post-recording split): 4-6 hours
- Phase 2 (During-recording): 8-12 hours
- UI updates: 4-6 hours
- Priority: Medium (after HEVC)

---

## Implementation Roadmap

### Week 1: HEVC Encoding
1. Add HEVC codec configuration
2. Update duration limits based on codec
3. Add codec detection and fallback
4. Test on multiple devices

### Week 2: Video Splitting (Phase 1)
1. Implement post-recording split with AVAssetExportSession
2. Add VideoSegment and SegmentedVideo models
3. Update GeminiService for multi-segment upload
4. Basic segment progress UI

### Week 3: Video Splitting (Phase 2)
1. Implement during-recording segmentation
2. Full timeline UI with segment navigation
3. Context-aware multi-segment analysis
4. Polish and edge case handling

---

## Configuration Constants

```swift
// Constants.swift additions
enum Video {
    // Segment configuration
    static let segmentDuration: TimeInterval = 25.0
    static let maxTotalDuration: TimeInterval = 300.0 // 5 minutes
    static let maxSegmentSizeBytes: Int64 = 80_000_000 // 80MB safety

    // Codec-specific durations
    static let maxDurationHEVC: TimeInterval = 60
    static let maxDurationH264: TimeInterval = 30

    // Enable/disable features
    static let enableHEVCEncoding = true
    static let enableAutoSegmentation = true
}
```

---

## Files to Modify

- `Services/VideoRecorder.swift` - HEVC config, segmented recording
- `Models/Video.swift` - Add segment models
- `Services/GeminiService.swift` - Multi-segment upload
- `Views/Recording/RecordViewModel.swift` - Segment tracking
- `Views/Recording/RecordView.swift` - Segment UI
- `Utilities/Constants.swift` - Feature configuration

---

*Document Version: 1.0*
*Created: December 2024*
