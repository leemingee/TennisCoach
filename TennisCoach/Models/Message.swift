import Foundation
import SwiftData

/// Role of the message sender
enum MessageRole: String, Codable {
    case user
    case assistant
}

/// Represents a single message in a conversation
@Model
final class Message {
    @Attribute(.unique) var id: UUID
    var conversation: Conversation?
    var roleRawValue: String
    var content: String
    var timestamp: Date

    var role: MessageRole {
        get { MessageRole(rawValue: roleRawValue) ?? .user }
        set { roleRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        conversation: Conversation? = nil,
        role: MessageRole,
        content: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.conversation = conversation
        self.roleRawValue = role.rawValue
        self.content = content
        self.timestamp = timestamp
    }
}
