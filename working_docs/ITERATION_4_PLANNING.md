# TennisCoach Iteration 4 - Annotation Tools & Video Splitting

> **Created:** 2025-12-04
> **Status:** Planned
> **Priority:** Medium
> **Estimated Effort:** 3-4 weeks
> **Dependencies:** Iteration 3 (Playback Controls)

---

## Executive Summary

Iteration 4 builds on the playback controls from Iteration 3 to complete the learning loop:
1. **Drawing/Annotation Tools** - Make AI feedback actionable with visual markup
2. **Video Splitting** - Enable longer recording sessions (2-5 minutes)

These features transform TennisCoach from "feedback tool" to "learning platform."

---

## Table of Contents

1. [Feature: Drawing/Annotation Tools](#feature-drawingannotation-tools)
2. [Feature: Video Splitting](#feature-video-splitting)
3. [Implementation Plan](#implementation-plan)
4. [Technical Specifications](#technical-specifications)
5. [Testing Checklist](#testing-checklist)

---

## Feature: Drawing/Annotation Tools

### Priority: P0 (Differentiator)
### Effort: 10-15 hours
### Impact: High (makes AI feedback actionable)

### Problem Statement

When Gemini says "Your elbow angle should be 90°", users need to:
1. Pause at the frame
2. Draw lines to measure their actual angle
3. Understand the correction visually
4. Save the annotated frame for reference

Without annotation tools, AI feedback remains abstract and hard to act on.

### Solution

Add professional annotation tools:
1. Freehand drawing with color picker
2. Straight lines and arrows
3. Circles and angle measurement
4. Save annotated frame as image

### Implementation

#### 1. Create AnnotationOverlayView.swift

```swift
import SwiftUI
import PencilKit

struct AnnotationOverlayView: View {
    @Binding var isActive: Bool
    @StateObject private var viewModel = AnnotationViewModel()
    let frameImage: UIImage
    let onSave: (UIImage) -> Void

    var body: some View {
        ZStack {
            // Background frame
            Image(uiImage: frameImage)
                .resizable()
                .aspectRatio(contentMode: .fit)

            // Drawing canvas
            AnnotationCanvasView(
                tool: viewModel.currentTool,
                color: viewModel.currentColor,
                drawings: $viewModel.drawings
            )

            // Toolbar
            VStack {
                AnnotationToolbar(viewModel: viewModel)
                Spacer()
                AnnotationActionBar(
                    onUndo: { viewModel.undo() },
                    onClear: { viewModel.clear() },
                    onSave: { saveAnnotatedFrame() },
                    onCancel: { isActive = false }
                )
            }
        }
    }

    private func saveAnnotatedFrame() {
        let annotatedImage = viewModel.renderToImage(
            background: frameImage
        )
        onSave(annotatedImage)
        isActive = false
    }
}

// MARK: - Annotation Tools

enum AnnotationTool: String, CaseIterable {
    case freehand = "scribble"
    case line = "line.diagonal"
    case arrow = "arrow.right"
    case circle = "circle"
    case angle = "angle"

    var systemImage: String { rawValue }

    var displayName: String {
        switch self {
        case .freehand: return "自由画"
        case .line: return "直线"
        case .arrow: return "箭头"
        case .circle: return "圆圈"
        case .angle: return "角度"
        }
    }
}

// MARK: - Annotation View Model

@MainActor
final class AnnotationViewModel: ObservableObject {
    @Published var currentTool: AnnotationTool = .freehand
    @Published var currentColor: Color = .yellow
    @Published var lineWidth: CGFloat = 3.0
    @Published var drawings: [Drawing] = []

    private var undoStack: [[Drawing]] = []

    let colorOptions: [Color] = [
        .yellow, .red, .green, .blue, .white, .orange
    ]

    func undo() {
        guard !drawings.isEmpty else { return }
        undoStack.append(drawings)
        drawings.removeLast()
    }

    func redo() {
        guard let last = undoStack.popLast() else { return }
        drawings = last
    }

    func clear() {
        undoStack.append(drawings)
        drawings.removeAll()
    }

    func renderToImage(background: UIImage) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: background.size)
        return renderer.image { context in
            // Draw background
            background.draw(at: .zero)

            // Draw annotations
            for drawing in drawings {
                drawing.render(in: context.cgContext, size: background.size)
            }
        }
    }
}
```

#### 2. Create Drawing Models

```swift
// MARK: - Drawing Model

struct Drawing: Identifiable {
    let id = UUID()
    let tool: AnnotationTool
    let color: Color
    let lineWidth: CGFloat
    var points: [CGPoint]  // Normalized 0-1 coordinates

    func render(in context: CGContext, size: CGSize) {
        guard points.count >= 2 else { return }

        // Convert normalized points to actual coordinates
        let scaledPoints = points.map { point in
            CGPoint(x: point.x * size.width, y: point.y * size.height)
        }

        context.setStrokeColor(UIColor(color).cgColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        switch tool {
        case .freehand:
            renderFreehand(context: context, points: scaledPoints)
        case .line:
            renderLine(context: context, points: scaledPoints)
        case .arrow:
            renderArrow(context: context, points: scaledPoints)
        case .circle:
            renderCircle(context: context, points: scaledPoints)
        case .angle:
            renderAngle(context: context, points: scaledPoints)
        }
    }

    private func renderFreehand(context: CGContext, points: [CGPoint]) {
        context.beginPath()
        context.move(to: points[0])
        for point in points.dropFirst() {
            context.addLine(to: point)
        }
        context.strokePath()
    }

    private func renderLine(context: CGContext, points: [CGPoint]) {
        guard let start = points.first, let end = points.last else { return }
        context.beginPath()
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()
    }

    private func renderArrow(context: CGContext, points: [CGPoint]) {
        guard let start = points.first, let end = points.last else { return }

        // Draw line
        context.beginPath()
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()

        // Draw arrowhead
        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLength: CGFloat = 15
        let arrowAngle: CGFloat = .pi / 6

        let arrowPoint1 = CGPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        )
        let arrowPoint2 = CGPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        )

        context.beginPath()
        context.move(to: end)
        context.addLine(to: arrowPoint1)
        context.move(to: end)
        context.addLine(to: arrowPoint2)
        context.strokePath()
    }

    private func renderCircle(context: CGContext, points: [CGPoint]) {
        guard let start = points.first, let end = points.last else { return }
        let radius = hypot(end.x - start.x, end.y - start.y)
        context.beginPath()
        context.addArc(
            center: start,
            radius: radius,
            startAngle: 0,
            endAngle: .pi * 2,
            clockwise: true
        )
        context.strokePath()
    }

    private func renderAngle(context: CGContext, points: [CGPoint]) {
        guard points.count >= 3 else { return }
        let vertex = points[1]
        let point1 = points[0]
        let point2 = points[2]

        // Draw the two lines
        context.beginPath()
        context.move(to: point1)
        context.addLine(to: vertex)
        context.addLine(to: point2)
        context.strokePath()

        // Calculate and display angle
        let angle1 = atan2(point1.y - vertex.y, point1.x - vertex.x)
        let angle2 = atan2(point2.y - vertex.y, point2.x - vertex.x)
        var angleDegrees = abs((angle2 - angle1) * 180 / .pi)
        if angleDegrees > 180 { angleDegrees = 360 - angleDegrees }

        // Draw arc
        let arcRadius: CGFloat = 30
        context.beginPath()
        context.addArc(
            center: vertex,
            radius: arcRadius,
            startAngle: angle1,
            endAngle: angle2,
            clockwise: angle2 < angle1
        )
        context.strokePath()

        // Draw angle text
        let textPoint = CGPoint(
            x: vertex.x + arcRadius * 1.5 * cos((angle1 + angle2) / 2),
            y: vertex.y + arcRadius * 1.5 * sin((angle1 + angle2) / 2)
        )
        let text = String(format: "%.0f°", angleDegrees)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: UIColor(color)
        ]
        (text as NSString).draw(at: textPoint, withAttributes: attributes)
    }
}
```

#### 3. Create AnnotationToolbar

```swift
struct AnnotationToolbar: View {
    @ObservedObject var viewModel: AnnotationViewModel

    var body: some View {
        HStack(spacing: 16) {
            // Tool picker
            ForEach(AnnotationTool.allCases, id: \.self) { tool in
                Button(action: { viewModel.currentTool = tool }) {
                    Image(systemName: tool.systemImage)
                        .font(.title3)
                        .foregroundColor(
                            viewModel.currentTool == tool ? .yellow : .white
                        )
                        .padding(8)
                        .background(
                            viewModel.currentTool == tool
                                ? Color.white.opacity(0.2)
                                : Color.clear
                        )
                        .clipShape(Circle())
                }
            }

            Divider()
                .frame(height: 30)
                .background(Color.white.opacity(0.3))

            // Color picker
            ForEach(viewModel.colorOptions, id: \.self) { color in
                Button(action: { viewModel.currentColor = color }) {
                    Circle()
                        .fill(color)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(
                                    viewModel.currentColor == color
                                        ? Color.white
                                        : Color.clear,
                                    lineWidth: 2
                                )
                        )
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.7))
    }
}
```

#### 4. Integrate with EnhancedVideoPlayerView

```swift
// Add annotation mode toggle to playback controls
struct PlaybackControlsView: View {
    @ObservedObject var controller: VideoPlayerController
    @Binding var showAnnotation: Bool

    var body: some View {
        // ... existing controls ...

        // Add annotation button
        Button(action: {
            controller.pause()
            showAnnotation = true
        }) {
            Image(systemName: "pencil.tip.crop.circle")
                .font(.title2)
        }
    }
}

// In EnhancedVideoPlayerView:
@State private var showAnnotation = false
@State private var currentFrame: UIImage?

.sheet(isPresented: $showAnnotation) {
    if let frame = currentFrame {
        AnnotationOverlayView(
            isActive: $showAnnotation,
            frameImage: frame,
            onSave: { annotatedImage in
                saveAnnotatedFrame(annotatedImage)
            }
        )
    }
}
```

---

## Feature: Video Splitting

### Priority: P1 (Enables longer sessions)
### Effort: 12-18 hours
### Impact: Medium (longer recordings)

### Problem Statement

With HEVC, users can record 60 seconds. For full practice sessions (2-5 minutes), we need video splitting:
1. Split long recordings into ~25-second segments
2. Upload each segment separately to stay under 100MB
3. Analyze segments with context preservation
4. Present combined insights to user

### Solution

Implement post-recording video splitting using AVAssetExportSession:
1. Record continuous video (up to 5 minutes)
2. Split into 25-second segments after recording
3. Upload segments in parallel
4. Analyze with contextual prompts
5. Display timeline with segment navigation

### Implementation

#### 1. Create VideoSegment Model

```swift
import SwiftData

@Model
final class VideoSegment {
    @Attribute(.unique) var id: UUID
    var segmentIndex: Int
    var localPath: String
    var geminiFileUri: String?
    var duration: TimeInterval
    var startTime: TimeInterval  // Relative to full video
    var fileSize: Int64
    var thumbnailData: Data?
    var analysisText: String?

    @Relationship(inverse: \SegmentedVideo.segments)
    var parentVideo: SegmentedVideo?

    init(
        segmentIndex: Int,
        localPath: String,
        duration: TimeInterval,
        startTime: TimeInterval
    ) {
        self.id = UUID()
        self.segmentIndex = segmentIndex
        self.localPath = localPath
        self.duration = duration
        self.startTime = startTime
        self.fileSize = 0
    }

    var localURL: URL? {
        URL(string: localPath)
    }
}

@Model
final class SegmentedVideo {
    @Attribute(.unique) var id: UUID
    var totalDuration: TimeInterval
    var createdAt: Date
    var thumbnailData: Data?

    @Relationship(deleteRule: .cascade)
    var segments: [VideoSegment] = []

    var sortedSegments: [VideoSegment] {
        segments.sorted { $0.segmentIndex < $1.segmentIndex }
    }

    var uploadProgress: Double {
        let uploaded = segments.filter { $0.geminiFileUri != nil }.count
        return Double(uploaded) / Double(max(segments.count, 1))
    }

    init(totalDuration: TimeInterval) {
        self.id = UUID()
        self.totalDuration = totalDuration
        self.createdAt = Date()
    }
}
```

#### 2. Create VideoSplitter Service

```swift
import AVFoundation

final class VideoSplitter {
    private let segmentDuration: TimeInterval

    init(segmentDuration: TimeInterval = 25.0) {
        self.segmentDuration = segmentDuration
    }

    /// Split video into segments
    func splitVideo(
        sourceURL: URL,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> [URL] {
        let asset = AVAsset(url: sourceURL)
        let duration = try await asset.load(.duration)
        let totalSeconds = CMTimeGetSeconds(duration)

        guard totalSeconds > 0 else {
            throw VideoSplitterError.invalidVideo
        }

        // If video is short enough, no splitting needed
        if totalSeconds <= segmentDuration {
            progressHandler(1.0)
            return [sourceURL]
        }

        var segments: [URL] = []
        var currentTime: CMTime = .zero
        var segmentIndex = 0
        let segmentCMDuration = CMTime(seconds: segmentDuration, preferredTimescale: 600)

        while CMTimeGetSeconds(currentTime) < totalSeconds {
            let startTime = currentTime
            let endTime = CMTimeMinimum(
                CMTimeAdd(currentTime, segmentCMDuration),
                duration
            )

            let segmentURL = try await extractSegment(
                from: asset,
                startTime: startTime,
                endTime: endTime,
                index: segmentIndex
            )

            segments.append(segmentURL)
            currentTime = endTime
            segmentIndex += 1

            // Report progress
            let progress = CMTimeGetSeconds(currentTime) / totalSeconds
            progressHandler(min(progress, 1.0))
        }

        return segments
    }

    private func extractSegment(
        from asset: AVAsset,
        startTime: CMTime,
        endTime: CMTime,
        index: Int
    ) async throws -> URL {
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetPassthrough  // No re-encoding
        ) else {
            throw VideoSplitterError.exportSessionFailed
        }

        let outputURL = generateSegmentURL(index: index)

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.timeRange = CMTimeRange(start: startTime, end: endTime)
        exportSession.shouldOptimizeForNetworkUse = true

        await exportSession.export()

        switch exportSession.status {
        case .completed:
            return outputURL
        case .failed:
            throw exportSession.error ?? VideoSplitterError.exportFailed(index)
        case .cancelled:
            throw VideoSplitterError.cancelled
        default:
            throw VideoSplitterError.unknownError
        }
    }

    private func generateSegmentURL(index: Int) -> URL {
        let documentsPath = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
        let segmentsPath = documentsPath
            .appendingPathComponent(Constants.Storage.videosDirectory)
            .appendingPathComponent("Segments")

        try? FileManager.default.createDirectory(
            at: segmentsPath,
            withIntermediateDirectories: true
        )

        let timestamp = Date().timeIntervalSince1970
        return segmentsPath.appendingPathComponent(
            "segment_\(timestamp)_\(index).mp4"
        )
    }
}

enum VideoSplitterError: LocalizedError {
    case invalidVideo
    case exportSessionFailed
    case exportFailed(Int)
    case cancelled
    case unknownError

    var errorDescription: String? {
        switch self {
        case .invalidVideo:
            return "无效的视频文件"
        case .exportSessionFailed:
            return "无法创建导出会话"
        case .exportFailed(let index):
            return "片段 \(index + 1) 导出失败"
        case .cancelled:
            return "导出已取消"
        case .unknownError:
            return "未知错误"
        }
    }
}
```

#### 3. Create Multi-Segment Upload Service

```swift
final class SegmentedUploadService {
    private let geminiService: GeminiServicing

    init(geminiService: GeminiServicing) {
        self.geminiService = geminiService
    }

    /// Upload all segments in parallel
    func uploadSegments(
        _ segments: [VideoSegment],
        progressHandler: @escaping (Double) -> Void
    ) async throws {
        let tracker = ProgressTracker(totalCount: segments.count)

        try await withThrowingTaskGroup(of: (Int, String).self) { group in
            for segment in segments {
                group.addTask {
                    guard let url = segment.localURL else {
                        throw GeminiError.uploadFailed("Invalid segment path")
                    }

                    let fileUri = try await self.geminiService.uploadVideo(
                        localURL: url,
                        progressHandler: { progress in
                            Task { @MainActor in
                                tracker.update(
                                    segment.segmentIndex,
                                    progress: progress
                                )
                                progressHandler(tracker.overallProgress)
                            }
                        }
                    )

                    return (segment.segmentIndex, fileUri)
                }
            }

            // Collect results
            for try await (index, fileUri) in group {
                if let segment = segments.first(where: { $0.segmentIndex == index }) {
                    segment.geminiFileUri = fileUri
                }
            }
        }
    }

    /// Analyze segments with context preservation
    func analyzeSegments(
        _ segments: [VideoSegment],
        basePrompt: String
    ) async throws -> AsyncThrowingStream<SegmentedAnalysisChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var previousSummary: String?

                    for segment in segments.sorted(by: { $0.segmentIndex < $1.segmentIndex }) {
                        guard let fileUri = segment.geminiFileUri else {
                            throw AnalysisError.segmentNotUploaded(segment.segmentIndex)
                        }

                        let contextPrompt = buildContextualPrompt(
                            base: basePrompt,
                            segmentIndex: segment.segmentIndex,
                            totalSegments: segments.count,
                            previousSummary: previousSummary
                        )

                        let stream = try await geminiService.analyzeVideo(
                            fileUri: fileUri,
                            prompt: contextPrompt
                        )

                        var segmentAnalysis = ""
                        for try await chunk in stream {
                            segmentAnalysis += chunk
                            continuation.yield(
                                SegmentedAnalysisChunk(
                                    text: chunk,
                                    segmentIndex: segment.segmentIndex,
                                    timestamp: segment.startTime
                                )
                            )
                        }

                        // Extract summary for next segment's context
                        previousSummary = extractSummary(from: segmentAnalysis)
                        segment.analysisText = segmentAnalysis
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func buildContextualPrompt(
        base: String,
        segmentIndex: Int,
        totalSegments: Int,
        previousSummary: String?
    ) -> String {
        var prompt = """
        这是网球训练视频的第 \(segmentIndex + 1)/\(totalSegments) 部分。

        """

        if let summary = previousSummary {
            prompt += """
            前面部分的要点：
            \(summary)

            请继续分析这一部分，注意与之前的连贯性。

            """
        }

        prompt += base

        if segmentIndex < totalSegments - 1 {
            prompt += "\n\n请在分析结尾提供一个简短摘要（2-3句话）供后续参考。"
        }

        return prompt
    }

    private func extractSummary(from analysis: String) -> String {
        // Extract last paragraph or last 200 characters as summary
        let lines = analysis.components(separatedBy: "\n\n")
        if let lastParagraph = lines.last, lastParagraph.count > 20 {
            return String(lastParagraph.prefix(200))
        }
        return String(analysis.suffix(200))
    }
}

struct SegmentedAnalysisChunk {
    let text: String
    let segmentIndex: Int
    let timestamp: TimeInterval
}

@MainActor
final class ProgressTracker {
    private var segmentProgress: [Int: Double] = [:]
    private let totalCount: Int

    init(totalCount: Int) {
        self.totalCount = totalCount
    }

    func update(_ index: Int, progress: Double) {
        segmentProgress[index] = progress
    }

    var overallProgress: Double {
        let total = segmentProgress.values.reduce(0, +)
        return total / Double(max(totalCount, 1))
    }
}

enum AnalysisError: LocalizedError {
    case segmentNotUploaded(Int)

    var errorDescription: String? {
        switch self {
        case .segmentNotUploaded(let index):
            return "片段 \(index + 1) 尚未上传"
        }
    }
}
```

#### 4. Create Segment Timeline UI

```swift
struct SegmentTimelineView: View {
    let segments: [VideoSegment]
    @Binding var selectedSegment: Int?
    let onSegmentTap: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(segments.sorted(by: { $0.segmentIndex < $1.segmentIndex })) { segment in
                    SegmentThumbnailView(
                        segment: segment,
                        isSelected: selectedSegment == segment.segmentIndex
                    )
                    .onTapGesture {
                        selectedSegment = segment.segmentIndex
                        onSegmentTap(segment.segmentIndex)
                    }
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 100)
    }
}

struct SegmentThumbnailView: View {
    let segment: VideoSegment
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            // Thumbnail
            ZStack {
                if let data = segment.thumbnailData,
                   let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                }

                // Upload status overlay
                if segment.geminiFileUri == nil {
                    Color.black.opacity(0.5)
                    ProgressView()
                        .tint(.white)
                }
            }
            .frame(width: 80, height: 60)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )

            // Time label
            Text(formatTime(segment.startTime))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
```

---

## Implementation Plan

### Week 1-2: Annotation Tools

| Task | Status | Files | Effort |
|------|--------|-------|--------|
| Create Drawing model | Pending | Drawing.swift | 2 hours |
| Create AnnotationViewModel | Pending | AnnotationViewModel.swift | 2 hours |
| Create AnnotationCanvasView | Pending | AnnotationCanvasView.swift | 3 hours |
| Implement freehand drawing | Pending | Drawing.swift | 1 hour |
| Implement line & arrow tools | Pending | Drawing.swift | 2 hours |
| Implement circle tool | Pending | Drawing.swift | 1 hour |
| Implement angle measurement | Pending | Drawing.swift | 2 hours |
| Create AnnotationToolbar | Pending | AnnotationToolbar.swift | 1 hour |
| Implement save annotated frame | Pending | AnnotationOverlayView.swift | 1 hour |
| Integrate with video player | Pending | EnhancedVideoPlayerView.swift | 1 hour |

### Week 3-4: Video Splitting

| Task | Status | Files | Effort |
|------|--------|-------|--------|
| Create VideoSegment model | Pending | VideoSegment.swift | 1 hour |
| Create SegmentedVideo model | Pending | SegmentedVideo.swift | 1 hour |
| Create VideoSplitter service | Pending | VideoSplitter.swift | 3 hours |
| Implement parallel upload | Pending | SegmentedUploadService.swift | 3 hours |
| Implement contextual analysis | Pending | SegmentedUploadService.swift | 3 hours |
| Create SegmentTimelineView | Pending | SegmentTimelineView.swift | 2 hours |
| Update RecordViewModel for long recordings | Pending | RecordViewModel.swift | 2 hours |
| Update ChatView for segmented videos | Pending | ChatView.swift | 2 hours |
| Add segment progress UI | Pending | Various | 2 hours |

---

## Technical Specifications

### Annotation Tools

| Tool | Gesture | Points Required |
|------|---------|-----------------|
| Freehand | Drag | Continuous |
| Line | Drag start→end | 2 (start, end) |
| Arrow | Drag start→end | 2 (start, end) |
| Circle | Drag center→edge | 2 (center, radius point) |
| Angle | Tap-tap-tap | 3 (point1, vertex, point2) |

### Video Splitting

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Segment duration | 25 seconds | 73MB at H.264, 45MB at HEVC |
| Max total duration | 5 minutes | 12 segments max |
| Parallel uploads | All at once | Maximize speed |
| Context carry-over | Last paragraph summary | Maintain analysis continuity |

---

## Testing Checklist

### Annotation Tools

- [ ] Freehand drawing smooth
- [ ] Lines snap to endpoints
- [ ] Arrows show proper direction
- [ ] Circles draw from center
- [ ] Angle measurement accurate (±2°)
- [ ] Color selection works
- [ ] Undo/redo works
- [ ] Save produces valid image
- [ ] Image saved to Photos

### Video Splitting

- [ ] 3-minute video splits into ~7 segments
- [ ] Segments play back smoothly
- [ ] No gaps between segments
- [ ] Parallel upload completes
- [ ] Progress shows correctly
- [ ] Context preserved across segments
- [ ] Timeline navigation works
- [ ] Combined analysis makes sense

---

## Success Metrics

| Metric | Target |
|--------|--------|
| Annotation usage | 30%+ of video reviews include annotations |
| Saved frames | Average 2+ annotated frames per session |
| Angle tool usage | 20%+ use angle measurement |
| Long session recording | 20%+ of recordings > 60 seconds |
| Segment analysis quality | Users rate 4+/5 for context continuity |

---

## Dependencies

- Iteration 3 (Playback Controls) - Required for annotation integration
- SwiftData for segment models
- AVAssetExportSession for splitting

---

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Drawing performance issues | Medium | Medium | Use Metal for canvas |
| Segment upload failures | Medium | High | Retry logic, resume capability |
| Context lost between segments | Medium | Medium | Include overlapping content |
| Storage space for segments | Low | Medium | Clean up after upload |

---

*Document Version: 1.0*
*Created: 2025-12-04*
*Status: Planned*
*Depends On: Iteration 3*
