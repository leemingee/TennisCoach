import AVFoundation
import UIKit

// MARK: - Protocol

/// Protocol for video recording functionality
protocol VideoRecording: AnyObject {
    var isRecording: Bool { get }
    var previewLayer: AVCaptureVideoPreviewLayer { get }

    func requestPermissions() async -> Bool
    func startSession() async throws
    func stopSession()
    func startRecording() throws
    func stopRecording() async throws -> URL
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
        }
    }
}

// MARK: - Implementation

final class VideoRecorder: NSObject, VideoRecording {

    // MARK: - Properties

    private let captureSession = AVCaptureSession()
    private var movieOutput = AVCaptureMovieFileOutput()
    private var currentRecordingURL: URL?
    private var recordingContinuation: CheckedContinuation<URL, Error>?

    private(set) var isRecording = false

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

    private func configureSession() throws {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        // Set session preset for high quality
        captureSession.sessionPreset = .high

        // Add video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw VideoRecorderError.cameraUnavailable
        }

        // Configure for 60fps if supported
        try configureFrameRate(device: videoDevice, desiredFPS: Constants.Video.preferredFPS)

        let videoInput = try AVCaptureDeviceInput(device: videoDevice)
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }

        // Add audio input
        guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
            throw VideoRecorderError.microphoneUnavailable
        }

        let audioInput = try AVCaptureDeviceInput(device: audioDevice)
        if captureSession.canAddInput(audioInput) {
            captureSession.addInput(audioInput)
        }

        // Add movie output
        if captureSession.canAddOutput(movieOutput) {
            captureSession.addOutput(movieOutput)

            // Configure video stabilization
            if let connection = movieOutput.connection(with: .video) {
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = .auto
                }
            }
        }
    }

    private func configureFrameRate(device: AVCaptureDevice, desiredFPS: Float) throws {
        var bestFormat: AVCaptureDevice.Format?
        var bestFrameRateRange: AVFrameRateRange?

        for format in device.formats {
            for range in format.videoSupportedFrameRateRanges {
                if range.maxFrameRate >= Float64(desiredFPS) {
                    if bestFrameRateRange == nil || range.maxFrameRate < bestFrameRateRange!.maxFrameRate {
                        bestFormat = format
                        bestFrameRateRange = range
                    }
                }
            }
        }

        if let format = bestFormat, let range = bestFrameRateRange {
            try device.lockForConfiguration()
            device.activeFormat = format
            device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(min(Float64(desiredFPS), range.maxFrameRate)))
            device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(min(Float64(desiredFPS), range.maxFrameRate)))
            device.unlockForConfiguration()
        }
    }

    // MARK: - Recording

    func startRecording() throws {
        guard !isRecording else { return }

        let outputURL = generateOutputURL()
        currentRecordingURL = outputURL

        movieOutput.startRecording(to: outputURL, recordingDelegate: self)
        isRecording = true
    }

    func stopRecording() async throws -> URL {
        guard isRecording else {
            throw VideoRecorderError.noRecordingInProgress
        }

        // Use timeout to prevent continuation memory leak if delegate never fires
        return try await withThrowingTaskGroup(of: URL.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { continuation in
                    self.recordingContinuation = continuation
                    self.movieOutput.stopRecording()
                }
            }

            group.addTask {
                // Timeout after 30 seconds
                try await Task.sleep(nanoseconds: 30_000_000_000)
                throw VideoRecorderError.recordingTimeout
            }

            // Return first successful result, cancel the other
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
            print("Failed to create videos directory: \(error)")
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
