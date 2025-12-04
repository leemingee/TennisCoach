import XCTest
@testable import TennisCoach

// MARK: - Mock URLSession

class MockURLSession: URLSession {
    var mockData: Data?
    var mockResponse: URLResponse?
    var mockError: Error?
    var mockBytesResponse: (Data, URLResponse)?

    override func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if let error = mockError {
            throw error
        }
        return (mockData ?? Data(), mockResponse ?? URLResponse())
    }

    override func data(from url: URL) async throws -> (Data, URLResponse) {
        if let error = mockError {
            throw error
        }
        return (mockData ?? Data(), mockResponse ?? URLResponse())
    }
}

// MARK: - Mock GeminiService

class MockGeminiService: GeminiServicing {
    var uploadVideoResult: Result<String, Error> = .success("files/mock-file-uri")
    var analyzeVideoResult: Result<String, Error> = .success("Mock analysis result")
    var chatResult: Result<String, Error> = .success("Mock chat response")

    var uploadVideoCallCount = 0
    var analyzeVideoCallCount = 0
    var chatCallCount = 0

    var lastAnalyzePrompt: String?
    var lastChatHistory: [Message]?
    var lastChatMessage: String?

    func uploadVideo(localURL: URL) async throws -> String {
        uploadVideoCallCount += 1
        switch uploadVideoResult {
        case .success(let uri):
            return uri
        case .failure(let error):
            throw error
        }
    }

    func analyzeVideo(fileUri: String, prompt: String) async throws -> AsyncThrowingStream<String, Error> {
        analyzeVideoCallCount += 1
        lastAnalyzePrompt = prompt

        switch analyzeVideoResult {
        case .success(let response):
            return AsyncThrowingStream { continuation in
                // Simulate streaming by yielding chunks
                let words = response.split(separator: " ")
                for word in words {
                    continuation.yield(String(word) + " ")
                }
                continuation.finish()
            }
        case .failure(let error):
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: error)
            }
        }
    }

    func chat(fileUri: String, history: [Message], userMessage: String) async throws -> AsyncThrowingStream<String, Error> {
        chatCallCount += 1
        lastChatHistory = history
        lastChatMessage = userMessage

        switch chatResult {
        case .success(let response):
            return AsyncThrowingStream { continuation in
                continuation.yield(response)
                continuation.finish()
            }
        case .failure(let error):
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: error)
            }
        }
    }
}

// MARK: - Tests

final class GeminiServiceTests: XCTestCase {

    // MARK: - Error Tests

    func testGeminiErrorDescriptions() {
        XCTAssertNotNil(GeminiError.invalidAPIKey.errorDescription)
        XCTAssertTrue(GeminiError.invalidAPIKey.errorDescription!.contains("API Key"))

        XCTAssertNotNil(GeminiError.uploadFailed("test").errorDescription)
        XCTAssertTrue(GeminiError.uploadFailed("test error").errorDescription!.contains("test error"))

        XCTAssertNotNil(GeminiError.fileProcessing.errorDescription)
        XCTAssertNotNil(GeminiError.analysisFaild("test").errorDescription)
        XCTAssertNotNil(GeminiError.invalidResponse.errorDescription)
    }

    // MARK: - Mock Service Tests

    func testMockServiceUpload() async throws {
        let mockService = MockGeminiService()
        let testURL = URL(fileURLWithPath: "/test/video.mp4")

        let result = try await mockService.uploadVideo(localURL: testURL)

        XCTAssertEqual(result, "files/mock-file-uri")
        XCTAssertEqual(mockService.uploadVideoCallCount, 1)
    }

    func testMockServiceUploadFailure() async {
        let mockService = MockGeminiService()
        mockService.uploadVideoResult = .failure(GeminiError.uploadFailed("Network error"))

        let testURL = URL(fileURLWithPath: "/test/video.mp4")

        do {
            _ = try await mockService.uploadVideo(localURL: testURL)
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertTrue(error is GeminiError)
        }
    }

    func testMockServiceAnalyze() async throws {
        let mockService = MockGeminiService()
        mockService.analyzeVideoResult = .success("This is the analysis")

        let stream = try await mockService.analyzeVideo(
            fileUri: "files/test",
            prompt: "Analyze this video"
        )

        var result = ""
        for try await chunk in stream {
            result += chunk
        }

        XCTAssertEqual(mockService.analyzeVideoCallCount, 1)
        XCTAssertEqual(mockService.lastAnalyzePrompt, "Analyze this video")
        XCTAssertFalse(result.isEmpty)
    }

    func testMockServiceChat() async throws {
        let mockService = MockGeminiService()

        let history = [
            Message(role: .user, content: "Previous question"),
            Message(role: .assistant, content: "Previous answer")
        ]

        let stream = try await mockService.chat(
            fileUri: "files/test",
            history: history,
            userMessage: "New question"
        )

        var result = ""
        for try await chunk in stream {
            result += chunk
        }

        XCTAssertEqual(mockService.chatCallCount, 1)
        XCTAssertEqual(mockService.lastChatHistory?.count, 2)
        XCTAssertEqual(mockService.lastChatMessage, "New question")
        XCTAssertEqual(result, "Mock chat response")
    }

    // MARK: - API Key Validation

    func testServiceWithEmptyAPIKey() async {
        let service = GeminiService(apiKey: "")
        let testURL = URL(fileURLWithPath: "/test/video.mp4")

        do {
            _ = try await service.uploadVideo(localURL: testURL)
            XCTFail("Should have thrown invalidAPIKey error")
        } catch let error as GeminiError {
            XCTAssertEqual(error, .invalidAPIKey)
        } catch {
            XCTFail("Unexpected error type")
        }
    }
}

// MARK: - GeminiError Equatable

extension GeminiError: Equatable {
    public static func == (lhs: GeminiError, rhs: GeminiError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidAPIKey, .invalidAPIKey):
            return true
        case (.uploadFailed(let l), .uploadFailed(let r)):
            return l == r
        case (.fileProcessing, .fileProcessing):
            return true
        case (.analysisFaild(let l), .analysisFaild(let r)):
            return l == r
        case (.invalidResponse, .invalidResponse):
            return true
        case (.networkError, .networkError):
            return true
        default:
            return false
        }
    }
}
