import Foundation
import SwiftData

/// Represents a recorded tennis video
@Model
final class Video {
    @Attribute(.unique) var id: UUID
    var localPath: String
    var geminiFileUri: String?
    var duration: TimeInterval
    var thumbnailData: Data?
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Conversation.video)
    var conversations: [Conversation] = []

    init(
        id: UUID = UUID(),
        localPath: String,
        duration: TimeInterval = 0,
        thumbnailData: Data? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.localPath = localPath
        self.duration = duration
        self.thumbnailData = thumbnailData
        self.createdAt = createdAt
    }

    /// Returns the local file URL
    var localURL: URL? {
        // Handle both file:// URLs and plain paths
        if localPath.hasPrefix("file://") {
            return URL(string: localPath)
        }
        return URL(fileURLWithPath: localPath)
    }

    /// Formatted duration string (e.g., "1:30")
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
