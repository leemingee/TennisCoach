import Foundation

// MARK: - RetryPolicy Usage Examples

/// This file demonstrates how to use the RetryPolicy utility
/// across different scenarios in the TennisCoach app.

// MARK: - Example 1: Basic Usage with Default Policy

func basicRetryExample() async throws {
    // Use default policy: 3 attempts, 1s initial delay, exponential backoff
    let result = try await withRetry {
        // Your network operation
        try await someNetworkOperation()
    }
    print("Success: \(result)")
}

// MARK: - Example 2: Custom Retry Policy

func customPolicyExample() async throws {
    // Create custom policy for critical operations
    let aggressivePolicy = RetryPolicy(
        maxAttempts: 5,
        initialDelay: 0.5,
        maxDelay: 10.0,
        multiplier: 2.0
    )

    let result = try await withRetry(policy: aggressivePolicy) {
        try await criticalNetworkOperation()
    }
    print("Success: \(result)")
}

// MARK: - Example 3: Custom Retry Decision Logic

func customRetryDecisionExample() async throws {
    let result = try await withRetry(
        policy: .default,
        shouldRetry: { error, attempt in
            print("Attempt \(attempt + 1) failed: \(error)")

            // Custom logic: only retry on specific error codes
            if let urlError = error as? URLError {
                switch urlError.code {
                case .timedOut, .networkConnectionLost:
                    return .retry
                case .notConnectedToInternet:
                    // Wait longer if no internet
                    return .retryAfter(5.0)
                default:
                    return .doNotRetry
                }
            }

            return .doNotRetry
        }
    ) {
        try await someNetworkOperation()
    }
    print("Success: \(result)")
}

// MARK: - Example 4: Using RetryExecutor for Cancellable Operations

func cancellableRetryExample() async throws {
    let executor = RetryExecutor()

    // Start retry operation in a task
    let task = Task {
        try await executor.execute(policy: .default) {
            try await longRunningOperation()
        }
    }

    // Later, cancel if needed
    Task {
        try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
        await executor.cancel()
    }

    do {
        let result = try await task.value
        print("Completed: \(result)")
    } catch is CancellationError {
        print("Operation was cancelled")
    }
}

// MARK: - Example 5: GeminiService Integration

class GeminiServiceUsageExample {

    let geminiService = GeminiService()

    func uploadVideoWithRetry() async throws {
        let videoURL = URL(fileURLWithPath: "/path/to/video.mp4")

        do {
            // GeminiService already has retry logic built-in
            let fileUri = try await geminiService.uploadVideo(
                localURL: videoURL,
                progressHandler: { progress in
                    print("Upload progress: \(Int(progress * 100))%")
                }
            )
            print("Upload successful: \(fileUri)")

        } catch let error as GeminiError {
            // Handle GeminiError with retry information
            switch error {
            case .networkError(let underlyingError):
                print("Network failed after retries: \(underlyingError)")
            case .httpError(let statusCode, _):
                print("HTTP error \(statusCode) after retries")
            case .invalidAPIKey:
                print("API key invalid - no retry attempted")
            default:
                print("Upload failed: \(error.localizedDescription)")
            }
        }
    }

    func analyzeVideoWithRetry() async throws {
        let fileUri = "files/some-file-id"

        do {
            // Analysis requests also have retry logic
            let stream = try await geminiService.analyzeVideo(
                fileUri: fileUri,
                prompt: "Analyze this tennis serve"
            )

            for try await chunk in stream {
                print("Received: \(chunk)")
            }

        } catch let error as GeminiError {
            print("Analysis failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Example 6: Creating Custom RetryableError

enum CustomError: Error, RetryableError {
    case temporaryFailure
    case permanentFailure
    case rateLimited

    var retryDecision: RetryDecision {
        switch self {
        case .temporaryFailure:
            return .retry
        case .permanentFailure:
            return .doNotRetry
        case .rateLimited:
            return .retryAfter(60.0) // Wait 1 minute
        }
    }
}

func customErrorRetryExample() async throws {
    let result = try await withRetry {
        // Your operation that throws CustomError
        if Bool.random() {
            throw CustomError.temporaryFailure // Will retry
        }
        return "Success"
    }
    print(result)
}

// MARK: - Example 7: Predefined Retry Policies

func predefinedPoliciesExample() async throws {
    // Conservative: 2 attempts, 2s initial delay
    try await withRetry(policy: .conservative) {
        try await someNetworkOperation()
    }

    // Aggressive: 5 attempts, 0.5s initial delay
    try await withRetry(policy: .aggressive) {
        try await someNetworkOperation()
    }

    // Default: 3 attempts, 1s initial delay
    try await withRetry(policy: .default) {
        try await someNetworkOperation()
    }
}

// MARK: - Example 8: Retry with HTTP Response Headers

func retryAfterHeaderExample() async throws {
    let result = try await withRetry(
        shouldRetry: { error, attempt in
            // Check if error contains Retry-After header
            if let geminiError = error as? GeminiError,
               case .httpError(let statusCode, let response) = geminiError,
               statusCode == 429, // Rate limited
               let httpResponse = response,
               let retryAfter = httpResponse.retryAfterDelay {
                return .retryAfter(retryAfter)
            }
            return .retry
        }
    ) {
        try await someNetworkOperation()
    }
    print("Success: \(result)")
}

// MARK: - Example 9: Multiple Sequential Operations with Retry

func multipleOperationsExample() async throws {
    // Each operation has independent retry logic
    let uploadResult = try await withRetry(policy: .aggressive) {
        try await uploadData()
    }

    let processResult = try await withRetry(policy: .default) {
        try await processData(uploadResult)
    }

    let finalResult = try await withRetry(policy: .conservative) {
        try await finalizeData(processResult)
    }

    print("All operations completed: \(finalResult)")
}

// MARK: - Example 10: Retry with Logging

func retryWithLoggingExample() async throws {
    let result = try await withRetry(
        policy: .default,
        shouldRetry: { error, attempt in
            // Log each retry attempt
            print("⚠️ Attempt \(attempt + 1) failed")
            print("   Error: \(error.localizedDescription)")

            if attempt == 2 {
                print("   This is the last attempt")
            }

            // Use default retry logic
            if let urlError = error as? URLError {
                let decision = urlError.shouldRetry ? "RETRY" : "FAIL"
                print("   Decision: \(decision)")
                return urlError.shouldRetry ? .retry : .doNotRetry
            }

            return .doNotRetry
        }
    ) {
        try await someNetworkOperation()
    }
    print("✅ Success: \(result)")
}

// MARK: - Mock Operations (for examples)

private func someNetworkOperation() async throws -> String {
    try await Task.sleep(nanoseconds: 100_000_000)
    if Bool.random() { throw URLError(.timedOut) }
    return "Success"
}

private func criticalNetworkOperation() async throws -> String {
    try await someNetworkOperation()
}

private func longRunningOperation() async throws -> String {
    try await Task.sleep(nanoseconds: 10_000_000_000)
    return "Completed"
}

private func uploadData() async throws -> String {
    try await someNetworkOperation()
}

private func processData(_ input: String) async throws -> String {
    try await someNetworkOperation()
}

private func finalizeData(_ input: String) async throws -> String {
    try await someNetworkOperation()
}
