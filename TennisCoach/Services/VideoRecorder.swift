import AVFoundation
import UIKit

// MARK: - Protocol

/// Protocol defining video recording functionality for the app.
///
/// This protocol enables dependency injection and mocking for tests.
/// The recorder handles:
/// - Camera permission requests
/// - AVCaptureSession lifecycle (start/stop/resume)
/// - Video recording to MP4 files
/// - Thumbnail generation from recorded videos
protocol VideoRecording: AnyObject {
    var isRecording: Bool { get }
    var previewLayer: AVCaptureVideoPreviewLayer { get }

    func requestPermissions() async -> Bool
    func startSession() async throws
    func stopSession()
    func startRecording() throws
    func stopRecording() async throws -> URL
}

// MARK: - Camera Lens

/// Available camera lenses for recording.
/// Maps to physical iPhone camera modules.
enum CameraLens: String, CaseIterable {
    case ultraWide = "0.5x"   // Ultra-wide angle (13mm equivalent)
    case wide = "1x"          // Standard wide angle (26mm equivalent)
    case telephoto = "2x"     // Telephoto (52mm equivalent, or 2x digital zoom)

    var displayName: String { rawValue }

    /// SF Symbol for the lens
    var systemImage: String {
        switch self {
        case .ultraWide: return "camera.aperture"
        case .wide: return "camera"
        case .telephoto: return "camera.macro"
        }
    }

    /// AVCaptureDevice type for this lens
    var deviceType: AVCaptureDevice.DeviceType {
        switch self {
        case .ultraWide: return .builtInUltraWideCamera
        case .wide: return .builtInWideAngleCamera
        case .telephoto: return .builtInTelephotoCamera
        }
    }

    /// Zoom factor for digital zoom fallback
    var zoomFactor: CGFloat {
        switch self {
        case .ultraWide: return 0.5  // Will use ultrawide if available
        case .wide: return 1.0
        case .telephoto: return 2.0
        }
    }
}

// MARK: - Errors

enum VideoRecorderError: LocalizedError {
    case cameraUnavailable
    case microphoneUnavailable
    case permissionDenied
    case sessionConfigurationFailed
    case recordingFailed(String)
    case noRecordingInProgress
    case recordingTimeout
    case lensNotAvailable

    var errorDescription: String? {
        switch self {
        case .cameraUnavailable:
            return "相机不可用"
        case .microphoneUnavailable:
            return "麦克风不可用"
        case .permissionDenied:
            return "请在设置中允许相机和麦克风访问"
        case .sessionConfigurationFailed:
            return "相机配置失败"
        case .recordingFailed(let message):
            return "录制失败: \(message)"
        case .noRecordingInProgress:
            return "当前没有正在进行的录制"
        case .recordingTimeout:
            return "录制停止超时"
        case .lensNotAvailable:
            return "该镜头不可用"
        }
    }
}

// MARK: - Implementation

/// AVFoundation-based video recorder for capturing tennis practice videos.
///
/// ## Architecture
/// Uses AVCaptureSession with:
/// - Wide-angle back camera (default)
/// - Built-in microphone for audio
/// - AVCaptureMovieFileOutput for H.264/AAC recording
///
/// ## Configuration Choices
/// - **60fps**: Higher frame rate captures fast tennis movements better for AI analysis
/// - **Session preset .high**: 1080p quality balances file size vs. quality
/// - **Auto video stabilization**: Reduces shake from handheld recording
/// - **File protection**: Videos protected until first device unlock
///
/// ## Threading Model
/// - AVCaptureSession runs on a private queue internally
/// - Public methods are async to work with Swift Concurrency
/// - Session start/stop dispatched to MainActor for safety
final class VideoRecorder: NSObject, VideoRecording {

    // MARK: - Properties

    private let captureSession = AVCaptureSession()
    private var movieOutput = AVCaptureMovieFileOutput()
    private var currentRecordingURL: URL?
    private var currentVideoDevice: AVCaptureDevice?
    private var currentVideoInput: AVCaptureDeviceInput?

    /// Continuation for bridging delegate callback to async/await
    private var recordingContinuation: CheckedContinuation<URL, Error>?

    private(set) var isRecording = false

    /// Currently selected camera lens
    private(set) var currentLens: CameraLens = .wide

    /// Check if the capture session is currently running.
    /// Used by RecordViewModel to verify camera is ready before recording.
    var isSessionRunning: Bool {
        captureSession.isRunning
    }

    /// Available lenses on this device.
    /// Determined at runtime based on device capabilities.
    var availableLenses: [CameraLens] {
        CameraLens.allCases.filter { lens in
            AVCaptureDevice.default(lens.deviceType, for: .video, position: .back) != nil ||
            (lens == .telephoto && currentVideoDevice != nil) // 2x digital zoom always available
        }
    }

    /// Preview layer for displaying camera feed in SwiftUI via UIViewRepresentable.
    /// Uses .resizeAspectFill to fill the view while maintaining aspect ratio.
    lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        return layer
    }()

    // MARK: - Permissions

    func requestPermissions() async -> Bool {
        let videoStatus = await requestVideoPermission()
        let audioStatus = await requestAudioPermission()
        return videoStatus && audioStatus
    }

    private func requestVideoPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    private func requestAudioPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        default:
            return false
        }
    }

    // MARK: - Session Management

    func startSession() async throws {
        guard await requestPermissions() else {
            throw VideoRecorderError.permissionDenied
        }

        try configureSession()

        await MainActor.run {
            captureSession.startRunning()
        }
    }

    func stopSession() {
        captureSession.stopRunning()
    }

    /// Resume the capture session if it was stopped
    func resumeSession() async {
        guard !captureSession.isRunning else { return }

        await MainActor.run {
            captureSession.startRunning()
        }
    }

    /// Configure AVCaptureSession with camera, microphone, and recording output.
    ///
    /// Configuration is wrapped in begin/commitConfiguration for atomic changes.
    /// This prevents glitches during setup and ensures all changes apply together.
    private func configureSession() throws {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        // Use .high preset for 1080p recording
        // Note: .high is better than .hd1920x1080 for compatibility across devices
        captureSession.sessionPreset = .high

        // === Video Input ===
        // Use wide-angle back camera (standard lens, not ultra-wide or telephoto)
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw VideoRecorderError.cameraUnavailable
        }

        // Store reference for lens switching
        currentVideoDevice = videoDevice
        currentLens = .wide

        // Configure 60fps for smooth tennis motion capture
        // Higher frame rate = better slow-motion analysis and AI frame extraction
        try configureFrameRate(device: videoDevice, desiredFPS: Constants.Video.preferredFPS)

        let videoInput = try AVCaptureDeviceInput(device: videoDevice)
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
            currentVideoInput = videoInput
        }

        // Add audio input
        guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
            throw VideoRecorderError.microphoneUnavailable
        }

        let audioInput = try AVCaptureDeviceInput(device: audioDevice)
        if captureSession.canAddInput(audioInput) {
            captureSession.addInput(audioInput)
        }

        // === Movie Output ===
        if captureSession.canAddOutput(movieOutput) {
            captureSession.addOutput(movieOutput)

            // Enable automatic video stabilization for handheld recording
            // .auto lets iOS choose the best stabilization mode for the situation
            if let connection = movieOutput.connection(with: .video) {
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = .auto
                }
            }
        }
    }

    /// Configure camera for high frame rate capture (60fps).
    ///
    /// Algorithm:
    /// 1. Iterate through all device formats
    /// 2. Find formats supporting the desired FPS
    /// 3. Pick the format with the *lowest* max FPS that still meets our requirement
    ///    (avoids unnecessarily high frame rates that waste battery)
    /// 4. Lock device and set the frame duration (1/fps)
    ///
    /// - Note: Uses CMTime for frame duration (1/60 = 0.0167 seconds per frame)
    private func configureFrameRate(device: AVCaptureDevice, desiredFPS: Float) throws {
        var bestFormat: AVCaptureDevice.Format?
        var bestFrameRateRange: AVFrameRateRange?

        // Find the best format that supports our desired frame rate
        for format in device.formats {
            for range in format.videoSupportedFrameRateRanges {
                if range.maxFrameRate >= Float64(desiredFPS) {
                    // Prefer the format with lowest max frame rate that still works
                    // This tends to be more power-efficient
                    if bestFrameRateRange == nil || range.maxFrameRate < bestFrameRateRange!.maxFrameRate {
                        bestFormat = format
                        bestFrameRateRange = range
                    }
                }
            }
        }

        if let format = bestFormat, let range = bestFrameRateRange {
            // Lock device for configuration (required for changing format settings)
            try device.lockForConfiguration()
            device.activeFormat = format
            // Set frame duration = 1/fps (e.g., 1/60 second for 60fps)
            let frameDuration = CMTime(value: 1, timescale: CMTimeScale(min(Float64(desiredFPS), range.maxFrameRate)))
            device.activeVideoMinFrameDuration = frameDuration
            device.activeVideoMaxFrameDuration = frameDuration
            device.unlockForConfiguration()
        }
    }

    // MARK: - Lens Switching

    /// Switch to a different camera lens.
    ///
    /// Strategy:
    /// 1. Try to use the physical lens (ultra-wide, wide, telephoto)
    /// 2. If physical lens unavailable, use digital zoom on current device
    ///
    /// - Parameter lens: The desired camera lens
    /// - Throws: VideoRecorderError if switching fails
    func switchLens(to lens: CameraLens) throws {
        guard !isRecording else {
            AppLogger.warning("Cannot switch lens while recording", category: AppLogger.video)
            return
        }

        // Try to get the physical camera for this lens
        if let device = AVCaptureDevice.default(lens.deviceType, for: .video, position: .back) {
            try switchToPhysicalCamera(device: device, lens: lens)
        } else if lens == .telephoto, let device = currentVideoDevice {
            // Fall back to digital zoom for telephoto
            try applyDigitalZoom(to: device, factor: lens.zoomFactor)
            currentLens = lens
        } else if lens == .ultraWide {
            // Ultra-wide not available, log and ignore
            AppLogger.warning("Ultra-wide camera not available on this device", category: AppLogger.video)
            throw VideoRecorderError.lensNotAvailable
        } else {
            throw VideoRecorderError.lensNotAvailable
        }
    }

    /// Switch to a physical camera device.
    private func switchToPhysicalCamera(device: AVCaptureDevice, lens: CameraLens) throws {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        // Remove current video input
        if let currentInput = currentVideoInput {
            captureSession.removeInput(currentInput)
        }

        // Configure new device
        try configureFrameRate(device: device, desiredFPS: Constants.Video.preferredFPS)

        // Add new input
        let newInput = try AVCaptureDeviceInput(device: device)
        if captureSession.canAddInput(newInput) {
            captureSession.addInput(newInput)
            currentVideoInput = newInput
            currentVideoDevice = device
            currentLens = lens

            // Reset zoom to 1x when switching physical cameras
            try? applyDigitalZoom(to: device, factor: 1.0)

            AppLogger.info("Switched to \(lens.displayName) lens", category: AppLogger.video)
        } else {
            // Re-add old input if new one fails
            if let oldInput = currentVideoInput {
                captureSession.addInput(oldInput)
            }
            throw VideoRecorderError.sessionConfigurationFailed
        }

        // Re-enable stabilization on new connection
        if let connection = movieOutput.connection(with: .video),
           connection.isVideoStabilizationSupported {
            connection.preferredVideoStabilizationMode = .auto
        }
    }

    /// Apply digital zoom to the current camera device.
    private func applyDigitalZoom(to device: AVCaptureDevice, factor: CGFloat) throws {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }

        // Clamp zoom factor to device limits
        let minZoom = device.minAvailableVideoZoomFactor
        let maxZoom = min(device.maxAvailableVideoZoomFactor, 4.0) // Cap at 4x for quality
        let clampedFactor = min(max(factor, minZoom), maxZoom)

        device.videoZoomFactor = clampedFactor
        AppLogger.info("Applied \(clampedFactor)x digital zoom", category: AppLogger.video)
    }

    // MARK: - Recording

    func startRecording() throws {
        guard !isRecording else { return }

        let outputURL = generateOutputURL()
        currentRecordingURL = outputURL

        movieOutput.startRecording(to: outputURL, recordingDelegate: self)
        isRecording = true
    }

    /// Stop recording and return the URL of the recorded video file.
    ///
    /// This method bridges AVFoundation's delegate-based API to async/await using
    /// CheckedContinuation. A timeout task races against the delegate callback
    /// to prevent memory leaks if the delegate never fires.
    ///
    /// ## Flow:
    /// 1. Create continuation for delegate callback
    /// 2. Call movieOutput.stopRecording() (triggers delegate when done)
    /// 3. Race against 30-second timeout
    /// 4. Return URL from whichever completes first
    ///
    /// - Returns: URL of the saved video file
    /// - Throws: VideoRecorderError if not recording, timeout, or save fails
    func stopRecording() async throws -> URL {
        guard isRecording else {
            throw VideoRecorderError.noRecordingInProgress
        }

        // Use TaskGroup to race recording completion against timeout
        // This prevents continuation memory leak if delegate never fires
        return try await withThrowingTaskGroup(of: URL.self) { group in
            // Task 1: Wait for delegate callback
            group.addTask {
                try await withCheckedThrowingContinuation { continuation in
                    self.recordingContinuation = continuation
                    self.movieOutput.stopRecording()
                }
            }

            // Task 2: Timeout after 30 seconds
            group.addTask {
                try await Task.sleep(nanoseconds: 30_000_000_000)
                throw VideoRecorderError.recordingTimeout
            }

            // Return whichever completes first, cancel the other
            guard let result = try await group.next() else {
                throw VideoRecorderError.recordingFailed("Unexpected error")
            }
            group.cancelAll()
            return result
        }
    }

    private func generateOutputURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videosPath = documentsPath.appendingPathComponent(Constants.Storage.videosDirectory, isDirectory: true)

        // Create directory with file protection if needed
        do {
            try FileManager.default.createDirectory(
                at: videosPath,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
            )
        } catch {
            // Log error but continue - directory might already exist
            AppLogger.warning("Failed to create videos directory: \(error.localizedDescription)", category: AppLogger.video)
        }

        let fileName = "tennis_\(Date().timeIntervalSince1970).mp4"
        return videosPath.appendingPathComponent(fileName)
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension VideoRecorder: AVCaptureFileOutputRecordingDelegate {

    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        isRecording = false

        if let error = error {
            recordingContinuation?.resume(throwing: VideoRecorderError.recordingFailed(error.localizedDescription))
        } else {
            recordingContinuation?.resume(returning: outputFileURL)
        }
        recordingContinuation = nil
    }
}

// MARK: - Thumbnail Generation

extension VideoRecorder {

    /// Generate a thumbnail image from a video URL
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

    /// Get the duration of a video
    static func getVideoDuration(from videoURL: URL) async -> TimeInterval {
        let asset = AVAsset(url: videoURL)
        do {
            let duration = try await asset.load(.duration)
            return CMTimeGetSeconds(duration)
        } catch {
            return 0
        }
    }
}
