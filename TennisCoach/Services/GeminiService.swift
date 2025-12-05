import Foundation

// MARK: - Protocol

/// Protocol defining the Gemini API service interface.
///
/// This protocol enables dependency injection for testing. The service handles:
/// - Video file uploads via Gemini's resumable upload protocol
/// - Streaming AI analysis using Server-Sent Events (SSE)
/// - Multi-turn conversations with video context
///
/// All methods are async and use Swift's modern concurrency model.
protocol GeminiServicing {
    /// Upload a video file to Gemini File API with progress tracking
    /// - Parameters:
    ///   - localURL: Local file URL of the video
    ///   - progressHandler: Optional closure called with upload progress (0.0 to 1.0)
    /// - Returns: The fileUri returned by Gemini
    func uploadVideo(
        localURL: URL,
        progressHandler: ((Double) -> Void)?
    ) async throws -> String

    /// Analyze a video with the initial analysis prompt
    /// - Parameters:
    ///   - fileUri: The Gemini file URI
    ///   - prompt: Analysis prompt
    /// - Returns: Async stream of response text chunks
    func analyzeVideo(
        fileUri: String,
        prompt: String
    ) async throws -> AsyncThrowingStream<String, Error>

    /// Continue a conversation about a video
    /// - Parameters:
    ///   - fileUri: The Gemini file URI
    ///   - history: Previous messages in the conversation
    ///   - userMessage: New user message
    /// - Returns: Async stream of response text chunks
    func chat(
        fileUri: String,
        history: [Message],
        userMessage: String
    ) async throws -> AsyncThrowingStream<String, Error>
}

// MARK: - Default Implementation

extension GeminiServicing {
    /// Upload video without progress tracking (backward compatibility)
    func uploadVideo(localURL: URL) async throws -> String {
        try await uploadVideo(localURL: localURL, progressHandler: nil)
    }
}

// MARK: - Errors

enum GeminiError: LocalizedError, RetryableError {
    case invalidAPIKey
    case uploadFailed(String)
    case fileTooLarge(sizeBytes: Int64, maxBytes: Int64)
    case fileProcessing
    case analysisFailed(String)
    case networkError(Error)
    case invalidResponse
    case uploadCancelled
    case httpError(statusCode: Int, response: HTTPURLResponse?)

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "API Key 未设置或无效"
        case .uploadFailed(let message):
            return "视频上传失败: \(message)"
        case .fileTooLarge(let sizeBytes, let maxBytes):
            let sizeMB = Double(sizeBytes) / (1024 * 1024)
            let maxMB = Double(maxBytes) / (1024 * 1024)
            return "视频文件过大 (\(String(format: "%.1f", sizeMB))MB)，最大支持 \(String(format: "%.0f", maxMB))MB"
        case .fileProcessing:
            return "视频正在处理中，请稍后再试"
        case .analysisFailed(let message):
            return "分析失败: \(message)"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .invalidResponse:
            return "服务器响应无效"
        case .uploadCancelled:
            return "上传已取消"
        case .httpError(let statusCode, _):
            return "HTTP 错误: \(statusCode)"
        }
    }

    /// Determines retry behavior for GeminiError
    var retryDecision: RetryDecision {
        switch self {
        case .invalidAPIKey:
            // Don't retry authentication errors
            return .doNotRetry

        case .uploadFailed, .analysisFailed, .fileTooLarge:
            // Don't retry explicit failures (may contain validation errors)
            return .doNotRetry

        case .fileProcessing:
            // Retry file processing with longer delay
            return .retryAfter(2.0)

        case .networkError(let error):
            // Delegate to URLError retry logic
            if let urlError = error as? URLError {
                return urlError.shouldRetry ? .retry : .doNotRetry
            }
            return .retry

        case .invalidResponse:
            // Retry invalid responses (might be temporary)
            return .retry

        case .uploadCancelled:
            // Don't retry cancelled operations
            return .doNotRetry

        case .httpError(_, let response):
            // Use HTTP response retry logic
            if let httpResponse = response {
                if let retryAfter = httpResponse.retryAfterDelay {
                    return .retryAfter(retryAfter)
                }
                return httpResponse.shouldRetry ? .retry : .doNotRetry
            }
            return .doNotRetry
        }
    }
}

// MARK: - Upload Delegate

/// URLSession delegate for tracking upload progress.
///
/// This delegate is used during video file uploads to report real-time progress.
/// The progress handler is called on the main thread for safe UI updates.
///
/// ## Thread Safety (P0 Fix)
/// - Properties are immutable (let) and set only in init
/// - URLSession calls delegate methods on its background queue
/// - We dispatch progress updates to MainActor for UI safety
/// - The class is Sendable because all properties are immutable and @Sendable
final class UploadProgressDelegate: NSObject, URLSessionTaskDelegate, Sendable {
    /// Closure to call with progress updates (0.0 to 1.0)
    /// Marked @Sendable for safe cross-actor calls
    private let progressHandler: @Sendable (Double) -> Void

    /// Expected total bytes for fallback progress calculation
    /// Immutable after init, safe to access from any thread
    private let totalBytes: Int64

    init(totalBytes: Int64, progressHandler: @escaping @Sendable (Double) -> Void) {
        self.totalBytes = totalBytes
        self.progressHandler = progressHandler
        super.init()
    }

    /// Called by URLSession as upload data is sent.
    ///
    /// This method is called on URLSession's delegate queue (background thread).
    /// We dispatch to MainActor for thread-safe UI updates.
    ///
    /// - Parameters:
    ///   - bytesSent: Bytes sent in this chunk
    ///   - totalBytesSent: Cumulative bytes sent so far
    ///   - totalBytesExpectedToSend: Total file size (-1 if unknown)
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        // Use URLSession's reported total if available, otherwise use our stored value
        // URLSession reports -1 if content length is unknown
        let total = totalBytesExpectedToSend > 0 ? totalBytesExpectedToSend : totalBytes
        let progress = Double(totalBytesSent) / Double(total)

        // Dispatch to MainActor for thread-safe UI update
        Task { @MainActor in
            self.progressHandler(progress)
        }
    }
}

// MARK: - Implementation

/// Main implementation of the Gemini API service.
///
/// This service handles all communication with Google's Gemini API for video analysis:
///
/// ## Upload Flow (Resumable Protocol)
/// 1. Start resumable upload → get upload URL
/// 2. Stream video file to upload URL with progress tracking
/// 3. Poll for file processing completion (ACTIVE state)
///
/// ## Analysis Flow (SSE Streaming)
/// 1. Send video fileUri + prompt to streamGenerateContent endpoint
/// 2. Parse Server-Sent Events (SSE) for real-time text chunks
/// 3. Return AsyncThrowingStream for SwiftUI consumption
///
/// ## Retry Logic
/// - Uses exponential backoff via RetryExecutor
/// - Respects HTTP Retry-After headers
/// - Different policies for upload vs. streaming (conservative for streams)
final class GeminiService: GeminiServicing {

    private let apiKey: String
    private let baseURL: String
    private let model: String
    private let session: URLSession
    private let retryExecutor: RetryExecutor

    /// Initialize the Gemini service.
    /// - Parameters:
    ///   - apiKey: Gemini API key (defaults to stored key from Constants)
    ///   - baseURL: API base URL (defaults to production)
    ///   - model: Model name to use (defaults to gemini-2.0-flash)
    ///   - session: URLSession for network requests (injectable for testing)
    init(
        apiKey: String = Constants.API.apiKey,
        baseURL: String = Constants.API.geminiBaseURL,
        model: String = Constants.API.geminiModel,
        session: URLSession = .shared
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.model = model
        self.session = session
        self.retryExecutor = RetryExecutor()
    }

    // MARK: - Retry Helper

    /// Executes a network request with retry logic
    /// - Parameters:
    ///   - policy: Retry policy to use (default: .default)
    ///   - request: URLRequest to execute
    ///   - validateResponse: Optional response validation closure
    /// - Returns: Response data and URLResponse
    private func executeWithRetry(
        policy: RetryPolicy = .default,
        request: URLRequest,
        validateResponse: ((Data, URLResponse) throws -> Void)? = nil
    ) async throws -> (Data, URLResponse) {
        try await retryExecutor.execute(policy: policy) {
            let (data, response) = try await self.session.data(for: request)

            // Check HTTP status code
            if let httpResponse = response as? HTTPURLResponse {
                if !(200...299).contains(httpResponse.statusCode) {
                    throw GeminiError.httpError(statusCode: httpResponse.statusCode, response: httpResponse)
                }
            }

            // Custom validation if provided
            try validateResponse?(data, response)

            return (data, response)
        }
    }

    /// Executes an upload request with retry logic
    /// - Parameters:
    ///   - policy: Retry policy to use
    ///   - request: URLRequest to execute
    ///   - fileURL: Local file URL to upload
    /// - Returns: Response data and URLResponse
    private func uploadWithRetry(
        policy: RetryPolicy = .default,
        request: URLRequest,
        fileURL: URL
    ) async throws -> (Data, URLResponse) {
        try await retryExecutor.execute(policy: policy) {
            let (data, response) = try await self.session.upload(for: request, fromFile: fileURL)

            // Check HTTP status code
            if let httpResponse = response as? HTTPURLResponse {
                if !(200...299).contains(httpResponse.statusCode) {
                    throw GeminiError.httpError(statusCode: httpResponse.statusCode, response: httpResponse)
                }
            }

            return (data, response)
        }
    }

    // MARK: - Upload Video

    /// Upload a video file to Gemini using the resumable upload protocol.
    ///
    /// The upload happens in 3 phases:
    /// 1. **Initialize**: POST to /upload/files to get a resumable upload URL
    /// 2. **Upload**: Stream file bytes to the upload URL with progress tracking
    /// 3. **Poll**: Wait for server-side processing (ACTIVE state)
    ///
    /// - Parameters:
    ///   - localURL: Local file URL of the video to upload
    ///   - progressHandler: Optional callback for upload progress (0.0-1.0)
    /// - Returns: The Gemini fileUri for use in analysis requests
    /// - Throws: GeminiError on failure
    func uploadVideo(
        localURL: URL,
        progressHandler: ((Double) -> Void)?
    ) async throws -> String {
        guard !apiKey.isEmpty else {
            throw GeminiError.invalidAPIKey
        }

        // Validate file exists and get size for progress calculation
        guard FileManager.default.fileExists(atPath: localURL.path) else {
            throw GeminiError.uploadFailed("File does not exist")
        }

        let fileAttributes = try FileManager.default.attributesOfItem(atPath: localURL.path)
        guard let fileSize = fileAttributes[.size] as? Int64 else {
            throw GeminiError.uploadFailed("Unable to determine file size")
        }

        // Validate file size before attempting upload
        let maxSize = Constants.Video.maxUploadSizeBytes
        if fileSize > maxSize {
            AppLogger.warning("File too large for upload: \(fileSize) bytes (max: \(maxSize))", category: AppLogger.network)
            throw GeminiError.fileTooLarge(sizeBytes: fileSize, maxBytes: maxSize)
        }

        // Log warning for large files that may take a while
        if fileSize > Constants.Video.largeFileSizeWarningBytes {
            AppLogger.info("Large file upload starting: \(fileSize / (1024 * 1024))MB", category: AppLogger.network)
        }

        let mimeType = "video/mp4"

        // === PHASE 1: Initialize resumable upload ===
        // This returns a unique upload URL that accepts the file bytes
        guard let startURL = URL(string: "\(baseURL)/upload/\(Constants.API.apiVersion)/files") else {
            throw GeminiError.uploadFailed("Invalid upload URL")
        }
        var startRequest = URLRequest(url: startURL)
        startRequest.httpMethod = "POST"
        startRequest.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        startRequest.setValue("resumable", forHTTPHeaderField: "X-Goog-Upload-Protocol")
        startRequest.setValue("start", forHTTPHeaderField: "X-Goog-Upload-Command")
        startRequest.setValue("\(fileSize)", forHTTPHeaderField: "X-Goog-Upload-Header-Content-Length")
        startRequest.setValue(mimeType, forHTTPHeaderField: "X-Goog-Upload-Header-Content-Type")
        startRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let metadata = ["file": ["display_name": localURL.lastPathComponent]]
        startRequest.httpBody = try JSONSerialization.data(withJSONObject: metadata)

        // Use retry logic for initial upload request
        let (_, startResponse) = try await executeWithRetry(request: startRequest)

        guard let httpResponse = startResponse as? HTTPURLResponse,
              let uploadURL = httpResponse.value(forHTTPHeaderField: "X-Goog-Upload-URL") else {
            throw GeminiError.uploadFailed("Failed to get upload URL")
        }

        // === PHASE 2: Stream upload file bytes ===
        // Uses a dedicated URLSession with progress delegate for real-time tracking
        guard let uploadTargetURL = URL(string: uploadURL) else {
            throw GeminiError.uploadFailed("Invalid upload target URL")
        }
        var uploadRequest = URLRequest(url: uploadTargetURL)
        uploadRequest.httpMethod = "POST"
        uploadRequest.setValue("upload, finalize", forHTTPHeaderField: "X-Goog-Upload-Command")
        uploadRequest.setValue("0", forHTTPHeaderField: "X-Goog-Upload-Offset")
        uploadRequest.setValue(mimeType, forHTTPHeaderField: "Content-Type")

        // Report initial progress
        progressHandler?(0.0)

        let responseData: Data

        // Use streaming upload if progress handler is provided
        if let progressHandler = progressHandler {
            // Create dedicated URLSession with progress delegate
            // Using ephemeral config to avoid caching large video data
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 300 // 5 minutes for slow networks
            configuration.timeoutIntervalForResource = 3600 // 1 hour for large files

            // Delegate tracks upload progress and dispatches to MainActor for UI updates
            let delegate = UploadProgressDelegate(
                totalBytes: fileSize,
                progressHandler: progressHandler
            )

            let uploadSession = URLSession(
                configuration: configuration,
                delegate: delegate,
                delegateQueue: nil
            )

            defer {
                uploadSession.invalidateAndCancel()
            }

            // Use upload(for:fromFile:) for streaming from disk
            let (data, response) = try await uploadSession.upload(for: uploadRequest, fromFile: localURL)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw GeminiError.uploadFailed("Upload request failed")
            }

            responseData = data

            // Report completion
            progressHandler(1.0)
        } else {
            // Fallback to streaming upload without progress tracking
            let (data, response) = try await session.upload(for: uploadRequest, fromFile: localURL)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw GeminiError.uploadFailed("Upload request failed")
            }

            responseData = data
        }

        // Parse response to extract the fileUri (e.g., "files/abc123")
        guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let file = json["file"] as? [String: Any],
              let fileUri = file["uri"] as? String else {
            throw GeminiError.uploadFailed("Failed to parse upload response")
        }

        // === PHASE 3: Poll for processing completion ===
        // Gemini processes video server-side; we poll until state becomes ACTIVE
        try await waitForFileProcessing(fileUri: fileUri)

        return fileUri
    }

    /// Poll Gemini API until the uploaded file is ready for use.
    ///
    /// After upload, Gemini processes the video server-side. We poll the file
    /// status endpoint until the state becomes "ACTIVE" (ready) or "FAILED".
    ///
    /// Uses a custom retry policy with:
    /// - 30 attempts (allows ~60 seconds for processing)
    /// - 1-3 second delays between polls
    /// - Slow multiplier (1.1x) since we expect many polls
    private func waitForFileProcessing(fileUri: String) async throws {
        // Extract file name from URI (e.g., "files/abc123" → "abc123")
        let fileName = fileUri.components(separatedBy: "/").last ?? ""
        guard let statusURL = URL(string: "\(baseURL)/\(Constants.API.apiVersion)/files/\(fileName)") else {
            throw GeminiError.uploadFailed("Invalid status check URL")
        }

        // Custom retry policy optimized for file processing polling
        // - More attempts than default (video processing can take 30-60 seconds)
        // - Shorter delays (we want responsive status updates)
        let processingPolicy = RetryPolicy(
            maxAttempts: 30,
            initialDelay: 1.0,
            maxDelay: 3.0,
            multiplier: 1.1
        )

        try await retryExecutor.execute(policy: processingPolicy) {
            // Check for task cancellation
            try Task.checkCancellation()

            var statusRequest = URLRequest(url: statusURL)
            statusRequest.setValue(self.apiKey, forHTTPHeaderField: "x-goog-api-key")

            // Use retry for status check
            let (data, _) = try await self.executeWithRetry(
                policy: .conservative,
                request: statusRequest
            )

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let state = json["state"] as? String {
                if state == "ACTIVE" {
                    return // File is ready - success!
                } else if state == "FAILED" {
                    throw GeminiError.uploadFailed("File processing failed")
                } else {
                    // Still processing - throw error to trigger retry
                    throw GeminiError.fileProcessing
                }
            }

            // Invalid response - retry
            throw GeminiError.invalidResponse
        }
    }

    // MARK: - Analyze Video

    func analyzeVideo(
        fileUri: String,
        prompt: String
    ) async throws -> AsyncThrowingStream<String, Error> {
        let contents: [[String: Any]] = [
            [
                "role": "user",
                "parts": [
                    ["fileData": ["mimeType": "video/mp4", "fileUri": fileUri]],
                    ["text": prompt]
                ]
            ]
        ]

        return try await generateContentStream(contents: contents)
    }

    // MARK: - Chat

    func chat(
        fileUri: String,
        history: [Message],
        userMessage: String
    ) async throws -> AsyncThrowingStream<String, Error> {
        var contents: [[String: Any]] = []

        // Add system instruction with the video
        contents.append([
            "role": "user",
            "parts": [
                ["fileData": ["mimeType": "video/mp4", "fileUri": fileUri]],
                ["text": Prompts.followUpSystem]
            ]
        ])

        // Add a model acknowledgment
        contents.append([
            "role": "model",
            "parts": [["text": "好的，我会基于这段视频回答你的问题。"]]
        ])

        // Add conversation history
        for message in history {
            let role = message.role == .user ? "user" : "model"
            contents.append([
                "role": role,
                "parts": [["text": message.content]]
            ])
        }

        // Add new user message
        contents.append([
            "role": "user",
            "parts": [["text": userMessage]]
        ])

        return try await generateContentStream(contents: contents)
    }

    // MARK: - Private Helpers

    /// Create a streaming content generation request to Gemini.
    ///
    /// This method handles the SSE (Server-Sent Events) streaming protocol:
    /// 1. Send multi-turn conversation contents to streamGenerateContent endpoint
    /// 2. Parse "data: {...}" lines from the SSE stream
    /// 3. Extract text chunks from candidates[0].content.parts[0].text
    /// 4. Yield chunks via AsyncThrowingStream for real-time UI updates
    ///
    /// - Parameter contents: Array of conversation turns (user/model roles)
    /// - Returns: AsyncThrowingStream yielding text chunks as they arrive
    private func generateContentStream(
        contents: [[String: Any]]
    ) async throws -> AsyncThrowingStream<String, Error> {
        guard !apiKey.isEmpty else {
            throw GeminiError.invalidAPIKey
        }

        // Use SSE streaming endpoint (?alt=sse)
        guard let url = URL(string: "\(baseURL)/\(Constants.API.apiVersion)/models/\(model):streamGenerateContent?alt=sse") else {
            throw GeminiError.analysisFailed("Invalid API URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Request body with conversation history and generation config
        // MEDIA_RESOLUTION_MEDIUM balances quality vs. processing speed for video
        let body: [String: Any] = [
            "contents": contents,
            "generationConfig": [
                "mediaResolution": "MEDIA_RESOLUTION_MEDIUM"
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Use conservative retry policy for streaming connections
        // Streaming is more sensitive to retries - failed streams should fail fast
        let (bytes, response) = try await retryExecutor.execute(
            policy: .conservative
        ) {
            let (bytes, response) = try await self.session.bytes(for: request)

            // Validate response
            guard let httpResponse = response as? HTTPURLResponse else {
                throw GeminiError.invalidResponse
            }

            if !(200...299).contains(httpResponse.statusCode) {
                throw GeminiError.httpError(statusCode: httpResponse.statusCode, response: httpResponse)
            }

            return (bytes, response)
        }

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in bytes.lines {
                        // Check for task cancellation
                        try Task.checkCancellation()

                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))
                            if let data = jsonString.data(using: .utf8),
                               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let candidates = json["candidates"] as? [[String: Any]],
                               let firstCandidate = candidates.first,
                               let content = firstCandidate["content"] as? [String: Any],
                               let parts = content["parts"] as? [[String: Any]],
                               let firstPart = parts.first,
                               let text = firstPart["text"] as? String {
                                continuation.yield(text)
                            }
                        }
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: GeminiError.uploadCancelled)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
