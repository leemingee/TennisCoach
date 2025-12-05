import Foundation

enum Constants {
    enum API {
        static let geminiBaseURL = "https://generativelanguage.googleapis.com"
        static let geminiModel = "gemini-3-pro-preview"
        static let apiVersion = "v1beta"

        // MARK: - API Key
        /// Retrieves the Gemini API key from secure storage.
        ///
        /// The key is fetched from the Keychain first, falling back to environment variables
        /// for development/testing purposes. In production, always use the Keychain.
        ///
        /// - Returns: The API key if available, empty string otherwise
        static var apiKey: String {
            // Try Keychain first (production)
            if let keychainKey = try? SecureKeyManager.shared.getGeminiAPIKey(),
               !keychainKey.isEmpty {
                return keychainKey
            }

            // Fall back to environment variable (development only)
            if let envKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"],
               !envKey.isEmpty {
                // Optionally save to Keychain for next time
                try? SecureKeyManager.shared.saveGeminiAPIKey(envKey)
                return envKey
            }

            return ""
        }

        /// Checks if a valid API key is configured.
        ///
        /// - Returns: True if an API key is available, false otherwise
        static var hasAPIKey: Bool {
            !apiKey.isEmpty
        }
    }

    enum Video {
        /// Preferred frame rate for recording
        /// 60fps captures fast tennis movements better for AI analysis
        static let preferredFPS: Float = 60

        /// Thumbnail generation size
        static let thumbnailSize = CGSize(width: 200, height: 150)

        // MARK: - File Size Limits

        /// Maximum file size for Gemini upload (100MB)
        /// Gemini has processing limits; larger files may timeout or fail
        static let maxUploadSizeBytes: Int64 = 100 * 1024 * 1024

        /// Warning threshold for large files (50MB)
        /// Files above this size may take longer to upload and process
        static let largeFileSizeWarningBytes: Int64 = 50 * 1024 * 1024

        // MARK: - Recording Duration Limits
        // Based on iPhone video file sizes with H.264 codec:
        // - 1080p @ 60fps ≈ 175-200 MB/minute
        // - 1080p @ 30fps ≈ 125-150 MB/minute
        // For 100MB limit with safety margin:

        /// Maximum recording duration for 1080p @ 60fps (current setting)
        /// ~175-200 MB/minute → 30 seconds safe limit for 100MB
        static let maxDuration60fps: TimeInterval = 30

        /// Maximum recording duration for 1080p @ 30fps
        /// ~125-150 MB/minute → 45 seconds safe limit for 100MB
        static let maxDuration30fps: TimeInterval = 45

        /// Default max duration based on current FPS setting
        static var maxDuration: TimeInterval {
            preferredFPS >= 60 ? maxDuration60fps : maxDuration30fps
        }

        /// Warning threshold before max duration (10 seconds before limit)
        static var durationWarningThreshold: TimeInterval {
            maxDuration - 10
        }

        // MARK: - Future: Video Splitting
        // TODO: Implement video splitting for recordings longer than maxDuration
        // - Split into segments at maxDuration boundaries
        // - Upload and analyze each segment separately
        // - Combine AI responses with segment context
    }

    enum Storage {
        static let videosDirectory = "RecordedVideos"
    }
}
