import SwiftUI
import SwiftData
import AVFoundation
import Combine

@MainActor
final class RecordViewModel: ObservableObject {

    // MARK: - Published Properties

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

    // MARK: - Setup

    func setup() async {
        let recorder = VideoRecorder()
        self.videoRecorder = recorder

        do {
            try await recorder.startSession()
        } catch {
            self.error = error.localizedDescription
        }
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
            return
        }

        do {
            try recorder.startRecording()
            isRecording = true
            recordingDuration = 0
            startDurationTimer()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func stopRecording(modelContext: ModelContext) async {
        guard let recorder = videoRecorder else { return }

        stopDurationTimer()
        isProcessing = true

        do {
            let videoURL = try await recorder.stopRecording()
            isRecording = false

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

            isProcessing = false
            savedVideo = video

        } catch {
            isRecording = false
            isProcessing = false
            self.error = error.localizedDescription
        }
    }

    // MARK: - Timer

    private func startDurationTimer() {
        // Use Task-based timer to avoid race conditions with Timer + Task
        timerTask = Task { [weak self] in
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
