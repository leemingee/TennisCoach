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
        static let maxDuration: TimeInterval = 300 // 5 minutes
        static let preferredFPS: Float = 60
        static let thumbnailSize = CGSize(width: 200, height: 150)
    }

    enum Storage {
        static let videosDirectory = "RecordedVideos"
    }
}
