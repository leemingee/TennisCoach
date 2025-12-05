import XCTest
import SwiftData
@testable import TennisCoach

@MainActor
final class ChatViewModelTests: XCTestCase {

    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([Video.self, Conversation.self, Message.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = ModelContext(modelContainer)
    }

    override func tearDownWithError() throws {
        modelContainer = nil
        modelContext = nil
    }

    // MARK: - Initialization Tests

    func testViewModelInitialization() {
        let video = Video(localPath: "test.mp4")
        let viewModel = ChatViewModel(video: video)

        XCTAssertTrue(viewModel.messages.isEmpty)
        XCTAssertTrue(viewModel.inputText.isEmpty)
        XCTAssertTrue(viewModel.streamingText.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(viewModel.showError)
    }

    // MARK: - Can Send Tests

    func testCanSendWithEmptyInput() {
        let video = Video(localPath: "test.mp4")
        let viewModel = ChatViewModel(video: video)

        viewModel.inputText = ""
        XCTAssertFalse(viewModel.canSend)

        viewModel.inputText = "   "
        XCTAssertFalse(viewModel.canSend)

        viewModel.inputText = "\n\t"
        XCTAssertFalse(viewModel.canSend)
    }

    func testCanSendWithValidInput() {
        let video = Video(localPath: "test.mp4")
        let viewModel = ChatViewModel(video: video)

        viewModel.inputText = "Hello"
        XCTAssertTrue(viewModel.canSend)
    }

    func testCanSendWhileLoading() {
        let video = Video(localPath: "test.mp4")
        let viewModel = ChatViewModel(video: video)

        viewModel.inputText = "Hello"
        viewModel.isLoading = true
        XCTAssertFalse(viewModel.canSend)
    }

    // MARK: - Load Conversation Tests

    func testLoadExistingConversation() async throws {
        let video = Video(localPath: "test.mp4")
        let conversation = Conversation(video: video, title: "Existing")
        let message = Message(conversation: conversation, role: .user, content: "Test message")

        video.conversations.append(conversation)
        conversation.messages.append(message)

        modelContext.insert(video)
        modelContext.insert(conversation)
        modelContext.insert(message)
        try modelContext.save()

        let mockService = MockGeminiService()
        let viewModel = ChatViewModel(video: video, geminiService: mockService)

        await viewModel.loadConversation(modelContext: modelContext)

        // Should load existing conversation without calling API
        XCTAssertEqual(mockService.uploadVideoCallCount, 0)
        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages.first?.content, "Test message")
    }

    func testLoadNewConversationStartsAnalysis() async throws {
        let video = Video(localPath: "file:///test/video.mp4")
        modelContext.insert(video)
        try modelContext.save()

        let mockService = MockGeminiService()
        mockService.analyzeVideoResult = .success("Analysis complete")

        let viewModel = ChatViewModel(video: video, geminiService: mockService)
        await viewModel.loadConversation(modelContext: modelContext)

        // Should upload and analyze
        XCTAssertEqual(mockService.uploadVideoCallCount, 1)
        XCTAssertEqual(mockService.analyzeVideoCallCount, 1)

        // Should have user message + assistant response
        XCTAssertEqual(viewModel.messages.count, 2)
    }

    // MARK: - Send Message Tests

    func testSendMessageClearsInput() async throws {
        let video = Video(localPath: "test.mp4")
        video.geminiFileUri = "files/existing-uri"

        let mockService = MockGeminiService()
        let viewModel = ChatViewModel(video: video, geminiService: mockService)

        viewModel.inputText = "My question"

        await viewModel.sendMessage(modelContext: modelContext)

        XCTAssertTrue(viewModel.inputText.isEmpty)
    }

    func testSendMessageAddsToHistory() async throws {
        let video = Video(localPath: "test.mp4")
        video.geminiFileUri = "files/existing-uri"

        let mockService = MockGeminiService()
        let viewModel = ChatViewModel(video: video, geminiService: mockService)

        viewModel.inputText = "My question"
        await viewModel.sendMessage(modelContext: modelContext)

        // Should have user message and assistant response
        XCTAssertEqual(viewModel.messages.count, 2)
        XCTAssertEqual(viewModel.messages[0].role, .user)
        XCTAssertEqual(viewModel.messages[0].content, "My question")
        XCTAssertEqual(viewModel.messages[1].role, .assistant)
    }

    func testSendMessageWithoutFileUri() async throws {
        let video = Video(localPath: "test.mp4")
        // No geminiFileUri set

        let mockService = MockGeminiService()
        let viewModel = ChatViewModel(video: video, geminiService: mockService)

        viewModel.inputText = "My question"
        await viewModel.sendMessage(modelContext: modelContext)

        // Should show error
        XCTAssertTrue(viewModel.showError)
        XCTAssertFalse(viewModel.errorMessage.isEmpty)
    }

    // MARK: - Error Handling Tests

    func testAnalysisErrorShowsAlert() async throws {
        let video = Video(localPath: "file:///test/video.mp4")
        modelContext.insert(video)
        try modelContext.save()

        let mockService = MockGeminiService()
        mockService.analyzeVideoResult = .failure(GeminiError.analysisFailed("Test error"))

        let viewModel = ChatViewModel(video: video, geminiService: mockService)
        await viewModel.loadConversation(modelContext: modelContext)

        XCTAssertTrue(viewModel.showError)
        XCTAssertFalse(viewModel.errorMessage.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testChatErrorShowsAlert() async throws {
        let video = Video(localPath: "test.mp4")
        video.geminiFileUri = "files/existing-uri"

        let mockService = MockGeminiService()
        mockService.chatResult = .failure(GeminiError.networkError(NSError(domain: "", code: -1)))

        let viewModel = ChatViewModel(video: video, geminiService: mockService)

        viewModel.inputText = "My question"
        await viewModel.sendMessage(modelContext: modelContext)

        XCTAssertTrue(viewModel.showError)
        XCTAssertFalse(viewModel.isLoading)
    }
}
