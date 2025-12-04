import Foundation

// MARK: - Protocol

/// Protocol for Gemini API service
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

        case .uploadFailed, .analysisFailed:
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

/// URLSession delegate for tracking upload progress
@MainActor
final class UploadProgressDelegate: NSObject, URLSessionTaskDelegate, Sendable {
    private let progressHandler: @Sendable (Double) -> Void
    private let totalBytes: Int64

    init(totalBytes: Int64, progressHandler: @escaping @Sendable (Double) -> Void) {
        self.totalBytes = totalBytes
        self.progressHandler = progressHandler
        super.init()
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        let total = totalBytesExpectedToSend > 0 ? totalBytesExpectedToSend : totalBytes
        let progress = Double(totalBytesSent) / Double(total)

        Task { @MainActor in
            progressHandler(progress)
        }
    }
}

// MARK: - Implementation

final class GeminiService: GeminiServicing {

    private let apiKey: String
    private let baseURL: String
    private let model: String
    private let session: URLSession
    private let retryExecutor: RetryExecutor

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

    func uploadVideo(
        localURL: URL,
        progressHandler: ((Double) -> Void)?
    ) async throws -> String {
        guard !apiKey.isEmpty else {
            throw GeminiError.invalidAPIKey
        }

        // Validate file exists and get attributes
        guard FileManager.default.fileExists(atPath: localURL.path) else {
            throw GeminiError.uploadFailed("File does not exist")
        }

        let fileAttributes = try FileManager.default.attributesOfItem(atPath: localURL.path)
        guard let fileSize = fileAttributes[.size] as? Int64 else {
            throw GeminiError.uploadFailed("Unable to determine file size")
        }

        let mimeType = "video/mp4"

        // Step 1: Start resumable upload with retry logic
        let startURL = URL(string: "\(baseURL)/upload/\(Constants.API.apiVersion)/files")!
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

        // Step 2: Stream upload the file data
        var uploadRequest = URLRequest(url: URL(string: uploadURL)!)
        uploadRequest.httpMethod = "POST"
        uploadRequest.setValue("upload, finalize", forHTTPHeaderField: "X-Goog-Upload-Command")
        uploadRequest.setValue("0", forHTTPHeaderField: "X-Goog-Upload-Offset")
        uploadRequest.setValue(mimeType, forHTTPHeaderField: "Content-Type")

        // Report initial progress
        progressHandler?(0.0)

        let responseData: Data

        // Use streaming upload if progress handler is provided
        if let progressHandler = progressHandler {
            // Create dedicated session with progress delegate
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 300 // 5 minutes
            configuration.timeoutIntervalForResource = 3600 // 1 hour

            let delegate = await UploadProgressDelegate(
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

        // Parse the response to get fileUri
        guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let file = json["file"] as? [String: Any],
              let fileUri = file["uri"] as? String else {
            throw GeminiError.uploadFailed("Failed to parse upload response")
        }

        // Step 3: Wait for file to be processed
        try await waitForFileProcessing(fileUri: fileUri)

        return fileUri
    }

    private func waitForFileProcessing(fileUri: String) async throws {
        // Extract file name from URI
        let fileName = fileUri.components(separatedBy: "/").last ?? ""
        let statusURL = URL(string: "\(baseURL)/\(Constants.API.apiVersion)/files/\(fileName)")!

        // Custom retry policy for file processing: more attempts, longer delays
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

    private func generateContentStream(
        contents: [[String: Any]]
    ) async throws -> AsyncThrowingStream<String, Error> {
        guard !apiKey.isEmpty else {
            throw GeminiError.invalidAPIKey
        }

        let url = URL(string: "\(baseURL)/\(Constants.API.apiVersion)/models/\(model):streamGenerateContent?alt=sse")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "contents": contents,
            "generationConfig": [
                "mediaResolution": "MEDIA_RESOLUTION_MEDIUM"
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Use retry logic for streaming request with conservative policy
        // (streaming connections are more sensitive to retries)
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
