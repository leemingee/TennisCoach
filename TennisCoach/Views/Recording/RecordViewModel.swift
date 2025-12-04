import SwiftUI
import SwiftData
import AVFoundation
import Combine
import Photos

// MARK: - Camera State

enum CameraState: Equatable {
    case initializing
    case ready
    case recording
    case error(String)

    var isReady: Bool {
        if case .ready = self { return true }
        return false
    }

    var isRecording: Bool {
        if case .recording = self { return true }
        return false
    }
}

@MainActor
final class RecordViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var cameraState: CameraState = .initializing
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var error: String?
    @Published var savedVideo: Video?

    // MARK: - Private Properties

    private var videoRecorder: VideoRecorder?
    private var timerTask: Task<Void, Never>?

    var previewLayer: CALayer {
        videoRecorder?.previewLayer ?? CALayer()
    }

    /// Check if camera is ready for recording
    var canRecord: Bool {
        cameraState.isReady && !isProcessing
    }

    // MARK: - Setup

    func setup() async {
        cameraState = .initializing

        let recorder = VideoRecorder()
        self.videoRecorder = recorder

        do {
            try await recorder.startSession()

            // Wait for session to actually be running (up to 2 seconds)
            var attempts = 0
            while !recorder.isSessionRunning && attempts < 20 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                attempts += 1
            }

            if recorder.isSessionRunning {
                cameraState = .ready
            } else {
                cameraState = .error("相机启动超时，请重试")
            }
        } catch {
            cameraState = .error(error.localizedDescription)
            self.error = error.localizedDescription
        }
    }

    // MARK: - Session Management

    /// Resume camera session (called when view appears)
    func resumeSession() async {
        guard let recorder = videoRecorder else {
            // First time setup
            await setup()
            return
        }

        if !recorder.isSessionRunning {
            cameraState = .initializing
            await recorder.resumeSession()

            // Wait for session to start
            var attempts = 0
            while !recorder.isSessionRunning && attempts < 20 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                attempts += 1
            }

            cameraState = recorder.isSessionRunning ? .ready : .error("相机恢复失败")
        }
    }

    /// Pause camera session (called when view disappears)
    func pauseSession() {
        // Don't stop the session, just mark as not recording
        // The session will continue running for quick resume
    }

    // MARK: - Recording Control

    func toggleRecording(modelContext: ModelContext) async {
        if isRecording {
            await stopRecording(modelContext: modelContext)
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        guard let recorder = videoRecorder else {
            error = "录制器未初始化"
            cameraState = .error("录制器未初始化")
            return
        }

        guard recorder.isSessionRunning else {
            error = "相机未就绪，请稍候"
            cameraState = .error("相机未就绪")
            return
        }

        do {
            try recorder.startRecording()
            isRecording = true
            cameraState = .recording
            recordingDuration = 0
            startDurationTimer()
        } catch {
            self.error = error.localizedDescription
            cameraState = .error(error.localizedDescription)
        }
    }

    private func stopRecording(modelContext: ModelContext) async {
        guard let recorder = videoRecorder else { return }

        stopDurationTimer()
        isProcessing = true

        do {
            let videoURL = try await recorder.stopRecording()
            isRecording = false
            cameraState = .ready

            // Create Video model - use .path instead of .absoluteString for proper file path handling
            let video = Video(
                localPath: videoURL.path,
                duration: recordingDuration
            )

            // Generate thumbnail in background
            if let thumbnailData = await VideoRecorder.generateThumbnail(from: videoURL) {
                video.thumbnailData = thumbnailData
            }

            // Get accurate duration
            let duration = await VideoRecorder.getVideoDuration(from: videoURL)
            video.duration = duration

            // Save to database
            modelContext.insert(video)
            try modelContext.save()

            // Auto-save to Photos Library (non-blocking)
            Task {
                await saveToPhotosLibrary(videoURL: videoURL)
            }

            isProcessing = false
            savedVideo = video

        } catch {
            isRecording = false
            isProcessing = false
            cameraState = .ready
            self.error = error.localizedDescription
        }
    }

    // MARK: - Photos Library

    /// Save video to Photos Library (auto-save feature)
    private func saveToPhotosLibrary(videoURL: URL) async {
        do {
            // Request authorization if needed
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard status == .authorized || status == .limited else {
                // Don't show error for auto-save, user can manually save later
                AppLogger.warning("Photos Library access denied for auto-save")
                return
            }

            // Save to Photos Library
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(
                    with: .video,
                    fileURL: videoURL,
                    options: nil
                )
            }

            AppLogger.info("Video auto-saved to Photos Library")
        } catch {
            AppLogger.error("Failed to auto-save video to Photos: \(error)")
        }
    }

    // MARK: - Timer

    private func startDurationTimer() {
        // Use Task-based timer with MainActor to avoid race conditions
        timerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                guard !Task.isCancelled else { break }
                self?.recordingDuration += 1
            }
        }
    }

    private func stopDurationTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    // MARK: - Error Handling

    func dismissError() {
        error = nil
    }

    // MARK: - Cleanup

    deinit {
        timerTask?.cancel()
        videoRecorder?.stopSession()
    }
}
