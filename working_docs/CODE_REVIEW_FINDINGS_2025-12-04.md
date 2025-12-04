# TennisCoach Code Review Findings

**Date:** 2025-12-04
**Reviewers:** Swift Expert Agent, Code Reviewer Agent
**Overall Score:** 78/100 (Good with improvements needed)

---

## Summary

The codebase demonstrates strong Swift fundamentals with modern concurrency patterns, protocol-oriented design, and good error handling. However, several critical issues require immediate attention.

---

## Critical Issues (P0) - Fix Immediately

### 1. Force Unwrapping in GeminiService ✅ FIXED
**File:** `Services/GeminiService.swift`
**Lines:** 256, 278, 351, 461

```swift
// PROBLEM: Force unwrap can crash app
let startURL = URL(string: "\(baseURL)/upload/...")!
```

**Fix Applied:** Replaced with guard let statements that throw proper errors.

### 2. UploadProgressDelegate Race Condition
**File:** `Services/GeminiService.swift:128-153`

The delegate is `@MainActor` but creates tasks in `nonisolated` method - causes data races.

### 3. Timer Race Condition in RecordViewModel ✅ FIXED
**File:** `Views/Recording/RecordViewModel.swift:106-114`

```swift
// PROBLEM: @Published property updated from background
self?.recordingDuration += 1  // Race condition!
```

**Fix Applied:** Added `@MainActor` to the timer Task closure.

### 4. Missing ModelContext Save Error Handling
**File:** `Views/Recording/RecordViewModel.swift:91-92`

If database save fails, video file is orphaned on disk.

---

## High Priority Issues (P1)

### 5. Unused Dead Code ✅ FIXED
**File:** `Item.swift` - Xcode template file, never used. **Deleted.**

### 6. Missing Task Cancellation in Streaming
**File:** `Views/Chat/ChatViewModel.swift:89-92`

Streaming continues even if user navigates away.

### 7. Inconsistent Main Thread Handling
**File:** `Views/Recording/RecordView.swift:73-74`

Uses `DispatchQueue.main.async` instead of `Task { @MainActor in }`.

---

## Medium Priority Issues (P2)

### 8. Print Statements Instead of Logging
11 instances of `print()` should use `AppLogger`.

### 9. Hard-Coded Screen Width ✅ FIXED
**File:** `Views/Chat/ChatView.swift:120, 149`

`UIScreen.main.bounds.width` breaks on iPad split screen. **Fixed with containerRelativeFrame.**

### 10. Missing File Size Validation
No check for max file size before Gemini upload.

### 11. Missing API Key Format Validation
Users can save invalid API keys.

---

## Low Priority Issues (P3)

- Magic numbers in VideoCompressor (3600 seconds)
- Inconsistent localization (mix of Chinese/English)
- Missing accessibility labels on buttons
- Hard-coded Gemini model name

---

## Security Review

### Good Practices Found:
- ✅ Keychain usage for API keys
- ✅ File protection on video files
- ✅ API key never logged

### Improvements Needed:
- Environment variable API key should be DEBUG-only
- Add input validation for API key format

---

## Performance Issues

1. **Thumbnail in database** - Large blobs slow queries
2. **Streaming text scroll** - Updates on every character
3. **No video upload cache** - Re-uploads same video

---

## iOS-Specific Issues

1. **No background upload support** - Upload fails if app backgrounded
2. **No memory warning handling** - Could crash on low memory
3. **Camera rotation not handled** - Preview may be wrong orientation

---

## Testing Gaps

- Missing integration tests (recording → upload → analysis)
- Missing UI tests
- Missing edge case tests (large files, network interruption)

---

## Recommended Actions

### This Week (P0):
1. Fix force unwraps in GeminiService
2. Fix timer race condition in RecordViewModel
3. Add error handling to ModelContext.save()
4. Delete unused Item.swift

### This Sprint (P1):
1. Fix UploadProgressDelegate threading
2. Add task cancellation to streaming
3. Replace print() with AppLogger

### This Quarter (P2):
1. Implement Photos Library storage (per architecture review)
2. Add background upload support
3. Add integration tests

---

## Code Quality Metrics

| Metric | Before | After | Target |
|--------|--------|-------|--------|
| Force Unwraps | 7 | 3 | 0 |
| Print Statements | 11 | 11 | 0 |
| Test Coverage | ~65% | ~65% | >80% |
| Dead Code Files | 1 | 0 ✅ | 0 |
| UIScreen.main usage | 2 | 0 ✅ | 0 |

---

*Document Updated: 2025-12-04*
*See also: ARCHITECTURE_REVIEW.md for storage redesign recommendations*
*See also: ITERATION_2_PLANNING_2025-12-04.md for bug fix details*
