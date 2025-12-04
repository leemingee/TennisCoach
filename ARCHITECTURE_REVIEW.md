# TennisCoach Architecture Review & Recommendations

**Review Date**: 2025-12-04
**Reviewer**: Architecture Review Agent
**Project**: TennisCoach iOS App
**Version**: 1.0.0

---

## Executive Summary

The TennisCoach iOS app demonstrates solid foundational architecture with clear separation of concerns through a layered architecture (Presentation, Service, Data). However, the current implementation stores videos in the app's Documents directory, which can lead to storage bloat and data management challenges. This review provides comprehensive recommendations for migrating to Photos Library storage while maintaining architectural integrity and planning for future extensibility.

### Critical Findings

1. **Storage Architecture Issue**: Videos stored in Documents directory (P0 - Immediate Action Required)
2. **Data Model Coupling**: Video model tightly coupled to file system paths (P0)
3. **Future Scalability**: Current architecture needs adjustments for planned features (P1)
4. **Performance Optimization**: Thumbnail generation and video playback patterns need refinement (P1)

### Strategic Recommendations Overview

- Migrate to PHAsset-based video storage
- Implement PhotoLibraryService layer
- Refactor Video model to support PHAsset references
- Design for future features: multi-angle comparison, annotations, cloud sync
- Establish clear data lifecycle management

---

## Table of Contents

1. [Current Architecture Analysis](#current-architecture-analysis)
2. [Critical Issues & Risks](#critical-issues--risks)
3. [Recommended Architecture: Photos Library Integration](#recommended-architecture-photos-library-integration)
4. [Implementation Roadmap](#implementation-roadmap)
5. [Future Feature Planning](#future-feature-planning)
6. [Code Examples & Patterns](#code-examples--patterns)
7. [Migration Strategy](#migration-strategy)
8. [Testing Strategy](#testing-strategy)

---

## Current Architecture Analysis

### System Overview

```
Current Layered Architecture:
┌─────────────────────────────────────────────────────────────┐
│ Presentation Layer (SwiftUI + ViewModels)                   │
│ - RecordView/RecordViewModel                                │
│ - VideoListView                                             │
│ - ChatView/ChatViewModel                                    │
├─────────────────────────────────────────────────────────────┤
│ Service Layer                                               │
│ - VideoRecorder (AVFoundation)                              │
│ - GeminiService (API integration)                           │
│ - VideoCompressor                                           │
├─────────────────────────────────────────────────────────────┤
│ Data Layer (SwiftData)                                      │
│ - Video (localPath: String)                                 │
│ - Conversation                                              │
│ - Message                                                   │
│ - FileManager for video/thumbnail storage                   │
└─────────────────────────────────────────────────────────────┘
```

### Strengths

1. **Clear Separation of Concerns**: Three-tier architecture with distinct responsibilities
2. **Protocol-Based Design**: `VideoRecording` and `GeminiServicing` protocols enable testability
3. **Modern Swift Patterns**:
   - Swift Concurrency (async/await)
   - SwiftData for persistence
   - Combine for reactive updates
4. **Robust Error Handling**: Custom error types with localized descriptions
5. **Retry Logic**: Sophisticated retry policies for network operations
6. **Streaming Support**: AsyncThrowingStream for real-time AI responses

### Current Data Flow

```
Recording Flow:
VideoRecorder → File System (Documents/RecordedVideos/) → Video Model (localPath) → SwiftData

Analysis Flow:
Video Model → GeminiService.uploadVideo() → Gemini API → geminiFileUri stored in Video

Playback Flow:
Video.localURL → AVPlayer (in-app) or system video player
```

---

## Critical Issues & Risks

### 1. Storage Architecture (P0 - Critical)

**Issue**: Videos stored in app Documents directory

**Impact**:
- App bundle size grows uncontrollably with user content
- Videos consume app storage quota, not device photo storage
- No integration with system Photos app
- Difficult backup/restore management
- Videos lost on app deletion
- Cannot leverage Photos Library features (Live Photos, iCloud Photo Library, etc.)

**Risk Level**: High
- **Business Risk**: Poor user experience, storage complaints
- **Technical Debt**: Significant refactoring required to change later
- **Scalability**: Blocks multi-device sync features

### 2. Data Model Coupling (P0 - Critical)

**Current Implementation** (`/Users/yoyo/src/TennisCoach/TennisCoach/TennisCoach/Models/Video.swift`):

```swift
@Model
final class Video {
    var localPath: String  // Tightly coupled to file system
    var geminiFileUri: String?
    var duration: TimeInterval
    var thumbnailData: Data?  // Stored in database (inefficient)
    // ...
}
```

**Problems**:
- `localPath` assumes file system storage
- Thumbnail data duplicated in database and file system
- No support for Photos Library asset identifiers
- Difficult to migrate existing data

**Risk Level**: High
- Breaking changes required for Photos Library migration
- Data migration complexity
- Potential data loss if not handled carefully

### 3. Thumbnail Management (P1 - Important)

**Current Pattern** (`/Users/yoyo/src/TennisCoach/TennisCoach/TennisCoach/Services/VideoRecorder.swift:273-286`):

```swift
static func generateThumbnail(from videoURL: URL) async -> Data? {
    let asset = AVAsset(url: videoURL)
    let imageGenerator = AVAssetImageGenerator(asset: asset)
    imageGenerator.appliesPreferredTrackTransform = true
    imageGenerator.maximumSize = Constants.Video.thumbnailSize

    do {
        let cgImage = try imageGenerator.copyCGImage(at: .zero, actualTime: nil)
        let uiImage = UIImage(cgImage: cgImage)
        return uiImage.jpegData(compressionQuality: 0.7)
    } catch {
        return nil
    }
}
```

**Issues**:
- Thumbnail stored as Data in SwiftData (increases database size)
- No caching strategy for thumbnails
- Regenerated on every access if missing
- Photos Library provides free thumbnails via PHImageManager

**Risk Level**: Medium
- Performance degradation with many videos
- Unnecessary storage consumption
- Battery impact from repeated generation

### 4. Video Playback Architecture (P1 - Important)

**Current State**:
- No dedicated video playback component
- ChatView likely uses AVPlayer with local file URLs
- No support for Photos Library playback

**Missing Components**:
- VideoPlayerView for consistent playback UI
- PHAsset-aware player
- Playback state management
- Picture-in-picture support preparation

### 5. Future Feature Constraints (P1 - Important)

**Planned Features vs. Current Architecture**:

| Feature | Current Support | Blockers |
|---------|----------------|----------|
| Multi-angle comparison | No | Requires multiple video references, playback sync |
| Video annotations | No | Needs frame-by-frame access, drawing layer |
| Progress tracking | Partial | Requires historical data aggregation |
| Cloud sync | No | File-based storage incompatible with efficient sync |
| Offline caching | No | No cache layer, always regenerates |
| Social sharing | No | No share sheet integration for PHAssets |

---

## Recommended Architecture: Photos Library Integration

### New Layered Architecture

```
Recommended Architecture:
┌─────────────────────────────────────────────────────────────────────┐
│ Presentation Layer                                                  │
│ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌──────────────┐  │
│ │ RecordView  │ │VideoListView│ │  ChatView   │ │VideoPlayerView│ │
│ │+ViewModel   │ │             │ │ +ViewModel  │ │  +ViewModel   │ │
│ └─────────────┘ └─────────────┘ └─────────────┘ └──────────────┘  │
├─────────────────────────────────────────────────────────────────────┤
│ Service Layer                                                       │
│ ┌─────────────────┐ ┌─────────────────┐ ┌────────────────────┐    │
│ │ VideoRecorder   │ │ GeminiService   │ │PhotoLibraryService │    │
│ │ - capture       │ │ - upload        │ │ - save to Photos   │    │
│ │ - compress      │ │ - analyze       │ │ - fetch PHAsset    │    │
│ │ - save to temp  │ │ - chat          │ │ - request video    │    │
│ │                 │ │                 │ │ - generate thumb   │    │
│ └─────────────────┘ └─────────────────┘ └────────────────────┘    │
│                                            ┌────────────────────┐   │
│                                            │  CacheService      │   │
│                                            │ - thumbnail cache  │   │
│                                            │ - video temp cache │   │
│                                            └────────────────────┘   │
├─────────────────────────────────────────────────────────────────────┤
│ Data Layer                                                          │
│ ┌──────────────────┐ ┌──────────────────────────────────────────┐  │
│ │ SwiftData Models │ │ Photos Library (PHPhotoLibrary)          │  │
│ │ - Video          │ │ - PHAsset (actual video)                 │  │
│ │   * assetID      │ │ - PHAssetCollection                      │  │
│ │   * metadata     │ │ - PHImageManager (thumbnail provider)    │  │
│ │ - Conversation   │ │ - PHCachingImageManager                  │  │
│ │ - Message        │ │                                          │  │
│ └──────────────────┘ └──────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │  Gemini 3 API   │
                    └─────────────────┘
```

### Key Architectural Changes

#### 1. PhotoLibraryService (New Component)

**Responsibilities**:
- Save recorded videos to Photos Library
- Retrieve PHAssets by local identifier
- Request video data for playback/upload
- Generate thumbnails using PHImageManager
- Manage Photos Library permissions
- Create/manage custom albums (e.g., "TennisCoach Videos")

**Location**: `/Users/yoyo/src/TennisCoach/TennisCoach/TennisCoach/Services/PhotoLibraryService.swift`

#### 2. Refactored Video Model

**New Schema**:

```swift
@Model
final class Video {
    @Attribute(.unique) var id: UUID

    // Photos Library Integration
    var photoAssetID: String?  // PHAsset.localIdentifier (primary storage)
    var legacyLocalPath: String?  // For migration from old storage

    // Metadata
    var duration: TimeInterval
    var createdAt: Date
    var recordingDate: Date

    // Analysis State
    var geminiFileUri: String?
    var uploadedAt: Date?

    // Cached Data (optional, for offline access)
    var cachedMetadata: VideoMetadata?

    @Relationship(deleteRule: .cascade, inverse: \Conversation.video)
    var conversations: [Conversation] = []

    // Computed Properties
    var storageType: VideoStorageType {
        if photoAssetID != nil { return .photoLibrary }
        if legacyLocalPath != nil { return .fileSystem }
        return .unknown
    }
}

enum VideoStorageType: Codable {
    case photoLibrary  // Recommended
    case fileSystem    // Legacy, migration pending
    case unknown
}

struct VideoMetadata: Codable {
    var width: Int
    var height: Int
    var frameRate: Double
    var fileSize: Int64
    var codec: String
}
```

#### 3. CacheService (New Component)

**Purpose**: Optimize performance by caching frequently accessed data

**Responsibilities**:
- In-memory thumbnail cache (NSCache)
- Temporary video file cache for upload/playback
- Cache invalidation policies
- Storage quota management

**Cache Strategy**:
```
Thumbnail Cache:
- Use PHCachingImageManager for Photos Library assets
- LRU eviction policy
- Memory limit: 50MB
- Disk cache: Optional, for offline scenarios

Video Cache:
- Temporary cache for Gemini upload (auto-cleanup)
- Playback buffer cache (AVPlayer handles this)
- Clear on app termination
```

---

## Implementation Roadmap

### Phase 1: Foundation (Week 1-2)

**Goal**: Establish Photos Library infrastructure without breaking existing functionality

**Tasks**:

1. **Create PhotoLibraryService** (Priority: P0)
   - File: `/Users/yoyo/src/TennisCoach/TennisCoach/TennisCoach/Services/PhotoLibraryService.swift`
   - Implement permission handling
   - Create custom album "TennisCoach Videos"
   - Save video to Photos Library
   - Fetch PHAsset by identifier
   - Request video URL for playback/upload

2. **Create CacheService** (Priority: P1)
   - File: `/Users/yoyo/src/TennisCoach/TennisCoach/TennisCoach/Services/CacheService.swift`
   - Implement thumbnail cache
   - Implement temporary file cache

3. **Update Video Model** (Priority: P0)
   - File: `/Users/yoyo/src/TennisCoach/TennisCoach/TennisCoach/Models/Video.swift`
   - Add `photoAssetID` field
   - Add `legacyLocalPath` for backward compatibility
   - Add computed properties for storage type detection
   - Maintain existing `localPath` temporarily

4. **Update Constants** (Priority: P2)
   - File: `/Users/yoyo/src/TennisCoach/TennisCoach/TennisCoach/Utilities/Constants.swift`
   - Add Photos Library configuration
   - Define cache limits

**Deliverables**:
- PhotoLibraryService protocol and implementation
- Updated Video model with migration support
- CacheService infrastructure
- Unit tests for new services

**Risk Mitigation**:
- Maintain backward compatibility
- Feature flag for Photos Library storage
- Comprehensive error handling

### Phase 2: Recording Integration (Week 3)

**Goal**: Record videos directly to Photos Library

**Tasks**:

1. **Update VideoRecorder** (Priority: P0)
   - File: `/Users/yoyo/src/TennisCoach/TennisCoach/TennisCoach/Services/VideoRecorder.swift`
   - Continue saving to temp location initially
   - Remove automatic Documents directory save
   - Return temp URL for Photos Library processing

2. **Update RecordViewModel** (Priority: P0)
   - File: `/Users/yoyo/src/TennisCoach/TennisCoach/TennisCoach/Views/Recording/RecordViewModel.swift`
   - Integrate PhotoLibraryService
   - Save video to Photos Library after recording
   - Store PHAsset identifier in Video model
   - Clean up temp file after successful save

3. **Permission Flow** (Priority: P0)
   - Request Photos Library "Add Only" permission on first record
   - Show permission denied alert with settings link
   - Handle permission changes gracefully

**Deliverables**:
- Videos saved to Photos Library
- PHAsset identifiers stored in SwiftData
- Temp file cleanup working
- Permission flow implemented

**Testing**:
- Test with permissions granted
- Test with permissions denied
- Test permission changes while app running
- Verify temp file cleanup

### Phase 3: Playback & Display (Week 4)

**Goal**: Display and play videos from Photos Library

**Tasks**:

1. **Create VideoPlayerView** (Priority: P0)
   - File: `/Users/yoyo/src/TennisCoach/TennisCoach/TennisCoach/Views/VideoPlayer/VideoPlayerView.swift`
   - Support PHAsset playback
   - Support legacy file-based playback
   - Playback controls (play, pause, seek)
   - Error handling for deleted assets

2. **Update VideoListView** (Priority: P0)
   - File: `/Users/yoyo/src/TennisCoach/TennisCoach/TennisCoach/Views/VideoList/VideoListView.swift`
   - Use PHImageManager for thumbnails
   - Handle missing assets gracefully
   - Show storage type indicator

3. **Thumbnail Loading** (Priority: P1)
   - Use PHCachingImageManager
   - Implement placeholder loading states
   - Handle thumbnail request cancellation

**Deliverables**:
- VideoPlayerView component
- Thumbnail loading from Photos Library
- Graceful handling of missing assets
- Legacy file playback support

**Testing**:
- Play videos from Photos Library
- Handle deleted assets (deleted outside app)
- Verify thumbnail performance with 50+ videos
- Test legacy video playback

### Phase 4: Upload Integration (Week 5)

**Goal**: Upload videos to Gemini from Photos Library

**Tasks**:

1. **Update GeminiService** (Priority: P0)
   - File: `/Users/yoyo/src/TennisCoach/TennisCoach/TennisCoach/Services/GeminiService.swift`
   - Accept PHAsset in addition to URL
   - Request video export from Photos Library
   - Cache exported video temporarily
   - Clean up temp files after upload

2. **Update ChatViewModel** (Priority: P0)
   - File: `/Users/yoyo/src/TennisCoach/TennisCoach/TennisCoach/Views/Chat/ChatViewModel.swift`
   - Handle PHAsset-based video upload
   - Show progress during export + upload
   - Handle export failures

**Deliverables**:
- Upload from Photos Library working
- Progress indication for export + upload
- Temp file cleanup after upload
- Error handling for export failures

**Testing**:
- Upload PHAsset-based videos
- Upload legacy file-based videos
- Test with large videos (>100MB)
- Verify temp file cleanup

### Phase 5: Migration & Cleanup (Week 6)

**Goal**: Migrate existing data and remove legacy code

**Tasks**:

1. **Data Migration Tool** (Priority: P1)
   - Create one-time migration utility
   - Move existing videos to Photos Library
   - Update Video records with PHAsset IDs
   - Delete old files from Documents directory
   - Log migration results

2. **Legacy Code Removal** (Priority: P2)
   - Remove `localPath` from Video model (breaking change)
   - Remove Documents directory video storage
   - Update tests
   - Update documentation

3. **User Communication** (Priority: P1)
   - Migration progress UI
   - Success/failure notifications
   - Handle migration failures gracefully

**Deliverables**:
- Migration utility
- Clean data model
- Updated documentation
- Migration analytics

**Testing**:
- Test migration with 0, 1, 10, 50 videos
- Test migration failures (permissions, storage)
- Verify old files deleted
- Verify no data loss

### Phase 6: Optimization (Week 7)

**Goal**: Performance optimization and polish

**Tasks**:

1. **Cache Optimization** (Priority: P1)
   - Tune cache sizes
   - Implement preloading for thumbnails
   - Optimize memory usage

2. **Background Tasks** (Priority: P2)
   - Background upload queue
   - Background thumbnail generation
   - Handle app suspension during operations

3. **Performance Monitoring** (Priority: P2)
   - Add performance metrics
   - Memory usage tracking
   - Storage usage reporting

**Deliverables**:
- Optimized cache performance
- Background task support
- Performance metrics

---

## Future Feature Planning

### 1. Multi-Angle Video Comparison

**Architecture Pattern**: Multi-video coordinator

**Components**:

```swift
// New Model
@Model
final class VideoComparison {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date

    @Relationship var primaryVideo: Video
    @Relationship var comparisonVideos: [Video]

    // Synchronization metadata
    var syncPoints: [SyncPoint]  // Frame-by-frame alignment
}

struct SyncPoint: Codable {
    var primaryFrame: Int
    var comparisonFrames: [String: Int]  // videoID -> frame number
    var timestamp: TimeInterval
    var label: String  // e.g., "Ball Contact"
}

// New Service
protocol VideoSyncServicing {
    func detectKeyFrames(in video: Video) async throws -> [KeyFrame]
    func alignVideos(_ videos: [Video]) async throws -> [SyncPoint]
    func exportSideBySide(_ comparison: VideoComparison) async throws -> URL
}
```

**UI Components**:
- `ComparisonView`: Split-screen video player
- `SyncPointEditor`: Manual sync point adjustment
- `KeyFrameDetector`: AI-powered frame detection using Gemini

**Integration Points**:
- PhotoLibraryService: Fetch multiple PHAssets
- GeminiService: Analyze multiple videos simultaneously
- VideoPlayerView: Synchronized playback controls

### 2. Video Annotations & Drawing

**Architecture Pattern**: Layer-based annotation system

**Components**:

```swift
// New Model
@Model
final class VideoAnnotation {
    @Attribute(.unique) var id: UUID
    var video: Video?
    var frameNumber: Int
    var timestamp: TimeInterval
    var annotationType: AnnotationType
    var annotationData: Data  // Serialized drawing data
    var createdAt: Date
}

enum AnnotationType: String, Codable {
    case arrow      // Trajectory, movement direction
    case circle     // Highlight area
    case line       // Reference line (e.g., horizontal for racket angle)
    case freehand   // Custom drawing
    case text       // Text annotation
    case angle      // Angle measurement
}

// Annotation Service
protocol AnnotationServicing {
    func addAnnotation(to video: Video, at frame: Int, annotation: VideoAnnotation) async throws
    func getAnnotations(for video: Video, at frame: Int) -> [VideoAnnotation]
    func exportAnnotatedVideo(_ video: Video) async throws -> URL
}
```

**UI Components**:
- `AnnotationCanvas`: Drawing layer over video
- `DrawingToolbar`: Tool selection (arrow, circle, etc.)
- `AnnotationListView`: Manage all annotations
- `FrameScrubber`: Frame-by-frame navigation

**Technical Considerations**:
- Use Core Graphics for drawing layer
- Store annotations separately from video (non-destructive)
- Option to export video with burned-in annotations
- Sync annotations across devices via CloudKit

### 3. Progress Tracking Over Time

**Architecture Pattern**: Analytics aggregation service

**Components**:

```swift
// New Model
@Model
final class ProgressMetric {
    @Attribute(.unique) var id: UUID
    var video: Video?
    var metricType: MetricType
    var value: Double
    var measuredAt: Date
    var notes: String?
}

enum MetricType: String, Codable {
    case serveSpeed
    case forehandConsistency
    case footworkRating
    case techniqueScore
    case rallysustain
    // Extensible
}

// Analytics Service
protocol AnalyticsServicing {
    func extractMetrics(from analysis: String) async -> [ProgressMetric]
    func getProgressChart(for metricType: MetricType, dateRange: DateInterval) -> ChartData
    func exportProgressReport(dateRange: DateInterval) async throws -> URL
}
```

**UI Components**:
- `ProgressDashboard`: Charts and metrics overview
- `MetricDetailView`: Drill-down into specific metric
- `ComparisonTimeline`: Before/after video comparison
- `GoalTracker`: Set and track improvement goals

**AI Integration**:
- Extract metrics from Gemini analysis responses
- Ask Gemini to compare current vs. previous videos
- Generate personalized improvement recommendations

### 4. Cloud Sync Across Devices

**Architecture Pattern**: CloudKit + iCloud Photo Library

**Strategy**:

```
Sync Architecture:
┌──────────────────────────────────────────────────────────┐
│ Device A                                                 │
│ ┌────────────┐  ┌──────────────┐  ┌─────────────────┐  │
│ │ SwiftData  │→│ CloudKit Sync│←→│ iCloud Photo Lib│  │
│ └────────────┘  └──────────────┘  └─────────────────┘  │
└──────────────────────────────────────────────────────────┘
                         ↕ CloudKit
┌──────────────────────────────────────────────────────────┐
│ Device B                                                 │
│ ┌────────────┐  ┌──────────────┐  ┌─────────────────┐  │
│ │ SwiftData  │←│ CloudKit Sync│←→│ iCloud Photo Lib│  │
│ └────────────┘  └──────────────┘  └─────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

**What Syncs**:
- Video metadata (SwiftData → CloudKit)
- PHAsset identifiers (shared via iCloud Photo Library)
- Conversations and messages (SwiftData → CloudKit)
- Annotations (CloudKit)
- Progress metrics (CloudKit)

**What Doesn't Sync**:
- Actual video files (handled by iCloud Photo Library automatically)
- Gemini file URIs (regenerated per device)
- Temporary caches

**Implementation**:
- Enable SwiftData CloudKit sync (minimal code change)
- Handle sync conflicts (last-write-wins for most data)
- Optimize for offline-first operation
- Background sync queue

### 5. Offline Analysis Caching

**Architecture Pattern**: Local cache with expiration

**Components**:

```swift
// Cache Service Extension
extension CacheService {
    func cacheAnalysis(_ analysis: String, for videoID: UUID, expiresIn: TimeInterval)
    func getCachedAnalysis(for videoID: UUID) -> String?
    func invalidateAnalysisCache(for videoID: UUID)
}

// Offline Queue
protocol OfflineQueueServicing {
    func queueForAnalysis(_ video: Video)
    func processQueueWhenOnline() async
    func retryFailedAnalyses() async
}
```

**Strategy**:
- Cache Gemini analysis responses locally
- Expire cache after 30 days or on video edit
- Queue videos for analysis when offline
- Process queue when network available
- Show "cached" badge in UI

### 6. Social Sharing

**Architecture Pattern**: Share extension + rich content

**Components**:

```swift
protocol SharingServicing {
    func shareVideo(_ video: Video, with annotations: [VideoAnnotation]?) async throws
    func shareAnalysis(_ conversation: Conversation) async throws
    func shareProgressReport(_ metrics: [ProgressMetric]) async throws
    func generateShareableLink(_ video: Video) async throws -> URL
}
```

**Share Options**:
- Share raw video from Photos Library (native share sheet)
- Share annotated video (export with annotations burned in)
- Share analysis text + thumbnail
- Share progress chart image
- Generate web link for analysis (future: web viewer)

**Privacy Considerations**:
- User control over what's shared
- Strip metadata if desired
- Watermark option for shared videos
- Analytics opt-in

---

## Code Examples & Patterns

### 1. PhotoLibraryService Implementation

```swift
import Photos
import UIKit

// MARK: - Protocol

protocol PhotoLibraryServicing {
    func requestAuthorization() async -> PHAuthorizationStatus
    func saveVideo(from tempURL: URL, metadata: VideoMetadata?) async throws -> String
    func fetchAsset(withIdentifier identifier: String) -> PHAsset?
    func requestVideoURL(for asset: PHAsset) async throws -> URL
    func requestThumbnail(for asset: PHAsset, size: CGSize) async throws -> UIImage
    func deleteAsset(_ asset: PHAsset) async throws
    func createAlbum(named name: String) async throws -> PHAssetCollection
}

// MARK: - Errors

enum PhotoLibraryError: LocalizedError {
    case permissionDenied
    case assetNotFound
    case saveFailed(String)
    case exportFailed(String)
    case albumCreationFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "照片库访问权限被拒绝"
        case .assetNotFound:
            return "找不到照片库中的视频"
        case .saveFailed(let message):
            return "保存视频失败: \(message)"
        case .exportFailed(let message):
            return "导出视频失败: \(message)"
        case .albumCreationFailed:
            return "创建相册失败"
        }
    }
}

// MARK: - Implementation

final class PhotoLibraryService: PhotoLibraryServicing {

    private let albumName = "TennisCoach Videos"
    private let imageManager = PHCachingImageManager()

    // MARK: - Authorization

    func requestAuthorization() async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: .addOnly)
    }

    // MARK: - Save Video

    func saveVideo(from tempURL: URL, metadata: VideoMetadata? = nil) async throws -> String {
        // Check authorization
        let status = await requestAuthorization()
        guard status == .authorized || status == .limited else {
            throw PhotoLibraryError.permissionDenied
        }

        var localIdentifier: String?

        try await PHPhotoLibrary.shared().performChanges {
            // Create asset creation request
            let creationRequest = PHAssetCreationRequest.forAsset()
            creationRequest.addResource(with: .video, fileURL: tempURL, options: nil)

            // Set creation date (important for sorting)
            creationRequest.creationDate = Date()

            // Get placeholder for local identifier
            localIdentifier = creationRequest.placeholderForCreatedAsset?.localIdentifier

            // Add to custom album
            if let album = self.fetchAlbum(named: self.albumName),
               let placeholder = creationRequest.placeholderForCreatedAsset {
                let addRequest = PHAssetCollectionChangeRequest(for: album)
                addRequest?.addAssets([placeholder] as NSArray)
            }
        }

        guard let identifier = localIdentifier else {
            throw PhotoLibraryError.saveFailed("Failed to get local identifier")
        }

        return identifier
    }

    // MARK: - Fetch Asset

    func fetchAsset(withIdentifier identifier: String) -> PHAsset? {
        let fetchResult = PHAsset.fetchAssets(
            withLocalIdentifiers: [identifier],
            options: nil
        )
        return fetchResult.firstObject
    }

    // MARK: - Request Video URL

    func requestVideoURL(for asset: PHAsset) async throws -> URL {
        guard asset.mediaType == .video else {
            throw PhotoLibraryError.assetNotFound
        }

        return try await withCheckedThrowingContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.version = .original
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, audioMix, info in
                if let urlAsset = avAsset as? AVURLAsset {
                    continuation.resume(returning: urlAsset.url)
                } else if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: PhotoLibraryError.exportFailed(error.localizedDescription))
                } else {
                    continuation.resume(throwing: PhotoLibraryError.exportFailed("Unknown error"))
                }
            }
        }
    }

    // MARK: - Request Thumbnail

    func requestThumbnail(for asset: PHAsset, size: CGSize) async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.isNetworkAccessAllowed = true
            options.resizeMode = .fast

            imageManager.requestImage(
                for: asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                if let image = image {
                    continuation.resume(returning: image)
                } else if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: PhotoLibraryError.assetNotFound)
                }
            }
        }
    }

    // MARK: - Delete Asset

    func deleteAsset(_ asset: PHAsset) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets([asset] as NSArray)
        }
    }

    // MARK: - Album Management

    func createAlbum(named name: String) async throws -> PHAssetCollection {
        if let existing = fetchAlbum(named: name) {
            return existing
        }

        var placeholder: PHObjectPlaceholder?

        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
            placeholder = request.placeholderForCreatedAssetCollection
        }

        guard let localIdentifier = placeholder?.localIdentifier else {
            throw PhotoLibraryError.albumCreationFailed
        }

        let collections = PHAssetCollection.fetchAssetCollections(
            withLocalIdentifiers: [localIdentifier],
            options: nil
        )

        guard let album = collections.firstObject else {
            throw PhotoLibraryError.albumCreationFailed
        }

        return album
    }

    private func fetchAlbum(named name: String) -> PHAssetCollection? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", name)
        let collections = PHAssetCollection.fetchAssetCollections(
            with: .album,
            subtype: .any,
            options: fetchOptions
        )
        return collections.firstObject
    }
}
```

### 2. Updated RecordViewModel with Photos Library

```swift
@MainActor
final class RecordViewModel: ObservableObject {

    // ... existing properties ...

    private let photoLibraryService: PhotoLibraryServicing

    init(
        videoRecorder: VideoRecorder? = nil,
        photoLibraryService: PhotoLibraryServicing = PhotoLibraryService()
    ) {
        self.videoRecorder = videoRecorder
        self.photoLibraryService = photoLibraryService
    }

    private func stopRecording(modelContext: ModelContext) async {
        guard let recorder = videoRecorder else { return }

        stopDurationTimer()
        isProcessing = true

        do {
            // Step 1: Stop recording to temp file
            let tempVideoURL = try await recorder.stopRecording()
            isRecording = false

            // Step 2: Save to Photos Library
            let assetIdentifier = try await photoLibraryService.saveVideo(
                from: tempVideoURL,
                metadata: nil
            )

            // Step 3: Create Video model with PHAsset reference
            let video = Video(
                photoAssetID: assetIdentifier,
                duration: recordingDuration
            )

            // Step 4: Generate accurate metadata in background
            async let durationTask = VideoRecorder.getVideoDuration(from: tempVideoURL)

            // Fetch PHAsset for thumbnail generation
            if let asset = photoLibraryService.fetchAsset(withIdentifier: assetIdentifier) {
                // Use Photos Library thumbnail (more efficient)
                if let thumbnail = try? await photoLibraryService.requestThumbnail(
                    for: asset,
                    size: Constants.Video.thumbnailSize
                ) {
                    video.cachedThumbnail = thumbnail.jpegData(compressionQuality: 0.7)
                }
            }

            let duration = await durationTask
            video.duration = duration

            // Step 5: Save to database
            modelContext.insert(video)
            try modelContext.save()

            // Step 6: Clean up temp file
            try? FileManager.default.removeItem(at: tempVideoURL)

            isProcessing = false
            savedVideo = video

        } catch {
            isRecording = false
            isProcessing = false
            self.error = error.localizedDescription
        }
    }
}
```

### 3. Updated Video Model

```swift
import Foundation
import SwiftData

@Model
final class Video {
    @Attribute(.unique) var id: UUID

    // Storage References
    var photoAssetID: String?        // Primary: PHAsset local identifier
    var legacyLocalPath: String?     // Migration: old file system path

    // Metadata
    var duration: TimeInterval
    var createdAt: Date
    var recordingDate: Date

    // Analysis State
    var geminiFileUri: String?
    var uploadedAt: Date?

    // Optional cached data
    var cachedThumbnail: Data?
    var cachedMetadata: VideoMetadata?

    @Relationship(deleteRule: .cascade, inverse: \Conversation.video)
    var conversations: [Conversation] = []

    init(
        id: UUID = UUID(),
        photoAssetID: String? = nil,
        legacyLocalPath: String? = nil,
        duration: TimeInterval = 0,
        createdAt: Date = Date(),
        recordingDate: Date = Date()
    ) {
        self.id = id
        self.photoAssetID = photoAssetID
        self.legacyLocalPath = legacyLocalPath
        self.duration = duration
        self.createdAt = createdAt
        self.recordingDate = recordingDate
    }

    // MARK: - Computed Properties

    var storageType: VideoStorageType {
        if photoAssetID != nil { return .photoLibrary }
        if legacyLocalPath != nil { return .fileSystem }
        return .unknown
    }

    var isAvailable: Bool {
        switch storageType {
        case .photoLibrary:
            return photoAssetID != nil
        case .fileSystem:
            return legacyLocalPath != nil && FileManager.default.fileExists(atPath: legacyLocalPath!)
        case .unknown:
            return false
        }
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

enum VideoStorageType: Codable {
    case photoLibrary
    case fileSystem
    case unknown
}

struct VideoMetadata: Codable {
    var width: Int
    var height: Int
    var frameRate: Double
    var fileSize: Int64
    var codec: String
}
```

### 4. VideoPlayerView with PHAsset Support

```swift
import SwiftUI
import AVKit
import Photos

struct VideoPlayerView: View {
    let video: Video
    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var error: String?

    @Environment(\.photoLibraryService) private var photoLibraryService

    var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
                    .onAppear {
                        player.play()
                    }
                    .onDisappear {
                        player.pause()
                    }
            } else if isLoading {
                ProgressView("Loading video...")
            } else if let error = error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.red)
                    Text(error)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
        .task {
            await loadVideo()
        }
    }

    private func loadVideo() async {
        isLoading = true
        error = nil

        do {
            let playerItem: AVPlayerItem

            switch video.storageType {
            case .photoLibrary:
                guard let assetID = video.photoAssetID,
                      let asset = photoLibraryService.fetchAsset(withIdentifier: assetID) else {
                    throw PhotoLibraryError.assetNotFound
                }

                let videoURL = try await photoLibraryService.requestVideoURL(for: asset)
                playerItem = AVPlayerItem(url: videoURL)

            case .fileSystem:
                guard let path = video.legacyLocalPath else {
                    throw VideoPlayerError.invalidPath
                }
                let url = URL(fileURLWithPath: path)
                playerItem = AVPlayerItem(url: url)

            case .unknown:
                throw VideoPlayerError.unsupportedStorage
            }

            player = AVPlayer(playerItem: playerItem)
            isLoading = false

        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }
}

enum VideoPlayerError: LocalizedError {
    case invalidPath
    case unsupportedStorage

    var errorDescription: String? {
        switch self {
        case .invalidPath:
            return "无效的视频路径"
        case .unsupportedStorage:
            return "不支持的存储类型"
        }
    }
}

// Environment Key for Dependency Injection
private struct PhotoLibraryServiceKey: EnvironmentKey {
    static let defaultValue: PhotoLibraryServicing = PhotoLibraryService()
}

extension EnvironmentValues {
    var photoLibraryService: PhotoLibraryServicing {
        get { self[PhotoLibraryServiceKey.self] }
        set { self[PhotoLibraryServiceKey.self] = newValue }
    }
}
```

### 5. CacheService Implementation

```swift
import Foundation
import UIKit

protocol CacheServicing {
    func cacheThumbnail(_ image: UIImage, for videoID: UUID)
    func getThumbnail(for videoID: UUID) -> UIImage?
    func invalidateThumbnail(for videoID: UUID)
    func cacheVideoURL(_ url: URL, for videoID: UUID, expiresIn: TimeInterval)
    func getVideoURL(for videoID: UUID) -> URL?
    func clearCache()
}

final class CacheService: CacheServicing {

    // MARK: - Singleton

    static let shared = CacheService()

    // MARK: - Properties

    private let thumbnailCache = NSCache<NSString, UIImage>()
    private let videoURLCache = NSCache<NSString, CachedVideoURL>()

    private let fileManager = FileManager.default
    private lazy var cacheDirectory: URL = {
        let urls = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        let cacheDir = urls[0].appendingPathComponent("TennisCoach", isDirectory: true)
        try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        return cacheDir
    }()

    // MARK: - Initialization

    private init() {
        configureCaches()
        observeMemoryWarnings()
    }

    private func configureCaches() {
        // Thumbnail cache: ~50MB (assuming 200KB per thumbnail, ~250 thumbnails)
        thumbnailCache.totalCostLimit = 50 * 1024 * 1024
        thumbnailCache.countLimit = 250

        // Video URL cache: ~100 entries (just metadata)
        videoURLCache.countLimit = 100
    }

    private func observeMemoryWarnings() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.thumbnailCache.removeAllObjects()
        }
    }

    // MARK: - Thumbnail Cache

    func cacheThumbnail(_ image: UIImage, for videoID: UUID) {
        let key = videoID.uuidString as NSString
        let cost = estimatedCost(of: image)
        thumbnailCache.setObject(image, forKey: key, cost: cost)
    }

    func getThumbnail(for videoID: UUID) -> UIImage? {
        let key = videoID.uuidString as NSString
        return thumbnailCache.object(forKey: key)
    }

    func invalidateThumbnail(for videoID: UUID) {
        let key = videoID.uuidString as NSString
        thumbnailCache.removeObject(forKey: key)
    }

    private func estimatedCost(of image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        return cgImage.width * cgImage.height * bytesPerPixel
    }

    // MARK: - Video URL Cache

    func cacheVideoURL(_ url: URL, for videoID: UUID, expiresIn: TimeInterval) {
        let key = videoID.uuidString as NSString
        let cachedURL = CachedVideoURL(url: url, expirationDate: Date().addingTimeInterval(expiresIn))
        videoURLCache.setObject(cachedURL, forKey: key)
    }

    func getVideoURL(for videoID: UUID) -> URL? {
        let key = videoID.uuidString as NSString
        guard let cached = videoURLCache.object(forKey: key) else {
            return nil
        }

        // Check expiration
        if cached.expirationDate < Date() {
            videoURLCache.removeObject(forKey: key)
            return nil
        }

        return cached.url
    }

    // MARK: - Clear Cache

    func clearCache() {
        thumbnailCache.removeAllObjects()
        videoURLCache.removeAllObjects()

        // Clear disk cache
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
}

// MARK: - Cached Video URL

private final class CachedVideoURL {
    let url: URL
    let expirationDate: Date

    init(url: URL, expirationDate: Date) {
        self.url = url
        self.expirationDate = expirationDate
    }
}
```

---

## Migration Strategy

### Migration Plan Overview

```
Migration Timeline:
Week 1-2: Parallel Storage (both file system + Photos Library)
Week 3-4: Gradual Migration (convert existing videos)
Week 5-6: Legacy Deprecation (remove file system storage)
```

### Migration Utility

```swift
import SwiftUI
import SwiftData
import Photos

@MainActor
final class DataMigrationService: ObservableObject {

    @Published var migrationState: MigrationState = .notStarted
    @Published var progress: Double = 0.0
    @Published var currentItem: String = ""
    @Published var errors: [MigrationError] = []

    private let photoLibraryService: PhotoLibraryServicing
    private let modelContext: ModelContext

    init(
        photoLibraryService: PhotoLibraryServicing = PhotoLibraryService(),
        modelContext: ModelContext
    ) {
        self.photoLibraryService = photoLibraryService
        self.modelContext = modelContext
    }

    // MARK: - Migration

    func startMigration() async {
        migrationState = .inProgress
        progress = 0.0
        errors = []

        do {
            // Step 1: Fetch all videos with file system storage
            let descriptor = FetchDescriptor<Video>(
                predicate: #Predicate { video in
                    video.photoAssetID == nil && video.legacyLocalPath != nil
                }
            )

            let videosToMigrate = try modelContext.fetch(descriptor)

            guard !videosToMigrate.isEmpty else {
                migrationState = .completed
                return
            }

            let total = Double(videosToMigrate.count)

            // Step 2: Request Photos Library permission
            let authStatus = await photoLibraryService.requestAuthorization()
            guard authStatus == .authorized || authStatus == .limited else {
                migrationState = .failed
                errors.append(.permissionDenied)
                return
            }

            // Step 3: Migrate each video
            for (index, video) in videosToMigrate.enumerated() {
                currentItem = "Migrating video \(index + 1) of \(videosToMigrate.count)"

                do {
                    try await migrateVideo(video)
                    progress = Double(index + 1) / total
                } catch {
                    errors.append(.videoMigrationFailed(video.id, error))
                    // Continue with other videos
                }
            }

            // Step 4: Clean up old files
            await cleanupOldFiles()

            migrationState = errors.isEmpty ? .completed : .completedWithErrors

        } catch {
            migrationState = .failed
            errors.append(.unknown(error))
        }
    }

    private func migrateVideo(_ video: Video) async throws {
        guard let legacyPath = video.legacyLocalPath else {
            throw MigrationError.invalidVideoPath(video.id)
        }

        let legacyURL = URL(fileURLWithPath: legacyPath)

        guard FileManager.default.fileExists(atPath: legacyPath) else {
            throw MigrationError.fileNotFound(legacyPath)
        }

        // Save to Photos Library
        let assetIdentifier = try await photoLibraryService.saveVideo(
            from: legacyURL,
            metadata: nil
        )

        // Update video model
        video.photoAssetID = assetIdentifier
        // Keep legacyLocalPath temporarily for rollback

        try modelContext.save()

        // Delete old file
        try FileManager.default.removeItem(at: legacyURL)

        // Clear legacy path after successful deletion
        video.legacyLocalPath = nil
        try modelContext.save()
    }

    private func cleanupOldFiles() async {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videosPath = documentsPath.appendingPathComponent(Constants.Storage.videosDirectory)

        // Remove old videos directory if empty
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: videosPath.path),
           contents.isEmpty {
            try? FileManager.default.removeItem(at: videosPath)
        }
    }
}

// MARK: - Migration State

enum MigrationState {
    case notStarted
    case inProgress
    case completed
    case completedWithErrors
    case failed
}

// MARK: - Migration Errors

enum MigrationError: LocalizedError, Identifiable {
    case permissionDenied
    case invalidVideoPath(UUID)
    case fileNotFound(String)
    case videoMigrationFailed(UUID, Error)
    case unknown(Error)

    var id: String {
        switch self {
        case .permissionDenied:
            return "permission_denied"
        case .invalidVideoPath(let id):
            return "invalid_path_\(id)"
        case .fileNotFound(let path):
            return "not_found_\(path)"
        case .videoMigrationFailed(let id, _):
            return "migration_failed_\(id)"
        case .unknown:
            return "unknown_error"
        }
    }

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "照片库权限被拒绝"
        case .invalidVideoPath(let id):
            return "视频 \(id) 的路径无效"
        case .fileNotFound(let path):
            return "找不到文件: \(path)"
        case .videoMigrationFailed(let id, let error):
            return "迁移视频 \(id) 失败: \(error.localizedDescription)"
        case .unknown(let error):
            return "未知错误: \(error.localizedDescription)"
        }
    }
}

// MARK: - Migration View

struct MigrationView: View {
    @StateObject private var migrationService: DataMigrationService
    @Environment(\.dismiss) private var dismiss

    init(modelContext: ModelContext) {
        _migrationService = StateObject(wrappedValue: DataMigrationService(modelContext: modelContext))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                switch migrationService.migrationState {
                case .notStarted:
                    notStartedView
                case .inProgress:
                    inProgressView
                case .completed:
                    completedView
                case .completedWithErrors:
                    completedWithErrorsView
                case .failed:
                    failedView
                }
            }
            .padding()
            .navigationTitle("数据迁移")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if migrationService.migrationState == .completed {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    private var notStartedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64))
                .foregroundColor(.blue)

            Text("迁移到照片库")
                .font(.title2)
                .fontWeight(.bold)

            Text("将您的视频迁移到系统照片库，以便更好地管理和备份。")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Button(action: {
                Task {
                    await migrationService.startMigration()
                }
            }) {
                Text("开始迁移")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
    }

    private var inProgressView: some View {
        VStack(spacing: 24) {
            ProgressView(value: migrationService.progress)
                .progressViewStyle(.linear)

            Text(migrationService.currentItem)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("\(Int(migrationService.progress * 100))%")
                .font(.title)
                .fontWeight(.bold)
        }
    }

    private var completedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text("迁移完成")
                .font(.title2)
                .fontWeight(.bold)

            Text("所有视频已成功迁移到照片库。")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
    }

    private var completedWithErrorsView: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundColor(.orange)

            Text("迁移完成(有错误)")
                .font(.title2)
                .fontWeight(.bold)

            Text("部分视频迁移失败，详情请查看错误列表。")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            List(migrationService.errors) { error in
                Text(error.errorDescription ?? "Unknown error")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    private var failedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.red)

            Text("迁移失败")
                .font(.title2)
                .fontWeight(.bold)

            if let firstError = migrationService.errors.first {
                Text(firstError.errorDescription ?? "Unknown error")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }

            Button("重试") {
                Task {
                    await migrationService.startMigration()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
```

### Migration Checklist

- [ ] Create PhotoLibraryService
- [ ] Update Video model with photoAssetID
- [ ] Update RecordViewModel to save to Photos Library
- [ ] Create MigrationView and DataMigrationService
- [ ] Test migration with 0, 1, 10, 50 videos
- [ ] Test permission flows
- [ ] Test error handling
- [ ] Update VideoListView to use Photos Library
- [ ] Update ChatViewModel to upload from Photos Library
- [ ] Clean up legacy code
- [ ] Update documentation
- [ ] Release migration update to users

---

## Testing Strategy

### Unit Tests

**PhotoLibraryService Tests**:
```swift
class PhotoLibraryServiceTests: XCTestCase {

    func testSaveVideoToPhotosLibrary() async throws {
        let service = PhotoLibraryService()
        let testVideoURL = Bundle.main.url(forResource: "test_video", withExtension: "mp4")!

        let assetID = try await service.saveVideo(from: testVideoURL)
        XCTAssertFalse(assetID.isEmpty)

        let asset = service.fetchAsset(withIdentifier: assetID)
        XCTAssertNotNil(asset)
    }

    func testRequestThumbnail() async throws {
        // Test thumbnail generation from PHAsset
    }

    func testRequestVideoURL() async throws {
        // Test video URL retrieval from PHAsset
    }

    func testPermissionHandling() async {
        // Test various permission states
    }
}
```

**CacheService Tests**:
```swift
class CacheServiceTests: XCTestCase {

    func testThumbnailCaching() {
        let cache = CacheService.shared
        let testImage = UIImage(systemName: "star.fill")!
        let videoID = UUID()

        cache.cacheThumbnail(testImage, for: videoID)
        let retrieved = cache.getThumbnail(for: videoID)

        XCTAssertNotNil(retrieved)
    }

    func testCacheEviction() {
        // Test cache limits and eviction
    }
}
```

### Integration Tests

**Recording to Photos Library Flow**:
```swift
class RecordingIntegrationTests: XCTestCase {

    func testRecordAndSaveToPhotosLibrary() async throws {
        let viewModel = RecordViewModel()
        let modelContext = createTestModelContext()

        // Start recording
        await viewModel.setup()
        await viewModel.toggleRecording(modelContext: modelContext)

        // Wait 3 seconds
        try await Task.sleep(nanoseconds: 3_000_000_000)

        // Stop recording
        await viewModel.toggleRecording(modelContext: modelContext)

        // Verify video saved
        XCTAssertNotNil(viewModel.savedVideo)
        XCTAssertNotNil(viewModel.savedVideo?.photoAssetID)

        // Verify in Photos Library
        let service = PhotoLibraryService()
        let asset = service.fetchAsset(withIdentifier: viewModel.savedVideo!.photoAssetID!)
        XCTAssertNotNil(asset)
    }
}
```

### UI Tests

**Migration Flow**:
```swift
class MigrationUITests: XCTestCase {

    func testMigrationFlow() throws {
        let app = XCUIApplication()
        app.launch()

        // Trigger migration
        // Verify progress updates
        // Verify completion state
    }
}
```

### Performance Tests

```swift
class PerformanceTests: XCTestCase {

    func testThumbnailLoadingPerformance() {
        measure {
            // Load 50 thumbnails from Photos Library
        }
    }

    func testVideoListScrollPerformance() {
        measure {
            // Scroll through 100 videos
        }
    }
}
```

---

## Conclusion

### Summary of Recommendations

1. **Immediate Actions (P0)**:
   - Implement PhotoLibraryService
   - Update Video model to support PHAsset storage
   - Migrate recording flow to Photos Library

2. **Short-term Actions (P1)**:
   - Implement CacheService
   - Create VideoPlayerView
   - Build migration utility
   - Update all views to support Photos Library

3. **Long-term Planning (P2)**:
   - Design for multi-angle comparison
   - Prepare annotation architecture
   - Plan cloud sync strategy
   - Optimize for offline scenarios

### Expected Benefits

**Storage Efficiency**:
- Eliminate app storage bloat
- Leverage system-managed storage
- Automatic iCloud Photo Library integration

**User Experience**:
- Videos accessible in Photos app
- Familiar photo management interface
- Better backup/restore experience
- Seamless device upgrade

**Performance**:
- Free thumbnail generation via PHImageManager
- Optimized caching
- Better memory management

**Future Readiness**:
- Foundation for cloud sync
- Support for multi-angle analysis
- Annotation system preparation
- Social sharing integration

### Risk Mitigation

**Data Loss Prevention**:
- Gradual migration with rollback support
- Keep legacy files during migration
- Comprehensive error logging
- User communication

**Performance Impact**:
- Asynchronous operations
- Progressive loading
- Cache optimization
- Background processing

**Compatibility**:
- Support both storage types during transition
- Feature flags for gradual rollout
- Backward compatibility for 1-2 releases

---

## Appendix

### File Modification Summary

**New Files to Create**:
1. `/Users/yoyo/src/TennisCoach/TennisCoach/TennisCoach/Services/PhotoLibraryService.swift`
2. `/Users/yoyo/src/TennisCoach/TennisCoach/TennisCoach/Services/CacheService.swift`
3. `/Users/yoyo/src/TennisCoach/TennisCoach/TennisCoach/Views/VideoPlayer/VideoPlayerView.swift`
4. `/Users/yoyo/src/TennisCoach/TennisCoach/TennisCoach/Views/Migration/MigrationView.swift`
5. `/Users/yoyo/src/TennisCoach/TennisCoach/TennisCoach/Services/DataMigrationService.swift`

**Files to Modify**:
1. `/Users/yoyo/src/TennisCoach/TennisCoach/TennisCoach/Models/Video.swift`
   - Add `photoAssetID`, `legacyLocalPath`
   - Add `storageType` computed property
   - Add `VideoMetadata` struct

2. `/Users/yoyo/src/TennisCoach/TennisCoach/TennisCoach/Services/VideoRecorder.swift`
   - Keep temp file storage
   - Remove automatic Documents save
   - Add metadata extraction

3. `/Users/yoyo/src/TennisCoach/TennisCoach/TennisCoach/Views/Recording/RecordViewModel.swift`
   - Integrate PhotoLibraryService
   - Save to Photos Library
   - Clean up temp files

4. `/Users/yoyo/src/TennisCoach/TennisCoach/TennisCoach/Views/VideoList/VideoListView.swift`
   - Use PHImageManager for thumbnails
   - Handle both storage types
   - Add migration prompt

5. `/Users/yoyo/src/TennisCoach/TennisCoach/TennisCoach/Views/Chat/ChatViewModel.swift`
   - Handle PHAsset upload
   - Request video URL from Photos Library
   - Cache exported videos

6. `/Users/yoyo/src/TennisCoach/TennisCoach/TennisCoach/Services/GeminiService.swift`
   - Accept PHAsset or URL
   - Handle video export

7. `/Users/yoyo/src/TennisCoach/TennisCoach/TennisCoach/Utilities/Constants.swift`
   - Add Photos Library constants
   - Add cache configuration

8. `/Users/yoyo/src/TennisCoach/TennisCoach/TennisCoach/TennisCoachApp.swift`
   - Register PhotoLibraryService in environment
   - Initialize CacheService

9. `/Users/yoyo/src/TennisCoach/TennisCoach/DESIGN.md`
   - Update architecture diagrams
   - Document Photos Library integration
   - Update data model documentation

### Info.plist Updates

Add required permissions:

```xml
<key>NSPhotoLibraryAddUsageDescription</key>
<string>TennisCoach需要访问您的照片库以保存录制的网球视频。</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>TennisCoach需要访问您的照片库以播放和分析您的网球视频。</string>
```

### Constants Configuration

```swift
enum Constants {
    // ... existing ...

    enum PhotoLibrary {
        static let albumName = "TennisCoach Videos"
        static let thumbnailSize = CGSize(width: 300, height: 300)
        static let thumbnailContentMode: PHImageContentMode = .aspectFill
    }

    enum Cache {
        static let thumbnailMemoryLimit = 50 * 1024 * 1024 // 50MB
        static let thumbnailCountLimit = 250
        static let videoURLCountLimit = 100
        static let tempFileLifetime: TimeInterval = 3600 // 1 hour
    }
}
```

---

**Document Version**: 1.0
**Last Updated**: 2025-12-04
**Next Review**: After Phase 1 completion
