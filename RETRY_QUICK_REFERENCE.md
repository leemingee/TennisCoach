# Retry Logic Quick Reference

## TL;DR

GeminiService now automatically retries failed network requests with exponential backoff. No code changes needed for existing functionality.

## Quick Examples

### 1. Upload Video (Automatic Retry)

```swift
// Just call as before - retry happens automatically
let fileUri = try await geminiService.uploadVideo(localURL: videoURL)
```

### 2. Upload with Progress

```swift
let fileUri = try await geminiService.uploadVideo(
    localURL: videoURL,
    progressHandler: { progress in
        print("Progress: \(Int(progress * 100))%")
    }
)
// Retries up to 3 times on network failures
```

### 3. Custom Retry Operation

```swift
// Use withRetry() for your own operations
let result = try await withRetry {
    try await yourNetworkOperation()
}
```

### 4. Custom Retry Policy

```swift
let policy = RetryPolicy(
    maxAttempts: 5,
    initialDelay: 0.5,
    multiplier: 2.0
)

let result = try await withRetry(policy: policy) {
    try await yourOperation()
}
```

### 5. Custom Retry Logic

```swift
let result = try await withRetry(
    shouldRetry: { error, attempt in
        if let urlError = error as? URLError {
            return urlError.code == .timedOut ? .retry : .doNotRetry
        }
        return .doNotRetry
    }
) {
    try await yourOperation()
}
```

## What Gets Retried?

| Scenario | Retry? | Max Attempts |
|----------|--------|--------------|
| Network timeout | ✅ Yes | 3 |
| Connection lost | ✅ Yes | 3 |
| Server error (500-599) | ✅ Yes | 3 |
| Rate limit (429) | ✅ Yes | 3 |
| Bad request (400) | ❌ No | - |
| Unauthorized (401) | ❌ No | - |
| Invalid API key | ❌ No | - |
| File processing | ✅ Yes | 30 |

## Retry Delays

Default exponential backoff (with ±10% jitter):

- **Attempt 1:** Immediate
- **Attempt 2:** Wait ~1 second
- **Attempt 3:** Wait ~2 seconds

## Error Handling

```swift
do {
    let result = try await geminiService.uploadVideo(localURL: url)
    // Success after 0-3 attempts
} catch let error as GeminiError {
    switch error {
    case .networkError:
        // Network failed after 3 retries
    case .httpError(let code, _):
        // HTTP error after retries
    case .invalidAPIKey:
        // Auth error - not retried
    default:
        // Other errors
    }
}
```

## Predefined Policies

```swift
// Default: 3 attempts, 1s → 2s → 4s
RetryPolicy.default

// Aggressive: 5 attempts, 0.5s → 0.75s → 1.125s → ...
RetryPolicy.aggressive

// Conservative: 2 attempts, 2s → 4s
RetryPolicy.conservative
```

## Cancellation

```swift
let task = Task {
    try await geminiService.uploadVideo(localURL: url)
}

// Cancel anytime
task.cancel()
```

## Custom Error Types

```swift
enum MyError: Error, RetryableError {
    case temporary
    case permanent

    var retryDecision: RetryDecision {
        switch self {
        case .temporary:
            return .retry
        case .permanent:
            return .doNotRetry
        }
    }
}
```

## Files Modified/Created

### Modified
- `/Users/yoyo/src/TennisCoach/TennisCoach/Services/GeminiService.swift`

### Created
- `/Users/yoyo/src/TennisCoach/TennisCoach/Utilities/RetryPolicy.swift`
- `/Users/yoyo/src/TennisCoach/TennisCoach/Examples/RetryPolicyExamples.swift`
- `/Users/yoyo/src/TennisCoach/TennisCoach/Examples/GeminiServiceRetryIntegration.swift`
- `/Users/yoyo/src/TennisCoach/TennisCoach/Tests/RetryPolicyTests.swift`

## Key Benefits

1. **Resilient to transient failures** - Network hiccups don't fail requests
2. **Respects server limits** - Uses Retry-After headers
3. **Smart error handling** - Doesn't retry permanent errors
4. **Fully cancellable** - User can cancel anytime
5. **Type-safe** - Full Swift concurrency support
6. **Reusable** - Use RetryPolicy anywhere in the app

## Migration

No migration needed! Existing code works as-is with automatic retry.

## Performance Impact

- Minimal overhead when requests succeed
- Retry delays only occur on failures
- No memory leaks from retry logic
- Thread-safe via actor isolation

## Testing

```swift
// Test automatic retry
let service = GeminiService()
let result = try await service.uploadVideo(localURL: testURL)
// Will retry up to 3 times on failures

// Test custom retry
let result = try await withRetry(policy: .aggressive) {
    try await yourOperation()
}
```
