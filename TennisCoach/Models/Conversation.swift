import Foundation
import SwiftData

/// Represents a conversation/analysis session for a video
@Model
final class Conversation {
    @Attribute(.unique) var id: UUID
    var video: Video?
    var title: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Message.conversation)
    var messages: [Message] = []

    init(
        id: UUID = UUID(),
        video: Video? = nil,
        title: String = "New Analysis",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.video = video
        self.title = title
        self.createdAt = createdAt
    }

    /// Returns messages sorted by timestamp
    var sortedMessages: [Message] {
        messages.sorted { $0.timestamp < $1.timestamp }
    }
}
