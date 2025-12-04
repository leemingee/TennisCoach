import AVFoundation
import UIKit

// MARK: - Protocol

/// Protocol for video compression functionality
protocol VideoCompressing: AnyObject {
    /// Compress a video file with specified quality
    /// - Parameters:
    ///   - inputURL: URL of the video to compress
    ///   - quality: Compression quality level
    ///   - progressHandler: Optional closure to receive progress updates (0.0 to 1.0)
    /// - Returns: URL of the compressed video file
    /// - Throws: VideoCompressorError if compression fails
    func compress(
        inputURL: URL,
        quality: CompressionQuality,
        progressHandler: ((Progress) -> Void)?
    ) async throws -> URL

    /// Cancel any ongoing compression operation
    func cancelCompression()

    /// Clean up temporary files created during compression
    func cleanupTemporaryFiles() async
}

// MARK: - Compression Quality

/// Defines compression quality levels for video processing
enum CompressionQuality {
    /// Fast compression with smaller file size (suitable for previews)
    /// Target: ~15-20MB for 2-minute video
    case low

    /// Balanced compression (recommended for AI analysis)
    /// Target: ~30-40MB for 2-minute video
    case medium

    /// Best quality compression with larger file size]\
    ///
    ///
    ///
    ///    /// Target: ~50-70MB for 2-minute video
    case high

    /// AVAssetExportSession preset for this quality level
    var exportPreset: String {
        switch self {
        case .low:
            return AVAssetExportPresetLowQuality
        case .medium:
            return AVAssetExportPresetMediumQuality
        case .high:
            return AVAssetExportPresetHighestQuality
        }
    }

    /// Target video bitrate in bits per second
    var videoBitRate: Int {
        switch self {
        case .low:
            return 1_500_000  // 1.5 Mbps
        case .medium:
            return 3_000_000  // 3 Mbps
        case .high:
            return 5_000_000  // 5 Mbps
        }
    }

    /// Target audio bitrate in bits per second
    var audioBitRate: Int {
        switch self {
        case .low:
            return 64_000   // 64 kbps
        case .medium:
            return 96_000   // 96 kbps
        case .high:
            return 128_000  // 128 kbps
        }
    }
}

// MARK: - Progress

/// Represents the progress of a video compression operation
struct Progress: Sendable {
    /// Fraction completed (0.0 to 1.0)
    let fractionCompleted: Double

    /// Estimated remaining time in seconds
    let estimatedTimeRemaining: TimeInterval?

    /// Whether the operation can be cancelled
    let isCancellable: Bool

    init(
        fractionCompleted: Double,
        estimatedTimeRemaining: TimeInterval? = nil,
        isCancellable: Bool = true
    ) {
        self.fractionCompleted = fractionCompleted
        self.estimatedTimeRemaining = estimatedTimeRemaining
        self.isCancellable = isCancellable
    }
}

// MARK: - Errors

enum VideoCompressorError: LocalizedError {
    case invalidInputURL
    case unsupportedFormat
    case exportSessionCreationFailed
    case compressionFailed(String)
    case compressionCancelled
    case outputFileCreationFailed
    case insufficientStorage
    case fileAccessDenied

    var errorDescription: String? {
        switch self {
        case .invalidInputURL:
            return "无效的视频文件路径"
        case .unsupportedFormat:
            return "不支持的视频格式"
        case .exportSessionCreationFailed:
            return "无法创建视频导出会话"
        case .compressionFailed(let message):
            return "视频压缩失败: \(message)"
        case .compressionCancelled:
            return "视频压缩已取消"
        case .outputFileCreationFailed:
            return "无法创建输出文件"
        case .insufficientStorage:
            return "存储空间不足"
        case .fileAccessDenied:
            return "无法访问视频文件"
        }
    }
}

// MARK: - Implementation

final class VideoCompressor: VideoCompressing {

    // MARK: - Properties

    private var currentExportSession: AVAssetExportSession?
    private var progressTimer: Timer?
    private let fileManager = FileManager.default
    private let temporaryDirectory: URL

    // MARK: - Initialization

    init() {
        // Create a dedicated temporary directory for compression
        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent("VideoCompression", isDirectory: true)
        self.temporaryDirectory = tempDir

        // Ensure temporary directory exists
        try? fileManager.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    deinit {
        // Clean up any ongoing operations
        cancelCompression()
        progressTimer?.invalidate()
    }

    // MARK: - Public Methods

    func compress(
        inputURL: URL,
        quality: CompressionQuality,
        progressHandler: ((Progress) -> Void)?
    ) async throws -> URL {
        // Validate input
        try await validateInput(inputURL)

        // Check available storage
        try checkAvailableStorage(for: inputURL)

        // Create asset from input URL
        let asset = AVAsset(url: inputURL)

        // Verify asset is readable
        guard try await asset.load(.isReadable) else {
            throw VideoCompressorError.fileAccessDenied
        }

        // Create export session
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: quality.exportPreset
        ) else {
            throw VideoCompressorError.exportSessionCreationFailed
        }

        // Store reference for cancellation
        self.currentExportSession = exportSession

        // Generate output URL
        let outputURL = generateOutputURL()

        // Configure export session
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true

        // Apply custom video and audio settings for better control
        exportSession.videoComposition = nil // Use default composition
        exportSession.audioMix = nil // Use default audio mix

        // Set metadata to preserve orientation
        exportSession.metadata = try? await asset.load(.metadata)

        // Start progress monitoring if handler provided
        if let progressHandler = progressHandler {
            await startProgressMonitoring(
                exportSession: exportSession,
                progressHandler: progressHandler
            )
        }

        // Perform compression
        await exportSession.export()

        // Stop progress monitoring
        await stopProgressMonitoring()

        // Check export status
        switch exportSession.status {
        case .completed:
            // Verify output file exists
            guard fileManager.fileExists(atPath: outputURL.path) else {
                throw VideoCompressorError.outputFileCreationFailed
            }

            // Log compression results
            await logCompressionResults(
                inputURL: inputURL,
                outputURL: outputURL,
                quality: quality
            )

            return outputURL

        case .cancelled:
            // Clean up partial file
            try? fileManager.removeItem(at: outputURL)
            throw VideoCompressorError.compressionCancelled

        case .failed:
            // Clean up partial file
            try? fileManager.removeItem(at: outputURL)

            let errorMessage = exportSession.error?.localizedDescription ?? "Unknown error"
            throw VideoCompressorError.compressionFailed(errorMessage)

        default:
            // Clean up partial file
            try? fileManager.removeItem(at: outputURL)
            throw VideoCompressorError.compressionFailed("Unexpected export status")
        }
    }

    func cancelCompression() {
        currentExportSession?.cancelExport()
        currentExportSession = nil
    }

    func cleanupTemporaryFiles() async {
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: temporaryDirectory,
                includingPropertiesForKeys: [.creationDateKey],
                options: [.skipsHiddenFiles]
            )

            // Remove files older than 1 hour
            let cutoffDate = Date().addingTimeInterval(-3600)

            for fileURL in contents {
                if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                   let creationDate = attributes[.creationDate] as? Date,
                   creationDate < cutoffDate {
                    try? fileManager.removeItem(at: fileURL)
                }
            }
        } catch {
            // Silently fail - cleanup is best effort
            print("Warning: Failed to clean up temporary files: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Methods

    private func validateInput(_ inputURL: URL) async throws {
        // Check if file exists
        guard fileManager.fileExists(atPath: inputURL.path) else {
            throw VideoCompressorError.invalidInputURL
        }

        // Verify it's a video file
        let asset = AVAsset(url: inputURL)
        let tracks = try await asset.load(.tracks)
        let hasVideoTrack = tracks.contains { $0.mediaType == .video }

        guard hasVideoTrack else {
            throw VideoCompressorError.unsupportedFormat
        }
    }

    private func checkAvailableStorage(for inputURL: URL) throws {
        do {
            let attributes = try fileManager.attributesOfItem(atPath: inputURL.path)
            guard let fileSize = attributes[.size] as? UInt64 else { return }

            // Get available storage
            let systemAttributes = try fileManager.attributesOfFileSystem(
                forPath: temporaryDirectory.path
            )
            guard let freeSpace = systemAttributes[.systemFreeSize] as? UInt64 else { return }

            // Ensure we have at least 2x the original file size available
            // (conservative estimate for compression workspace)
            let requiredSpace = fileSize * 2

            if freeSpace < requiredSpace {
                throw VideoCompressorError.insufficientStorage
            }
        } catch is VideoCompressorError {
            throw VideoCompressorError.insufficientStorage
        } catch {
            // If we can't determine storage, proceed optimistically
            return
        }
    }

    private func generateOutputURL() -> URL {
        let fileName = "compressed_\(UUID().uuidString).mp4"
        return temporaryDirectory.appendingPathComponent(fileName)
    }

    @MainActor
    private func startProgressMonitoring(
        exportSession: AVAssetExportSession,
        progressHandler: @escaping (Progress) -> Void
    ) {
        // Initial progress callback
        progressHandler(Progress(fractionCompleted: 0.0, isCancellable: true))

        // Create timer to monitor progress
        progressTimer = Timer.scheduledTimer(
            withTimeInterval: 0.1,
            repeats: true
        ) { [weak self, weak exportSession] _ in
            guard let exportSession = exportSession else { return }

            let progress = Progress(
                fractionCompleted: Double(exportSession.progress),
                estimatedTimeRemaining: nil,
                isCancellable: true
            )

            progressHandler(progress)
        }
    }

    @MainActor
    private func stopProgressMonitoring() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func logCompressionResults(
        inputURL: URL,
        outputURL: URL,
        quality: CompressionQuality
    ) async {
        do {
            let inputAttributes = try fileManager.attributesOfItem(atPath: inputURL.path)
            let outputAttributes = try fileManager.attributesOfItem(atPath: outputURL.path)

            if let inputSize = inputAttributes[.size] as? UInt64,
               let outputSize = outputAttributes[.size] as? UInt64 {
                let compressionRatio = Double(outputSize) / Double(inputSize)
                let savedSpace = inputSize - outputSize

                print("""
                    Video Compression Results:
                    - Quality: \(quality)
                    - Input size: \(formatBytes(inputSize))
                    - Output size: \(formatBytes(outputSize))
                    - Compression ratio: \(String(format: "%.1f%%", compressionRatio * 100))
                    - Space saved: \(formatBytes(savedSpace))
                    """)
            }
        } catch {
            print("Warning: Could not log compression results: \(error.localizedDescription)")
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - Convenience Methods

extension VideoCompressor {

    /// Compress a video with default medium quality
    /// - Parameters:
    ///   - inputURL: URL of the video to compress
    ///   - progressHandler: Optional closure to receive progress updates
    /// - Returns: URL of the compressed video file
    func compress(
        inputURL: URL,
        progressHandler: ((Progress) -> Void)? = nil
    ) async throws -> URL {
        try await compress(
            inputURL: inputURL,
            quality: .medium,
            progressHandler: progressHandler
        )
    }

    /// Get estimated output size for a compression operation
    /// - Parameters:
    ///   - inputURL: URL of the video to compress
    ///   - quality: Compression quality level
    /// - Returns: Estimated output size in bytes
    static func estimateOutputSize(
        inputURL: URL,
        quality: CompressionQuality
    ) async throws -> UInt64 {
        let asset = AVAsset(url: inputURL)
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)

        // Calculate estimated size based on bitrate and duration
        let videoBitRate = UInt64(quality.videoBitRate)
        let audioBitRate = UInt64(quality.audioBitRate)
        let totalBitRate = videoBitRate + audioBitRate

        // Size = (bitrate * duration) / 8 (convert bits to bytes)
        let estimatedSize = (totalBitRate * UInt64(durationSeconds)) / 8

        return estimatedSize
    }

    /// Check if a video needs compression based on file size
    /// - Parameters:
    ///   - videoURL: URL of the video to check
    ///   - threshold: Size threshold in bytes (default: 50MB)
    /// - Returns: True if video exceeds threshold
    static func needsCompression(
        videoURL: URL,
        threshold: UInt64 = 50_000_000
    ) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(
            atPath: videoURL.path
        ),
              let fileSize = attributes[.size] as? UInt64 else {
            return false
        }

        return fileSize > threshold
    }
}

// MARK: - Testing Support

#if DEBUG
extension VideoCompressor {

    /// Get information about a video file for testing
    static func getVideoInfo(_ videoURL: URL) async throws -> VideoInfo {
        let asset = AVAsset(url: videoURL)
        let duration = try await asset.load(.duration)
        let tracks = try await asset.load(.tracks)

        var videoTrack: AVAssetTrack?
        for track in tracks where track.mediaType == .video {
            videoTrack = track
            break
        }

        let fileAttributes = try FileManager.default.attributesOfItem(
            atPath: videoURL.path
        )
        let fileSize = fileAttributes[.size] as? UInt64 ?? 0

        var naturalSize: CGSize = .zero
        var estimatedFrameRate: Float = 0

        if let track = videoTrack {
            naturalSize = try await track.load(.naturalSize)
            estimatedFrameRate = try await track.load(.nominalFrameRate)
        }

        return VideoInfo(
            duration: CMTimeGetSeconds(duration),
            fileSize: fileSize,
            resolution: naturalSize,
            frameRate: estimatedFrameRate
        )
    }

    struct VideoInfo {
        let duration: TimeInterval
        let fileSize: UInt64
        let resolution: CGSize
        let frameRate: Float
    }
}
#endif
