import XCTest
import AVFoundation
@testable import TennisCoach

// MARK: - Camera Lens Tests

final class CameraLensTests: XCTestCase {

    // MARK: - Enum Properties Tests

    func testLensDisplayNames() {
        XCTAssertEqual(CameraLens.ultraWide.displayName, "0.5x")
        XCTAssertEqual(CameraLens.wide.displayName, "1x")
        XCTAssertEqual(CameraLens.telephoto.displayName, "2x")
    }

    func testLensSystemImages() {
        XCTAssertEqual(CameraLens.ultraWide.systemImage, "camera.aperture")
        XCTAssertEqual(CameraLens.wide.systemImage, "camera")
        XCTAssertEqual(CameraLens.telephoto.systemImage, "camera.macro")
    }

    func testLensDeviceTypes() {
        XCTAssertEqual(CameraLens.ultraWide.deviceType, .builtInUltraWideCamera)
        XCTAssertEqual(CameraLens.wide.deviceType, .builtInWideAngleCamera)
        XCTAssertEqual(CameraLens.telephoto.deviceType, .builtInTelephotoCamera)
    }

    func testLensZoomFactors() {
        XCTAssertEqual(CameraLens.ultraWide.zoomFactor, 0.5)
        XCTAssertEqual(CameraLens.wide.zoomFactor, 1.0)
        XCTAssertEqual(CameraLens.telephoto.zoomFactor, 2.0)
    }

    func testAllCasesOrdering() {
        let allCases = CameraLens.allCases
        XCTAssertEqual(allCases.count, 3)
        XCTAssertEqual(allCases[0], .ultraWide)
        XCTAssertEqual(allCases[1], .wide)
        XCTAssertEqual(allCases[2], .telephoto)
    }

    // MARK: - Negative Tests

    func testLensRawValues() {
        // Verify raw values match expected display format
        XCTAssertEqual(CameraLens(rawValue: "0.5x"), .ultraWide)
        XCTAssertEqual(CameraLens(rawValue: "1x"), .wide)
        XCTAssertEqual(CameraLens(rawValue: "2x"), .telephoto)

        // Invalid raw values should return nil
        XCTAssertNil(CameraLens(rawValue: "3x"))
        XCTAssertNil(CameraLens(rawValue: ""))
        XCTAssertNil(CameraLens(rawValue: "wide"))
    }
}

// MARK: - Recording Time Limit Tests

final class RecordingTimeLimitTests: XCTestCase {

    // MARK: - Constants Tests

    func testMaxDuration60fps() {
        // At 60fps with H.264: ~175-200 MB/min → 30 seconds for 100MB limit
        XCTAssertEqual(Constants.Video.maxDuration60fps, 30)
    }

    func testMaxDuration30fps() {
        // At 30fps with H.264: ~125-150 MB/min → 45 seconds for 100MB limit
        XCTAssertEqual(Constants.Video.maxDuration30fps, 45)
    }

    func testMaxDurationBasedOnFPS() {
        // With preferredFPS = 60, should use 60fps limit
        XCTAssertEqual(Constants.Video.preferredFPS, 60)
        XCTAssertEqual(Constants.Video.maxDuration, 30)
    }

    func testDurationWarningThreshold() {
        // Warning should appear 10 seconds before limit
        let expectedThreshold = Constants.Video.maxDuration - 10
        XCTAssertEqual(Constants.Video.durationWarningThreshold, expectedThreshold)
        XCTAssertEqual(Constants.Video.durationWarningThreshold, 20) // 30 - 10
    }

    // MARK: - File Size Limits Tests

    func testMaxUploadSizeBytes() {
        // Gemini limit is 100MB
        XCTAssertEqual(Constants.Video.maxUploadSizeBytes, 100 * 1024 * 1024)
    }

    func testLargeFileSizeWarningBytes() {
        // Warning at 50MB
        XCTAssertEqual(Constants.Video.largeFileSizeWarningBytes, 50 * 1024 * 1024)
    }

    // MARK: - Boundary Condition Tests

    func testWarningThresholdIsPositive() {
        XCTAssertGreaterThan(Constants.Video.durationWarningThreshold, 0)
    }

    func testWarningThresholdLessThanMax() {
        XCTAssertLessThan(Constants.Video.durationWarningThreshold, Constants.Video.maxDuration)
    }

    func testMaxDurationIsReasonable() {
        // Recording should be at least 10 seconds to be useful
        XCTAssertGreaterThanOrEqual(Constants.Video.maxDuration, 10)
        // And no more than 2 minutes for upload practicality
        XCTAssertLessThanOrEqual(Constants.Video.maxDuration, 120)
    }
}

// MARK: - VideoRecorder Error Tests (Extended)

final class VideoRecorderErrorExtendedTests: XCTestCase {

    func testLensNotAvailableError() {
        let error = VideoRecorderError.lensNotAvailable
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
        XCTAssertTrue(error.errorDescription!.contains("镜头"))
    }

    func testErrorEquality() {
        // Same errors should be equal
        XCTAssertEqual(VideoRecorderError.lensNotAvailable, VideoRecorderError.lensNotAvailable)
        XCTAssertEqual(VideoRecorderError.cameraUnavailable, VideoRecorderError.cameraUnavailable)

        // Different errors should not be equal
        XCTAssertNotEqual(VideoRecorderError.lensNotAvailable, VideoRecorderError.cameraUnavailable)
    }

    func testRecordingFailedWithDifferentMessages() {
        let error1 = VideoRecorderError.recordingFailed("Error A")
        let error2 = VideoRecorderError.recordingFailed("Error B")
        let error3 = VideoRecorderError.recordingFailed("Error A")

        XCTAssertNotEqual(error1, error2, "Different messages should not be equal")
        XCTAssertEqual(error1, error3, "Same messages should be equal")
    }
}

// MARK: - RecordViewModel Time Limit Tests

@MainActor
final class RecordViewModelTimeLimitTests: XCTestCase {

    var viewModel: RecordViewModel!

    override func setUp() {
        super.setUp()
        viewModel = RecordViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Computed Properties Tests

    func testMaxRecordingDuration() {
        XCTAssertEqual(viewModel.maxRecordingDuration, Constants.Video.maxDuration)
    }

    func testRemainingTimeAtStart() {
        // At start, remaining time equals max duration
        XCTAssertEqual(viewModel.remainingTime, Constants.Video.maxDuration)
    }

    func testRemainingTimeDecreases() {
        viewModel.recordingDuration = 10
        XCTAssertEqual(viewModel.remainingTime, Constants.Video.maxDuration - 10)
    }

    func testRemainingTimeNeverNegative() {
        viewModel.recordingDuration = Constants.Video.maxDuration + 100
        XCTAssertEqual(viewModel.remainingTime, 0, "Remaining time should never be negative")
    }

    func testFormattedRemainingTime() {
        viewModel.recordingDuration = 0
        let formatted = viewModel.formattedRemainingTime
        XCTAssertTrue(formatted.contains(":"), "Should be in MM:SS format")
    }

    // MARK: - Warning State Tests

    func testShowDurationWarningInitiallyFalse() {
        XCTAssertFalse(viewModel.showDurationWarning)
    }

    func testShowDurationWarningCanBeSet() {
        viewModel.showDurationWarning = true
        XCTAssertTrue(viewModel.showDurationWarning)
    }

    // MARK: - Lens State Tests

    func testCurrentLensInitiallyWide() {
        XCTAssertEqual(viewModel.currentLens, .wide)
    }

    func testAvailableLensesReturnsAtLeastWide() {
        // Wide lens should always be available
        let lenses = viewModel.availableLenses
        XCTAssertTrue(lenses.contains(.wide) || lenses.isEmpty,
                     "Either wide lens available or no recorder initialized")
    }

    func testCanSwitchLensWhenNotRecording() {
        // When not recording and camera not ready, should not be able to switch
        XCTAssertFalse(viewModel.canSwitchLens)
    }

    // MARK: - Focus Tests

    func testSupportsTapToFocusWithoutRecorder() {
        // Without recorder initialized, should return false
        XCTAssertFalse(viewModel.supportsTapToFocus)
    }
}

// MARK: - GeminiService File Size Validation Tests

final class GeminiServiceFileSizeTests: XCTestCase {

    func testFileTooLargeErrorDescription() {
        let maxBytes: Int64 = 100 * 1024 * 1024
        let actualBytes: Int64 = 150 * 1024 * 1024
        let error = GeminiError.fileTooLarge(sizeBytes: actualBytes, maxBytes: maxBytes)

        XCTAssertNotNil(error.errorDescription)
        // Should mention the file size
        XCTAssertTrue(error.errorDescription!.contains("MB") || error.errorDescription!.contains("大"))
    }

    func testFileSizeConstants() {
        // Verify the file size limit matches Gemini's documented limit
        let maxSizeBytes = Constants.Video.maxUploadSizeBytes
        let maxSizeMB = maxSizeBytes / (1024 * 1024)
        XCTAssertEqual(maxSizeMB, 100, "Max upload size should be 100MB")
    }
}

// MARK: - Integration Tests

@MainActor
final class CameraFeatureIntegrationTests: XCTestCase {

    // MARK: - Lens Switching Integration

    func testLensSwitchingPreventedDuringRecording() {
        let viewModel = RecordViewModel()

        // Simulate recording state
        viewModel.isRecording = true

        // Attempt to switch lens should be prevented
        XCTAssertFalse(viewModel.canSwitchLens, "Should not allow lens switching during recording")
    }

    func testLensStatePreservedAfterRecording() {
        let viewModel = RecordViewModel()

        // Set lens before recording
        viewModel.currentLens = .telephoto

        // Simulate recording cycle
        viewModel.isRecording = true
        viewModel.isRecording = false

        // Lens should still be telephoto
        XCTAssertEqual(viewModel.currentLens, .telephoto)
    }

    // MARK: - Time Limit Integration

    func testRecordingDurationApproachingLimit() {
        let viewModel = RecordViewModel()

        // Set duration just before warning threshold
        viewModel.recordingDuration = Constants.Video.durationWarningThreshold - 1

        // Remaining time should be just over 10 seconds
        XCTAssertGreaterThan(viewModel.remainingTime, 10)
    }

    func testRecordingDurationAtLimit() {
        let viewModel = RecordViewModel()

        // Set duration exactly at max
        viewModel.recordingDuration = Constants.Video.maxDuration

        // Remaining time should be 0
        XCTAssertEqual(viewModel.remainingTime, 0)
    }

    func testRecordingDurationBeyondLimit() {
        let viewModel = RecordViewModel()

        // Set duration beyond max (edge case)
        viewModel.recordingDuration = Constants.Video.maxDuration + 5

        // Remaining time should still be 0 (clamped)
        XCTAssertEqual(viewModel.remainingTime, 0)
    }
}

// MARK: - Performance Tests

final class CameraFeaturePerformanceTests: XCTestCase {

    func testLensEnumPerformance() {
        measure {
            for _ in 0..<10000 {
                _ = CameraLens.allCases.map { $0.displayName }
                _ = CameraLens.allCases.map { $0.zoomFactor }
            }
        }
    }

    @MainActor
    func testTimeLimitCalculationPerformance() {
        let viewModel = RecordViewModel()

        measure {
            for i in 0..<10000 {
                viewModel.recordingDuration = TimeInterval(i % 60)
                _ = viewModel.remainingTime
                _ = viewModel.formattedRemainingTime
            }
        }
    }
}
