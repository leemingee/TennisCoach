import XCTest
@testable import TennisCoach

// MARK: - RetryPolicy Tests

final class RetryPolicyTests: XCTestCase {

    // MARK: - Policy Configuration Tests

    func testDefaultPolicyConfiguration() {
        let policy = RetryPolicy.default

        XCTAssertEqual(policy.maxAttempts, 3)
        XCTAssertEqual(policy.initialDelay, 1.0)
        XCTAssertEqual(policy.maxDelay, 30.0)
        XCTAssertEqual(policy.multiplier, 2.0)
    }

    func testAggressivePolicyConfiguration() {
        let policy = RetryPolicy.aggressive

        XCTAssertEqual(policy.maxAttempts, 5)
        XCTAssertEqual(policy.initialDelay, 0.5)
    }

    func testConservativePolicyConfiguration() {
        let policy = RetryPolicy.conservative

        XCTAssertEqual(policy.maxAttempts, 2)
        XCTAssertEqual(policy.initialDelay, 2.0)
    }

    // MARK: - Exponential Backoff Tests

    func testExponentialBackoff() {
        let policy = RetryPolicy(
            maxAttempts: 4,
            initialDelay: 1.0,
            multiplier: 2.0,
            jitter: 0.0 // No jitter for predictable testing
        )

        let delay0 = policy.delay(for: 0)
        let delay1 = policy.delay(for: 1)
        let delay2 = policy.delay(for: 2)

        XCTAssertEqual(delay0, 1.0) // 1 * 2^0 = 1
        XCTAssertEqual(delay1, 2.0) // 1 * 2^1 = 2
        XCTAssertEqual(delay2, 4.0) // 1 * 2^2 = 4
    }

    func testMaxDelayCap() {
        let policy = RetryPolicy(
            maxAttempts: 10,
            initialDelay: 1.0,
            maxDelay: 5.0,
            multiplier: 2.0,
            jitter: 0.0
        )

        // 1 * 2^10 = 1024, but should be capped at 5
        let delay = policy.delay(for: 10)
        XCTAssertEqual(delay, 5.0)
    }

    func testJitterVariation() {
        let policy = RetryPolicy(
            maxAttempts: 3,
            initialDelay: 10.0,
            multiplier: 1.0,
            jitter: 0.5 // 50% jitter
        )

        // Generate multiple delays and ensure they vary
        var delays: Set<TimeInterval> = []
        for _ in 0..<100 {
            let delay = policy.delay(for: 0)
            delays.insert(delay)

            // Should be within 50% of 10: between 5 and 15
            XCTAssertGreaterThanOrEqual(delay, 5.0)
            XCTAssertLessThanOrEqual(delay, 15.0)
        }

        // With 100 samples and 50% jitter, we should see variation
        XCTAssertGreaterThan(delays.count, 1, "Jitter should produce varying delays")
    }

    // MARK: - URL Error Retry Decision Tests

    func testURLErrorShouldRetry() {
        // Transient errors that should retry
        let retryableErrors: [URLError.Code] = [
            .timedOut,
            .networkConnectionLost,
            .notConnectedToInternet,
            .cannotConnectToHost,
            .cannotFindHost,
            .dnsLookupFailed
        ]

        for code in retryableErrors {
            let error = URLError(code)
            XCTAssertTrue(
                error.shouldRetry,
                "\(code) should be retryable"
            )
        }
    }

    func testURLErrorShouldNotRetry() {
        // Permanent errors that should not retry
        let nonRetryableErrors: [URLError.Code] = [
            .badURL,
            .unsupportedURL,
            .fileDoesNotExist,
            .userCancelledAuthentication
        ]

        for code in nonRetryableErrors {
            let error = URLError(code)
            XCTAssertFalse(
                error.shouldRetry,
                "\(code) should not be retryable"
            )
        }
    }

    // MARK: - HTTP Response Retry Tests

    func testHTTPSuccessNoRetry() {
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!

        XCTAssertFalse(response.shouldRetry)
    }

    func testHTTPServerErrorShouldRetry() {
        let codes = [500, 502, 503, 504]
        for code in codes {
            let response = HTTPURLResponse(
                url: URL(string: "https://example.com")!,
                statusCode: code,
                httpVersion: nil,
                headerFields: nil
            )!

            XCTAssertTrue(
                response.shouldRetry,
                "HTTP \(code) should be retryable"
            )
        }
    }

    func testHTTPClientErrorNoRetry() {
        let codes = [400, 401, 403, 404]
        for code in codes {
            let response = HTTPURLResponse(
                url: URL(string: "https://example.com")!,
                statusCode: code,
                httpVersion: nil,
                headerFields: nil
            )!

            XCTAssertFalse(
                response.shouldRetry,
                "HTTP \(code) should not be retryable"
            )
        }
    }

    func testHTTPRateLimitShouldRetry() {
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: nil
        )!

        XCTAssertTrue(response.shouldRetry)
    }

    func testHTTPRetryAfterHeader() {
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: ["Retry-After": "60"]
        )!

        XCTAssertEqual(response.retryAfterDelay, 60.0)
    }

    // MARK: - GeminiError Retry Decision Tests

    func testGeminiErrorRetryDecisions() {
        // Should not retry
        XCTAssertEqual(
            GeminiError.invalidAPIKey.retryDecision,
            .doNotRetry
        )
        XCTAssertEqual(
            GeminiError.uploadCancelled.retryDecision,
            .doNotRetry
        )
        XCTAssertEqual(
            GeminiError.uploadFailed("test").retryDecision,
            .doNotRetry
        )

        // Should retry
        XCTAssertEqual(
            GeminiError.invalidResponse.retryDecision,
            .retry
        )

        // Should retry with delay
        if case .retryAfter(let delay) = GeminiError.fileProcessing.retryDecision {
            XCTAssertEqual(delay, 2.0)
        } else {
            XCTFail("fileProcessing should retry after delay")
        }
    }

    func testGeminiNetworkErrorRetryDecision() {
        let timeoutError = URLError(.timedOut)
        let geminiError = GeminiError.networkError(timeoutError)

        if case .retry = geminiError.retryDecision {
            // Success
        } else {
            XCTFail("Network timeout should trigger retry")
        }
    }

    func testGeminiHTTPErrorRetryDecision() {
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 503,
            httpVersion: nil,
            headerFields: nil
        )!

        let error = GeminiError.httpError(statusCode: 503, response: response)

        if case .retry = error.retryDecision {
            // Success
        } else {
            XCTFail("HTTP 503 should trigger retry")
        }
    }

    // MARK: - Integration Tests

    func testRetryExecutorSuccess() async throws {
        let executor = RetryExecutor()
        var attemptCount = 0

        let result = try await executor.execute(policy: .default) {
            attemptCount += 1
            return "Success"
        }

        XCTAssertEqual(result, "Success")
        XCTAssertEqual(attemptCount, 1, "Should succeed on first attempt")
    }

    func testRetryExecutorWithFailures() async throws {
        let executor = RetryExecutor()
        var attemptCount = 0

        let result = try await executor.execute(
            policy: RetryPolicy(maxAttempts: 3, initialDelay: 0.01, jitter: 0.0)
        ) {
            attemptCount += 1
            if attemptCount < 3 {
                throw URLError(.timedOut)
            }
            return "Success on attempt 3"
        }

        XCTAssertEqual(result, "Success on attempt 3")
        XCTAssertEqual(attemptCount, 3, "Should succeed on third attempt")
    }

    func testRetryExecutorAllFailures() async {
        let executor = RetryExecutor()
        var attemptCount = 0

        do {
            _ = try await executor.execute(
                policy: RetryPolicy(maxAttempts: 3, initialDelay: 0.01, jitter: 0.0)
            ) {
                attemptCount += 1
                throw URLError(.timedOut)
            }
            XCTFail("Should have thrown error")
        } catch {
            // Expected
            XCTAssertEqual(attemptCount, 3, "Should attempt 3 times")
        }
    }

    func testRetryExecutorCancellation() async {
        let executor = RetryExecutor()
        var attemptCount = 0

        let task = Task {
            try await executor.execute(
                policy: RetryPolicy(maxAttempts: 10, initialDelay: 1.0)
            ) {
                attemptCount += 1
                throw URLError(.timedOut)
            }
        }

        // Cancel after short delay
        try? await Task.sleep(nanoseconds: 100_000_000)
        await executor.cancel()

        do {
            _ = try await task.value
            XCTFail("Should have been cancelled")
        } catch is CancellationError {
            // Expected
            XCTAssertLessThan(attemptCount, 10, "Should cancel before all attempts")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testWithRetryConvenienceFunction() async throws {
        var attemptCount = 0

        let result = try await withRetry(
            policy: RetryPolicy(maxAttempts: 3, initialDelay: 0.01, jitter: 0.0)
        ) {
            attemptCount += 1
            if attemptCount < 2 {
                throw URLError(.timedOut)
            }
            return "Success"
        }

        XCTAssertEqual(result, "Success")
        XCTAssertEqual(attemptCount, 2)
    }

    func testCustomRetryDecisionFunction() async throws {
        var attemptCount = 0
        var decisionCallCount = 0

        let result = try await withRetry(
            policy: RetryPolicy(maxAttempts: 5, initialDelay: 0.01, jitter: 0.0),
            shouldRetry: { error, attempt in
                decisionCallCount += 1
                // Only retry first 2 failures
                return attempt < 2 ? .retry : .doNotRetry
            }
        ) {
            attemptCount += 1
            if attemptCount < 4 {
                throw URLError(.timedOut)
            }
            return "Success"
        }

        XCTAssertEqual(result, "Success")
        XCTAssertEqual(attemptCount, 4)
        XCTAssertEqual(decisionCallCount, 3, "Should make 3 retry decisions")
    }

    // MARK: - Performance Tests

    func testRetryBackoffTiming() async throws {
        let policy = RetryPolicy(
            maxAttempts: 3,
            initialDelay: 0.1,
            multiplier: 2.0,
            jitter: 0.0
        )

        let startTime = Date()
        var attemptCount = 0

        do {
            _ = try await withRetry(policy: policy) {
                attemptCount += 1
                throw URLError(.timedOut)
            }
        } catch {
            // Expected to fail
        }

        let elapsed = Date().timeIntervalSince(startTime)

        // Should take approximately: 0.1 + 0.2 = 0.3 seconds
        XCTAssertGreaterThan(elapsed, 0.25, "Should respect backoff delays")
        XCTAssertLessThan(elapsed, 0.5, "Should not take too long")
        XCTAssertEqual(attemptCount, 3)
    }
}
