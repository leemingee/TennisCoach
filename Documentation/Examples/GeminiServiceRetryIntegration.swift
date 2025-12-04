import Foundation

// MARK: - GeminiService Retry Integration Example

/// This file demonstrates the retry logic integration in GeminiService
/// and how it handles different failure scenarios.

// MARK: - Key Features

/**
 The GeminiService now includes automatic retry logic with:

 1. Exponential Backoff
    - Initial delay: 1 second
    - Multiplier: 2x each attempt
    - Maximum delay: 30 seconds
    - Random jitter to prevent thundering herd

 2. Smart Retry Decisions
    - Network errors (timeout, connection lost) → Retry
    - Server errors (5xx) → Retry
    - Rate limiting (429) → Retry with delay from Retry-After header
    - Client errors (400, 401, 403) → Don't retry
    - Invalid API key → Don't retry

 3. Cancellation Support
    - All operations can be cancelled
    - Cancellation stops pending retries immediately

 4. Different Policies for Different Operations
    - Upload initialization: Default policy (3 attempts)
    - File processing: Custom policy (30 attempts, slower backoff)
    - Streaming requests: Conservative policy (2 attempts)
 */

// MARK: - Usage Example

class GeminiServiceRetryDemo {

    let service = GeminiService()

    // MARK: - Upload with Automatic Retry

    /// Upload a video with automatic retry on transient failures
    func uploadVideoExample() async {
        let videoURL = URL(fileURLWithPath: "/path/to/tennis-serve.mp4")

        do {
            let fileUri = try await service.uploadVideo(
                localURL: videoURL,
                progressHandler: { progress in
                    print("Upload: \(Int(progress * 100))%")
                }
            )
            print("✅ Upload successful: \(fileUri)")

        } catch let error as GeminiError {
            handleGeminiError(error)
        } catch {
            print("❌ Unexpected error: \(error)")
        }
    }

    // MARK: - Analysis with Retry

    /// Analyze video with automatic retry on connection issues
    func analyzeVideoExample() async {
        let fileUri = "files/abc123"

        do {
            let stream = try await service.analyzeVideo(
                fileUri: fileUri,
                prompt: "Analyze this tennis serve technique"
            )

            print("📊 Receiving analysis...")
            var fullResponse = ""

            for try await chunk in stream {
                fullResponse += chunk
                print(chunk, terminator: "")
            }

            print("\n✅ Analysis complete")

        } catch let error as GeminiError {
            handleGeminiError(error)
        } catch {
            print("❌ Unexpected error: \(error)")
        }
    }

    // MARK: - Error Handling

    /// Handle different types of GeminiError
    private func handleGeminiError(_ error: GeminiError) {
        switch error {
        case .invalidAPIKey:
            print("❌ Invalid API key - no retry attempted")
            print("   Please check your API configuration")

        case .networkError(let underlying):
            print("❌ Network error after \(RetryPolicy.default.maxAttempts) retries")
            print("   Details: \(underlying.localizedDescription)")

        case .httpError(let statusCode, _):
            if statusCode == 429 {
                print("❌ Rate limited even after retry with backoff")
                print("   Please try again later")
            } else if (500...599).contains(statusCode) {
                print("❌ Server error \(statusCode) after retries")
                print("   The service may be temporarily unavailable")
            } else {
                print("❌ HTTP error \(statusCode) - not retried")
            }

        case .fileProcessing:
            print("❌ File processing timeout after 30 attempts")
            print("   The file may be too large or corrupted")

        case .uploadFailed(let message):
            print("❌ Upload failed: \(message)")

        case .analysisFailed(let message):
            print("❌ Analysis failed: \(message)")

        case .invalidResponse:
            print("❌ Invalid response from server after retries")

        case .uploadCancelled:
            print("⚠️ Upload was cancelled by user")
        }
    }

    // MARK: - Cancellable Upload

    /// Upload that can be cancelled during retry attempts
    func cancellableUploadExample() async {
        let videoURL = URL(fileURLWithPath: "/path/to/video.mp4")

        let uploadTask = Task {
            try await service.uploadVideo(localURL: videoURL)
        }

        // Simulate user cancellation after 3 seconds
        Task {
            try await Task.sleep(nanoseconds: 3_000_000_000)
            print("⚠️ Cancelling upload...")
            uploadTask.cancel()
        }

        do {
            let result = try await uploadTask.value
            print("✅ Upload completed: \(result)")
        } catch is CancellationError {
            print("⚠️ Upload cancelled successfully")
        } catch {
            print("❌ Upload failed: \(error)")
        }
    }
}

// MARK: - Implementation Details

/**
 ## How Retry Works in GeminiService

 ### 1. Upload Video Flow

 ```
 uploadVideo()
    ↓
 [Step 1] Start resumable upload → executeWithRetry()
    ↓                                  - Max 3 attempts
    ↓                                  - 1s, 2s, 4s delays
 [Step 2] Upload file data → uploadWithRetry()
    ↓                          - Max 3 attempts
    ↓                          - Smart error handling
 [Step 3] Wait for processing → waitForFileProcessing()
    ↓                             - Max 30 attempts
    ↓                             - 1s initial, 3s max delay
 Return fileUri ✅
 ```

 ### 2. Retry Decision Matrix

 | Error Type          | HTTP Code | Retry? | Reason                    |
 |---------------------|-----------|--------|---------------------------|
 | Network timeout     | -         | Yes    | Transient                 |
 | Connection lost     | -         | Yes    | Transient                 |
 | No internet         | -         | Yes    | May recover               |
 | Server error        | 500-599   | Yes    | Server may recover        |
 | Rate limited        | 429       | Yes    | With Retry-After delay    |
 | Bad request         | 400       | No     | Client error              |
 | Unauthorized        | 401       | No     | Invalid credentials       |
 | Forbidden           | 403       | No     | No access                 |
 | Not found           | 404       | No     | Resource doesn't exist    |
 | Invalid API key     | -         | No     | Configuration error       |
 | Upload cancelled    | -         | No     | User action               |

 ### 3. Exponential Backoff Example

 For default policy with initial delay of 1s and multiplier of 2:

 ```
 Attempt 1: Immediate
 Attempt 2: Wait 1.0s ± 10% jitter  = 0.9s - 1.1s
 Attempt 3: Wait 2.0s ± 10% jitter  = 1.8s - 2.2s
 (Total max time: ~4s for 3 attempts)
 ```

 ### 4. Memory and Performance

 - RetryExecutor is an actor → thread-safe
 - All retry state is isolated
 - No memory leaks from retry operations
 - Cancellation propagates immediately
 - Progress handlers work during retries

 ### 5. Testing Retry Logic

 ```swift
 // Test with mock URLSession
 let mockSession = MockURLSession()
 let service = GeminiService(session: mockSession)

 // Simulate transient failure
 mockSession.failCount = 2  // Fail first 2 attempts
 let result = try await service.uploadVideo(localURL: url)
 // Should succeed on 3rd attempt
 ```
 */

// MARK: - Advanced Usage

/// Custom retry policy for specific use cases
func customRetryExample() async throws {
    // For large video files, use more aggressive retry
    let largeFilePolicy = RetryPolicy(
        maxAttempts: 5,
        initialDelay: 2.0,
        maxDelay: 60.0,
        multiplier: 2.0,
        jitter: 0.2
    )

    // Note: To use custom policy with GeminiService,
    // you would need to expose it in the method signature
    // or use the withRetry() function directly:

    let result = try await withRetry(policy: largeFilePolicy) {
        // Your custom operation
        try await performNetworkCall()
    }

    print("Success: \(result)")
}

private func performNetworkCall() async throws -> String {
    // Mock implementation
    return "Success"
}
