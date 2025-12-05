import SwiftUI
import SwiftData
import AVFoundation
import Combine
import Photos

// MARK: - Camera State

/// State machine for camera lifecycle.
///
/// The camera progresses through states:
/// ```
/// initializing → ready ⟷ recording
///       ↓          ↓
///    error ←───────┘
/// ```
///
/// UI binds to this state to show appropriate overlays and enable/disable controls.
enum CameraState: Equatable {
    case initializing  // Camera session starting up
    case ready         // Session running, can start recording
    case recording     // Currently recording video
    case error(String) // Something went wrong, show message

    var isReady: Bool {
        if case .ready = self { return true }
        return false
    }

    var isRecording: Bool {
        if case .recording = self { return true }
        return false
    }
}

/// ViewModel managing the Recording screen state.
///
/// ## Responsibilities:
/// - Camera session lifecycle (setup, pause, resume)
/// - Recording start/stop with duration timer
/// - Video persistence to SwiftData and Photos Library
/// - Camera state machine for UI binding
///
/// ## Threading:
/// - Marked @MainActor for safe @Published property updates
/// - Timer uses Task with @MainActor to avoid race conditions
/// - VideoRecorder operations are async
///
/// ## Key Patterns:
/// - Uses CameraState enum for clear UI state binding
/// - Saves video to both app storage (SwiftData) and Photos Library
/// - Generates thumbnail asynchronously after recording
@MainActor
final class RecordViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var cameraState: CameraState = .initializing
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var error: String?
    @Published var savedVideo: Video?
    @Published var showDurationWarning = false  // Shows when approaching time limit
    @Published var currentLens: CameraLens = .wide  // Current camera lens

    // MARK: - Private Properties

    private var videoRecorder: VideoRecorder?
    private var timerTask: Task<Void, Never>?
    private var modelContextForAutoStop: ModelContext?  // Store for auto-stop

    var previewLayer: CALayer {
        videoRecorder?.previewLayer ?? CALayer()
    }

    /// Check if camera is ready for recording
    var canRecord: Bool {
        cameraState.isReady && !isProcessing
    }

    /// Maximum recording duration based on Gemini upload limits
    var maxRecordingDuration: TimeInterval {
        Constants.Video.maxDuration
    }

    /// Remaining recording time
    var remainingTime: TimeInterval {
        max(0, maxRecordingDuration - recordingDuration)
    }

    /// Formatted remaining time for display (e.g., "0:25")
    var formattedRemainingTime: String {
        let remaining = Int(remainingTime)
        return String(format: "%d:%02d", remaining / 60, remaining % 60)
    }

    /// Available camera lenses on this device
    var availableLenses: [CameraLens] {
        videoRecorder?.availableLenses ?? [.wide]
    }

    /// Check if lens switching is allowed (not recording, camera ready)
    var canSwitchLens: Bool {
        !isRecording && cameraState.isReady
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
            // Store context for auto-stop functionality
            modelContextForAutoStop = modelContext
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

    /// Start a 1-second interval timer to track recording duration.
    ///
    /// ## Why Task-based timer instead of Timer.publish?
    /// - Automatically cooperative with Swift Concurrency
    /// - Cancellable via Task.cancel()
    /// - @MainActor ensures thread-safe @Published updates
    ///
    /// ## Race Condition Fix (P0):
    /// The @MainActor annotation on the Task closure ensures recordingDuration
    /// is always updated on the main thread, fixing the race condition that
    /// previously caused crashes when Timer fired on a background queue.
    ///
    /// ## Duration Limit Feature:
    /// The timer now monitors duration and:
    /// - Shows warning when approaching limit (10 seconds before)
    /// - Auto-stops recording when limit is reached
    private func startDurationTimer() {
        showDurationWarning = false

        timerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                guard !Task.isCancelled, let self = self else { break }

                self.recordingDuration += 1

                // Check if approaching duration limit (10 seconds warning)
                let warningThreshold = Constants.Video.durationWarningThreshold
                if self.recordingDuration >= warningThreshold && !self.showDurationWarning {
                    self.showDurationWarning = true
                    AppLogger.info("Recording approaching time limit", category: AppLogger.video)
                }

                // Check if duration limit reached - auto-stop
                let maxDuration = Constants.Video.maxDuration
                if self.recordingDuration >= maxDuration {
                    AppLogger.info("Recording reached time limit, auto-stopping", category: AppLogger.video)
                    // Auto-stop recording
                    if let context = self.modelContextForAutoStop {
                        await self.stopRecording(modelContext: context)
                    }
                    break
                }
            }
        }
    }

    private func stopDurationTimer() {
        timerTask?.cancel()
        timerTask = nil
        showDurationWarning = false
    }

    // MARK: - Lens Switching

    /// Switch to a different camera lens.
    /// - Parameter lens: The desired camera lens
    func switchLens(to lens: CameraLens) {
        guard canSwitchLens else {
            AppLogger.warning("Cannot switch lens: recording or camera not ready", category: AppLogger.video)
            return
        }

        do {
            try videoRecorder?.switchLens(to: lens)
            currentLens = lens
        } catch {
            self.error = error.localizedDescription
        }
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
