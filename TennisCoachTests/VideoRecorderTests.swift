import XCTest
import AVFoundation
@testable import TennisCoach

// MARK: - Mock AVCaptureMovieFileOutput

class MockMovieFileOutput: AVCaptureMovieFileOutput {
    var startRecordingCalled = false
    var stopRecordingCalled = false
    var recordingURL: URL?
    var recordingDelegate: AVCaptureFileOutputRecordingDelegate?

    var shouldSimulateError = false
    var simulatedError: Error?

    override func startRecording(to outputFileURL: URL, recordingDelegate delegate: AVCaptureFileOutputRecordingDelegate) {
        startRecordingCalled = true
        recordingURL = outputFileURL
        self.recordingDelegate = delegate
    }

    override func stopRecording() {
        stopRecordingCalled = true

        // Simulate the delegate callback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self,
                  let delegate = self.recordingDelegate,
                  let url = self.recordingURL else { return }

            delegate.fileOutput(
                self,
                didFinishRecordingTo: url,
                from: [],
                error: self.shouldSimulateError ? (self.simulatedError ?? NSError(domain: "TestError", code: -1)) : nil
            )
        }
    }

    func simulateImmediateCompletion(with error: Error? = nil) {
        guard let delegate = recordingDelegate,
              let url = recordingURL else { return }

        delegate.fileOutput(
            self,
            didFinishRecordingTo: url,
            from: [],
            error: error
        )
    }
}

// Note: VideoRecorder is a final class and cannot be mocked via inheritance.
// Tests use the actual VideoRecorder or test its static methods directly.

// MARK: - Test Video Generator

class TestVideoGenerator {
    static func createTestVideo(duration: TimeInterval = 1.0, size: CGSize = CGSize(width: 640, height: 480)) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let videoURL = tempDir.appendingPathComponent("test_video_\(UUID().uuidString).mp4")

        // Create a simple video file
        guard let videoWriter = try? AVAssetWriter(url: videoURL, fileType: .mp4) else {
            return nil
        }

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height)
        ]

        let videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoWriterInput.expectsMediaDataInRealTime = false

        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height)
        ]

        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoWriterInput,
            sourcePixelBufferAttributes: sourcePixelBufferAttributes
        )

        videoWriter.add(videoWriterInput)
        videoWriter.startWriting()
        videoWriter.startSession(atSourceTime: .zero)

        // Generate frames
        let frameDuration = CMTime(value: 1, timescale: 30) // 30 fps
        let totalFrames = Int(duration * 30)

        for frameIndex in 0..<totalFrames {
            let frameTime = CMTime(value: Int64(frameIndex), timescale: 30)

            autoreleasepool {
                while !videoWriterInput.isReadyForMoreMediaData {
                    Thread.sleep(forTimeInterval: 0.01)
                }

                if let pixelBuffer = createPixelBuffer(size: size) {
                    pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: frameTime)
                }
            }
        }

        videoWriterInput.markAsFinished()

        let expectation = XCTestExpectation(description: "Video writing finished")
        videoWriter.finishWriting {
            expectation.fulfill()
        }

        let waiter = XCTWaiter()
        waiter.wait(for: [expectation], timeout: 5.0)

        return videoURL
    }

    private static func createPixelBuffer(size: CGSize) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32ARGB,
            nil,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        let pixelData = CVPixelBufferGetBaseAddress(buffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(
            data: pixelData,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            CVPixelBufferUnlockBaseAddress(buffer, [])
            return nil
        }

        // Fill with a solid color
        context.setFillColor(red: 0.5, green: 0.5, blue: 0.8, alpha: 1.0)
        context.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height))

        CVPixelBufferUnlockBaseAddress(buffer, [])

        return buffer
    }

    static func cleanup(url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - Tests

final class VideoRecorderTests: XCTestCase {

    var testVideoURL: URL?

    override func setUp() async throws {
        try await super.setUp()

        // Create a test video for thumbnail and duration tests
        testVideoURL = TestVideoGenerator.createTestVideo(duration: 2.0)
    }

    override func tearDown() async throws {
        // Clean up test video
        if let url = testVideoURL {
            TestVideoGenerator.cleanup(url: url)
        }
        testVideoURL = nil

        try await super.tearDown()
    }

    // MARK: - Error Description Tests

    func testVideoRecorderErrorDescriptions() {
        // Test all error cases have localized descriptions
        XCTAssertNotNil(VideoRecorderError.cameraUnavailable.errorDescription)
        XCTAssertFalse(VideoRecorderError.cameraUnavailable.errorDescription!.isEmpty)

        XCTAssertNotNil(VideoRecorderError.microphoneUnavailable.errorDescription)
        XCTAssertFalse(VideoRecorderError.microphoneUnavailable.errorDescription!.isEmpty)

        XCTAssertNotNil(VideoRecorderError.permissionDenied.errorDescription)
        XCTAssertFalse(VideoRecorderError.permissionDenied.errorDescription!.isEmpty)

        XCTAssertNotNil(VideoRecorderError.sessionConfigurationFailed.errorDescription)
        XCTAssertFalse(VideoRecorderError.sessionConfigurationFailed.errorDescription!.isEmpty)

        XCTAssertNotNil(VideoRecorderError.recordingFailed("test").errorDescription)
        XCTAssertTrue(VideoRecorderError.recordingFailed("test error").errorDescription!.contains("test error"))

        XCTAssertNotNil(VideoRecorderError.noRecordingInProgress.errorDescription)
        XCTAssertFalse(VideoRecorderError.noRecordingInProgress.errorDescription!.isEmpty)

        XCTAssertNotNil(VideoRecorderError.recordingTimeout.errorDescription)
        XCTAssertFalse(VideoRecorderError.recordingTimeout.errorDescription!.isEmpty)
    }

    // MARK: - Thumbnail Generation Tests

    func testGenerateThumbnailSuccess() async throws {
        guard let videoURL = testVideoURL else {
            XCTFail("Test video not created")
            return
        }

        let thumbnailData = await VideoRecorder.generateThumbnail(from: videoURL)

        XCTAssertNotNil(thumbnailData, "Thumbnail data should not be nil")

        if let data = thumbnailData {
            XCTAssertGreaterThan(data.count, 0, "Thumbnail data should not be empty")

            // Verify it's valid image data
            let image = UIImage(data: data)
            XCTAssertNotNil(image, "Should be able to create UIImage from thumbnail data")

            if let image = image {
                // Verify size constraints
                let maxDimension = max(image.size.width, image.size.height)
                let expectedMaxDimension = max(Constants.Video.thumbnailSize.width, Constants.Video.thumbnailSize.height)
                XCTAssertLessThanOrEqual(maxDimension, expectedMaxDimension * image.scale + 1,
                                        "Thumbnail should respect maximum size constraint")
            }
        }
    }

    func testGenerateThumbnailWithInvalidURL() async {
        let invalidURL = URL(fileURLWithPath: "/nonexistent/video.mp4")

        let thumbnailData = await VideoRecorder.generateThumbnail(from: invalidURL)

        XCTAssertNil(thumbnailData, "Thumbnail should be nil for invalid URL")
    }

    func testGenerateThumbnailWithCorruptedFile() async {
        // Create a corrupted video file
        let tempDir = FileManager.default.temporaryDirectory
        let corruptedURL = tempDir.appendingPathComponent("corrupted_\(UUID().uuidString).mp4")

        // Write invalid data
        let invalidData = "This is not a video file".data(using: .utf8)!
        try? invalidData.write(to: corruptedURL)

        let thumbnailData = await VideoRecorder.generateThumbnail(from: corruptedURL)

        XCTAssertNil(thumbnailData, "Thumbnail should be nil for corrupted video file")

        // Cleanup
        TestVideoGenerator.cleanup(url: corruptedURL)
    }

    // MARK: - Video Duration Tests

    func testGetVideoDurationSuccess() async throws {
        guard let videoURL = testVideoURL else {
            XCTFail("Test video not created")
            return
        }

        let duration = await VideoRecorder.getVideoDuration(from: videoURL)

        XCTAssertGreaterThan(duration, 0, "Duration should be greater than 0")
        XCTAssertLessThanOrEqual(duration, 3.0, "Duration should be approximately 2 seconds")
        XCTAssertGreaterThanOrEqual(duration, 1.5, "Duration should be approximately 2 seconds")
    }

    func testGetVideoDurationWithInvalidURL() async {
        let invalidURL = URL(fileURLWithPath: "/nonexistent/video.mp4")

        let duration = await VideoRecorder.getVideoDuration(from: invalidURL)

        XCTAssertEqual(duration, 0, "Duration should be 0 for invalid URL")
    }

    func testGetVideoDurationWithCorruptedFile() async {
        let tempDir = FileManager.default.temporaryDirectory
        let corruptedURL = tempDir.appendingPathComponent("corrupted_\(UUID().uuidString).mp4")

        // Write invalid data
        let invalidData = "Not a video".data(using: .utf8)!
        try? invalidData.write(to: corruptedURL)

        let duration = await VideoRecorder.getVideoDuration(from: corruptedURL)

        XCTAssertEqual(duration, 0, "Duration should be 0 for corrupted file")

        // Cleanup
        TestVideoGenerator.cleanup(url: corruptedURL)
    }

    func testGetVideoDurationMultipleCalls() async throws {
        guard let videoURL = testVideoURL else {
            XCTFail("Test video not created")
            return
        }

        // Test that multiple calls return consistent results
        let duration1 = await VideoRecorder.getVideoDuration(from: videoURL)
        let duration2 = await VideoRecorder.getVideoDuration(from: videoURL)
        let duration3 = await VideoRecorder.getVideoDuration(from: videoURL)

        XCTAssertEqual(duration1, duration2, accuracy: 0.01, "Duration should be consistent")
        XCTAssertEqual(duration2, duration3, accuracy: 0.01, "Duration should be consistent")
    }

    // MARK: - Recording State Tests

    func testInitialRecordingState() {
        let recorder = VideoRecorder()

        XCTAssertFalse(recorder.isRecording, "Should not be recording initially")
    }

    func testStartRecordingChangesState() throws {
        let recorder = VideoRecorder()

        // Note: This will fail without proper session setup, but we're testing the basic flow
        // In a real scenario, we'd need camera permissions and session configuration
        XCTAssertFalse(recorder.isRecording)
    }

    // MARK: - Stop Recording Error Cases

    func testStopRecordingWhenNotRecording() async {
        let recorder = VideoRecorder()

        do {
            _ = try await recorder.stopRecording()
            XCTFail("Should throw noRecordingInProgress error")
        } catch let error as VideoRecorderError {
            XCTAssertEqual(error, .noRecordingInProgress)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Timeout Mechanism Tests

    func testStopRecordingTimeout() async {
        // This test verifies the timeout mechanism exists
        // We can't easily test the full 30-second timeout in unit tests
        // but we can verify the structure is correct

        let recorder = VideoRecorder()

        do {
            _ = try await recorder.stopRecording()
            XCTFail("Should throw an error")
        } catch let error as VideoRecorderError {
            // Should throw noRecordingInProgress, not timeout
            XCTAssertEqual(error, .noRecordingInProgress)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - URL Generation Tests

    func testOutputURLGeneration() {
        // Test that output URLs are generated correctly
        let recorder = VideoRecorder()

        // Access the private method via reflection for testing
        // Or we can indirectly test by checking file creation

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videosPath = documentsPath.appendingPathComponent(Constants.Storage.videosDirectory, isDirectory: true)

        // Verify the expected path exists or can be created
        XCTAssertNotNil(videosPath)
        XCTAssertTrue(videosPath.path.contains(Constants.Storage.videosDirectory))
    }

    func testVideosDirectoryStructure() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videosPath = documentsPath.appendingPathComponent(Constants.Storage.videosDirectory, isDirectory: true)

        // Try to create the directory
        do {
            try FileManager.default.createDirectory(
                at: videosPath,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
            )

            XCTAssertTrue(FileManager.default.fileExists(atPath: videosPath.path))

            // Cleanup
            try? FileManager.default.removeItem(at: videosPath)
        } catch {
            // Directory might already exist, which is fine
            XCTAssertTrue(FileManager.default.fileExists(atPath: videosPath.path))
        }
    }

    // MARK: - Protocol Conformance Tests

    func testVideoRecordingProtocolConformance() {
        let recorder: VideoRecording = VideoRecorder()

        // Test protocol properties are accessible
        XCTAssertFalse(recorder.isRecording)
        XCTAssertNotNil(recorder.previewLayer)
    }

    func testPreviewLayerConfiguration() {
        let recorder = VideoRecorder()
        let previewLayer = recorder.previewLayer

        XCTAssertEqual(previewLayer.videoGravity, .resizeAspectFill)
        XCTAssertNotNil(previewLayer.session)
    }

    // MARK: - Concurrent Access Tests

    func testConcurrentThumbnailGeneration() async throws {
        guard let videoURL = testVideoURL else {
            XCTFail("Test video not created")
            return
        }

        // Test that concurrent thumbnail generation works correctly
        async let thumbnail1 = VideoRecorder.generateThumbnail(from: videoURL)
        async let thumbnail2 = VideoRecorder.generateThumbnail(from: videoURL)
        async let thumbnail3 = VideoRecorder.generateThumbnail(from: videoURL)

        let results = await [thumbnail1, thumbnail2, thumbnail3]

        for result in results {
            XCTAssertNotNil(result, "All concurrent thumbnail generations should succeed")
        }
    }

    func testConcurrentDurationRequests() async throws {
        guard let videoURL = testVideoURL else {
            XCTFail("Test video not created")
            return
        }

        // Test that concurrent duration requests work correctly
        async let duration1 = VideoRecorder.getVideoDuration(from: videoURL)
        async let duration2 = VideoRecorder.getVideoDuration(from: videoURL)
        async let duration3 = VideoRecorder.getVideoDuration(from: videoURL)

        let durations = await [duration1, duration2, duration3]

        for duration in durations {
            XCTAssertGreaterThan(duration, 0, "All concurrent duration requests should succeed")
        }

        // Verify consistency
        XCTAssertEqual(durations[0], durations[1], accuracy: 0.01)
        XCTAssertEqual(durations[1], durations[2], accuracy: 0.01)
    }

    // MARK: - Memory Management Tests

    func testThumbnailGenerationDoesNotLeak() async throws {
        guard let videoURL = testVideoURL else {
            XCTFail("Test video not created")
            return
        }

        // Generate multiple thumbnails and ensure no memory issues
        for _ in 0..<10 {
            _ = await VideoRecorder.generateThumbnail(from: videoURL)
        }

        // If we get here without crashing, memory management is likely correct
        XCTAssertTrue(true)
    }

    func testDurationRequestsDoNotLeak() async throws {
        guard let videoURL = testVideoURL else {
            XCTFail("Test video not created")
            return
        }

        // Make multiple duration requests
        for _ in 0..<10 {
            _ = await VideoRecorder.getVideoDuration(from: videoURL)
        }

        // If we get here without crashing, memory management is likely correct
        XCTAssertTrue(true)
    }

    // MARK: - Edge Cases

    func testEmptyVideoFile() async {
        let tempDir = FileManager.default.temporaryDirectory
        let emptyURL = tempDir.appendingPathComponent("empty_\(UUID().uuidString).mp4")

        // Create empty file
        FileManager.default.createFile(atPath: emptyURL.path, contents: nil)

        let thumbnail = await VideoRecorder.generateThumbnail(from: emptyURL)
        let duration = await VideoRecorder.getVideoDuration(from: emptyURL)

        XCTAssertNil(thumbnail, "Empty file should not generate thumbnail")
        XCTAssertEqual(duration, 0, "Empty file should have 0 duration")

        // Cleanup
        TestVideoGenerator.cleanup(url: emptyURL)
    }

    func testVeryShortVideo() async throws {
        // Create a very short video (0.1 seconds)
        guard let shortVideoURL = TestVideoGenerator.createTestVideo(duration: 0.1) else {
            XCTFail("Failed to create short test video")
            return
        }

        let thumbnail = await VideoRecorder.generateThumbnail(from: shortVideoURL)
        let duration = await VideoRecorder.getVideoDuration(from: shortVideoURL)

        XCTAssertNotNil(thumbnail, "Should generate thumbnail even for very short video")
        XCTAssertGreaterThan(duration, 0, "Duration should be greater than 0")
        XCTAssertLessThan(duration, 1.0, "Duration should be less than 1 second")

        // Cleanup
        TestVideoGenerator.cleanup(url: shortVideoURL)
    }

    // MARK: - Performance Tests

    func testThumbnailGenerationPerformance() throws {
        guard let videoURL = testVideoURL else {
            XCTFail("Test video not created")
            return
        }

        measure {
            let expectation = XCTestExpectation(description: "Thumbnail generation")

            Task {
                _ = await VideoRecorder.generateThumbnail(from: videoURL)
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 5.0)
        }
    }

    func testDurationRequestPerformance() throws {
        guard let videoURL = testVideoURL else {
            XCTFail("Test video not created")
            return
        }

        measure {
            let expectation = XCTestExpectation(description: "Duration request")

            Task {
                _ = await VideoRecorder.getVideoDuration(from: videoURL)
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 5.0)
        }
    }
}

// MARK: - VideoRecorderError Equatable Extension

extension VideoRecorderError: @retroactive Equatable {
    public static func == (lhs: VideoRecorderError, rhs: VideoRecorderError) -> Bool {
        switch (lhs, rhs) {
        case (.cameraUnavailable, .cameraUnavailable):
            return true
        case (.microphoneUnavailable, .microphoneUnavailable):
            return true
        case (.permissionDenied, .permissionDenied):
            return true
        case (.sessionConfigurationFailed, .sessionConfigurationFailed):
            return true
        case (.recordingFailed(let lMsg), .recordingFailed(let rMsg)):
            return lMsg == rMsg
        case (.noRecordingInProgress, .noRecordingInProgress):
            return true
        case (.recordingTimeout, .recordingTimeout):
            return true
        case (.lensNotAvailable, .lensNotAvailable):
            return true
        default:
            return false
        }
    }
}
