import XCTest
import SwiftData
@testable import TennisCoach

final class ModelTests: XCTestCase {

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

    // MARK: - Video Tests

    func testVideoCreation() throws {
        let video = Video(localPath: "file:///test/video.mp4", duration: 120)

        modelContext.insert(video)
        try modelContext.save()

        let fetchDescriptor = FetchDescriptor<Video>()
        let videos = try modelContext.fetch(fetchDescriptor)

        XCTAssertEqual(videos.count, 1)
        XCTAssertEqual(videos.first?.localPath, "file:///test/video.mp4")
        XCTAssertEqual(videos.first?.duration, 120)
    }

    func testVideoFormattedDuration() {
        let video1 = Video(localPath: "test.mp4", duration: 90)
        XCTAssertEqual(video1.formattedDuration, "1:30")

        let video2 = Video(localPath: "test.mp4", duration: 65)
        XCTAssertEqual(video2.formattedDuration, "1:05")

        let video3 = Video(localPath: "test.mp4", duration: 3661)
        XCTAssertEqual(video3.formattedDuration, "61:01")
    }

    func testVideoLocalURL() {
        let video = Video(localPath: "file:///test/video.mp4")
        XCTAssertNotNil(video.localURL)
        XCTAssertEqual(video.localURL?.absoluteString, "file:///test/video.mp4")
    }

    // MARK: - Conversation Tests

    func testConversationCreation() throws {
        let video = Video(localPath: "test.mp4")
        let conversation = Conversation(video: video, title: "Test Analysis")

        modelContext.insert(video)
        modelContext.insert(conversation)
        try modelContext.save()

        let fetchDescriptor = FetchDescriptor<Conversation>()
        let conversations = try modelContext.fetch(fetchDescriptor)

        XCTAssertEqual(conversations.count, 1)
        XCTAssertEqual(conversations.first?.title, "Test Analysis")
        XCTAssertNotNil(conversations.first?.video)
    }

    func testConversationSortedMessages() throws {
        let conversation = Conversation(title: "Test")

        let message1 = Message(
            conversation: conversation,
            role: .user,
            content: "First",
            timestamp: Date(timeIntervalSince1970: 1000)
        )

        let message2 = Message(
            conversation: conversation,
            role: .assistant,
            content: "Second",
            timestamp: Date(timeIntervalSince1970: 2000)
        )

        let message3 = Message(
            conversation: conversation,
            role: .user,
            content: "Third",
            timestamp: Date(timeIntervalSince1970: 1500)
        )

        conversation.messages = [message1, message2, message3]

        let sorted = conversation.sortedMessages
        XCTAssertEqual(sorted[0].content, "First")
        XCTAssertEqual(sorted[1].content, "Third")
        XCTAssertEqual(sorted[2].content, "Second")
    }

    // MARK: - Message Tests

    func testMessageCreation() throws {
        let message = Message(role: .user, content: "Test message")

        modelContext.insert(message)
        try modelContext.save()

        let fetchDescriptor = FetchDescriptor<Message>()
        let messages = try modelContext.fetch(fetchDescriptor)

        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages.first?.role, .user)
        XCTAssertEqual(messages.first?.content, "Test message")
    }

    func testMessageRole() {
        let userMessage = Message(role: .user, content: "User message")
        XCTAssertEqual(userMessage.role, .user)
        XCTAssertEqual(userMessage.roleRawValue, "user")

        let assistantMessage = Message(role: .assistant, content: "Assistant message")
        XCTAssertEqual(assistantMessage.role, .assistant)
        XCTAssertEqual(assistantMessage.roleRawValue, "assistant")
    }

    // MARK: - Relationship Tests

    func testVideoConversationRelationship() throws {
        let video = Video(localPath: "test.mp4")
        let conversation1 = Conversation(video: video, title: "Analysis 1")
        let conversation2 = Conversation(video: video, title: "Analysis 2")

        modelContext.insert(video)
        modelContext.insert(conversation1)
        modelContext.insert(conversation2)
        try modelContext.save()

        XCTAssertEqual(video.conversations.count, 2)
    }

    func testConversationMessageRelationship() throws {
        let conversation = Conversation(title: "Test")
        let message1 = Message(conversation: conversation, role: .user, content: "Hello")
        let message2 = Message(conversation: conversation, role: .assistant, content: "Hi")

        modelContext.insert(conversation)
        modelContext.insert(message1)
        modelContext.insert(message2)
        try modelContext.save()

        XCTAssertEqual(conversation.messages.count, 2)
    }

    func testCascadeDelete() throws {
        let video = Video(localPath: "test.mp4")
        let conversation = Conversation(video: video, title: "Test")
        let message = Message(conversation: conversation, role: .user, content: "Hello")

        video.conversations.append(conversation)
        conversation.messages.append(message)

        modelContext.insert(video)
        modelContext.insert(conversation)
        modelContext.insert(message)
        try modelContext.save()

        // Delete video
        modelContext.delete(video)
        try modelContext.save()

        // Verify cascade delete
        let conversationDescriptor = FetchDescriptor<Conversation>()
        let conversations = try modelContext.fetch(conversationDescriptor)
        XCTAssertEqual(conversations.count, 0)

        let messageDescriptor = FetchDescriptor<Message>()
        let messages = try modelContext.fetch(messageDescriptor)
        XCTAssertEqual(messages.count, 0)
    }
}
