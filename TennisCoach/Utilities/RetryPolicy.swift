import Foundation

/// Configuration for retry behavior with exponential backoff
public struct RetryPolicy: Sendable {

    /// Maximum number of retry attempts
    public let maxAttempts: Int

    /// Initial delay before first retry (in seconds)
    public let initialDelay: TimeInterval

    /// Maximum delay between retries (in seconds)
    public let maxDelay: TimeInterval

    /// Multiplier for exponential backoff
    public let multiplier: Double

    /// Jitter factor (0.0 to 1.0) to randomize delays
    public let jitter: Double

    /// Creates a retry policy with exponential backoff
    /// - Parameters:
    ///   - maxAttempts: Maximum retry attempts (default: 3)
    ///   - initialDelay: Initial delay in seconds (default: 1.0)
    ///   - maxDelay: Maximum delay cap in seconds (default: 30.0)
    ///   - multiplier: Exponential multiplier (default: 2.0)
    ///   - jitter: Random jitter factor 0-1 (default: 0.1)
    public init(
        maxAttempts: Int = 3,
        initialDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 30.0,
        multiplier: Double = 2.0,
        jitter: Double = 0.1
    ) {
        self.maxAttempts = max(1, maxAttempts)
        self.initialDelay = max(0, initialDelay)
        self.maxDelay = max(initialDelay, maxDelay)
        self.multiplier = max(1.0, multiplier)
        self.jitter = min(1.0, max(0.0, jitter))
    }

    /// Default retry policy: 3 attempts, 1s initial, exponential backoff
    public static let `default` = RetryPolicy()

    /// Aggressive retry policy: 5 attempts, 0.5s initial delay
    public static let aggressive = RetryPolicy(
        maxAttempts: 5,
        initialDelay: 0.5,
        multiplier: 1.5
    )

    /// Conservative retry policy: 2 attempts, 2s initial delay
    public static let conservative = RetryPolicy(
        maxAttempts: 2,
        initialDelay: 2.0
    )

    /// Calculate delay for a given attempt number
    /// - Parameter attempt: Current attempt number (0-based)
    /// - Returns: Delay in seconds with jitter applied
    public func delay(for attempt: Int) -> TimeInterval {
        let exponentialDelay = initialDelay * pow(multiplier, Double(attempt))
        let cappedDelay = min(exponentialDelay, maxDelay)

        // Apply jitter: random variation of ±jitter%
        let jitterAmount = cappedDelay * jitter
        let randomJitter = Double.random(in: -jitterAmount...jitterAmount)

        return max(0, cappedDelay + randomJitter)
    }
}

/// Error classification for retry decisions
public enum RetryDecision: Equatable {
    /// Retry the operation
    case retry

    /// Don't retry, fail immediately
    case doNotRetry

    /// Retry after a custom delay
    case retryAfter(TimeInterval)
}

/// Protocol for errors that can determine their retry eligibility
public protocol RetryableError: Error {
    /// Determines if this error should be retried
    var retryDecision: RetryDecision { get }
}

/// Extension to classify HTTP errors for retry logic
extension URLError {

    /// Determines if this URLError should be retried
    public var shouldRetry: Bool {
        switch code {
        // Network and connection errors - retry
        case .notConnectedToInternet,
             .networkConnectionLost,
             .timedOut,
             .cannotConnectToHost,
             .cannotFindHost,
             .dnsLookupFailed,
             .secureConnectionFailed,
             .dataNotAllowed:
            return true

        // Permanent errors - don't retry
        case .badURL,
             .unsupportedURL,
             .fileDoesNotExist,
             .fileIsDirectory,
             .userCancelledAuthentication,
             .userAuthenticationRequired:
            return false

        // Resource unavailable - retry
        case .resourceUnavailable:
            return true

        // Default to retry for unknown cases
        default:
            return true
        }
    }
}

/// Extension to classify HTTP status codes for retry logic
extension HTTPURLResponse {

    /// Determines if this HTTP status code should be retried
    public var shouldRetry: Bool {
        switch statusCode {
        // 2xx Success - don't retry
        case 200..<300:
            return false

        // 4xx Client errors - mostly don't retry
        case 400, 403, 404, 405, 406, 407, 410:
            return false

        // 401 Unauthorized - don't retry (invalid credentials)
        case 401:
            return false

        // 408 Request Timeout - retry
        case 408:
            return true

        // 409 Conflict - don't retry
        case 409:
            return false

        // 429 Rate Limited - retry with backoff
        case 429:
            return true

        // 5xx Server errors - retry
        case 500..<600:
            return true

        // Default: don't retry unknown codes
        default:
            return false
        }
    }

    /// Extract retry-after delay from headers
    public var retryAfterDelay: TimeInterval? {
        guard let retryAfter = value(forHTTPHeaderField: "Retry-After") else {
            return nil
        }

        // Try to parse as seconds (integer)
        if let seconds = TimeInterval(retryAfter) {
            return seconds
        }

        // Try to parse as HTTP date
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        if let date = formatter.date(from: retryAfter) {
            return date.timeIntervalSinceNow
        }

        return nil
    }
}

/// Retry executor with exponential backoff and cancellation support
public actor RetryExecutor {

    private var isCancelled = false

    /// Cancel all pending retries
    public func cancel() {
        isCancelled = true
    }

    /// Execute an async operation with retry logic
    /// - Parameters:
    ///   - policy: Retry policy to use
    ///   - operation: Async operation to execute
    ///   - shouldRetry: Custom retry decision logic (optional)
    /// - Returns: Result from the operation
    /// - Throws: Last error if all retries fail
    public func execute<T>(
        policy: RetryPolicy = .default,
        operation: @Sendable () async throws -> T,
        shouldRetry: (@Sendable (Error, Int) -> RetryDecision)? = nil
    ) async throws -> T {
        var lastError: Error?

        for attempt in 0..<policy.maxAttempts {
            // Check for cancellation
            guard !isCancelled else {
                throw CancellationError()
            }

            do {
                // Execute the operation
                let result = try await operation()
                return result

            } catch {
                lastError = error

                // Don't retry on last attempt
                if attempt == policy.maxAttempts - 1 {
                    break
                }

                // Determine if we should retry
                let decision: RetryDecision

                if let customDecision = shouldRetry?(error, attempt) {
                    decision = customDecision
                } else {
                    decision = defaultRetryDecision(for: error)
                }

                switch decision {
                case .retry:
                    let delay = policy.delay(for: attempt)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                case .retryAfter(let customDelay):
                    try await Task.sleep(nanoseconds: UInt64(customDelay * 1_000_000_000))

                case .doNotRetry:
                    throw error
                }
            }
        }

        // All retries exhausted
        throw lastError ?? RetryError.allAttemptsFailed
    }

    /// Default retry decision logic
    private func defaultRetryDecision(for error: Error) -> RetryDecision {
        // Check if error implements RetryableError
        if let retryableError = error as? RetryableError {
            return retryableError.retryDecision
        }

        // Check URLError
        if let urlError = error as? URLError {
            return urlError.shouldRetry ? .retry : .doNotRetry
        }

        // Check for HTTP response errors (wrapped in custom errors)
        // This will be handled by custom error types

        // Default: don't retry
        return .doNotRetry
    }
}

/// Errors specific to retry logic
public enum RetryError: LocalizedError {
    case allAttemptsFailed
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .allAttemptsFailed:
            return "Operation failed after all retry attempts"
        case .cancelled:
            return "Retry operation was cancelled"
        }
    }
}

/// Convenience function for simple retry operations
/// - Parameters:
///   - policy: Retry policy (default: .default)
///   - operation: Operation to retry
/// - Returns: Result from the operation
public func withRetry<T>(
    policy: RetryPolicy = .default,
    operation: @Sendable () async throws -> T
) async throws -> T {
    let executor = RetryExecutor()
    return try await executor.execute(policy: policy, operation: operation)
}

/// Convenience function for retry with custom logic
/// - Parameters:
///   - policy: Retry policy
///   - shouldRetry: Custom retry decision
///   - operation: Operation to retry
/// - Returns: Result from the operation
public func withRetry<T>(
    policy: RetryPolicy = .default,
    shouldRetry: @escaping @Sendable (Error, Int) -> RetryDecision,
    operation: @Sendable () async throws -> T
) async throws -> T {
    let executor = RetryExecutor()
    return try await executor.execute(
        policy: policy,
        operation: operation,
        shouldRetry: shouldRetry
    )
}
