import Foundation

/// Validates and manages API key availability for the application.
///
/// This utility provides methods to check API key configuration and guide users
/// through the setup process if needed.
@available(iOS 13.0, macOS 10.15, *)
enum APIKeyValidator {

    // MARK: - Validation

    /// Validates that a Gemini API key is properly configured.
    ///
    /// - Returns: True if a valid API key exists, false otherwise
    static func isAPIKeyConfigured() -> Bool {
        Constants.API.hasAPIKey
    }

    /// Retrieves the configured API key if available.
    ///
    /// - Returns: The API key, or nil if not configured
    static func getConfiguredAPIKey() -> String? {
        let key = Constants.API.apiKey
        return key.isEmpty ? nil : key
    }

    /// Validates the format of an API key string.
    ///
    /// This performs basic format validation without making API calls.
    ///
    /// - Parameter apiKey: The API key to validate
    /// - Returns: True if the format appears valid, false otherwise
    static func isValidFormat(_ apiKey: String) -> Bool {
        // Gemini API keys typically start with "AIza" and are 39 characters
        guard !apiKey.isEmpty else { return false }
        guard apiKey.count >= 20 else { return false }

        // Check for common patterns in Google API keys
        let hasValidPrefix = apiKey.hasPrefix("AIza")
        let hasReasonableLength = apiKey.count >= 30 && apiKey.count <= 50

        return hasValidPrefix && hasReasonableLength
    }

    /// Validates an API key by making a test request to the Gemini API.
    ///
    /// - Parameter apiKey: The API key to validate
    /// - Returns: True if the key is valid, false otherwise
    /// - Throws: Network or API errors
    static func validateWithAPI(_ apiKey: String) async throws -> Bool {
        guard isValidFormat(apiKey) else {
            return false
        }

        // Construct a minimal test request
        let endpoint = "\(Constants.API.geminiBaseURL)/\(Constants.API.apiVersion)/models/\(Constants.API.geminiModel):generateContent"
        guard var components = URLComponents(string: endpoint) else {
            return false
        }

        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey)
        ]

        guard let url = components.url else {
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Minimal test payload
        let testPayload: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": "test"]
                    ]
                ]
            ]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: testPayload)

        // Make the request
        let (_, response) = try await URLSession.shared.data(for: request)

        // Check if we got a valid response (not 401/403)
        if let httpResponse = response as? HTTPURLResponse {
            return httpResponse.statusCode != 401 && httpResponse.statusCode != 403
        }

        return false
    }

    // MARK: - Setup Guidance

    /// Determines if the app should show API key setup to the user.
    ///
    /// - Returns: True if setup should be shown, false otherwise
    static func shouldShowSetup() -> Bool {
        !isAPIKeyConfigured()
    }

    /// Provides a user-friendly message about the API key status.
    ///
    /// - Returns: A status message for display to users
    static func getStatusMessage() -> String {
        if isAPIKeyConfigured() {
            return "API key is configured and ready."
        } else {
            return "No API key configured. Please add your Gemini API key to continue."
        }
    }

    /// Generates a help URL for obtaining a Gemini API key.
    ///
    /// - Returns: URL to Google AI Studio for API key generation
    static func getAPIKeyHelpURL() -> URL? {
        URL(string: "https://aistudio.google.com/apikey")
    }

    // MARK: - Migration Support

    /// Attempts to migrate API key from environment variables to Keychain.
    ///
    /// This should be called once during app initialization to ensure
    /// development keys are properly stored in the Keychain.
    ///
    /// - Returns: True if migration occurred, false otherwise
    @discardableResult
    static func migrateFromEnvironmentIfNeeded() -> Bool {
        // Check if already in Keychain
        if SecureKeyManager.shared.hasGeminiAPIKey() {
            return false
        }

        // Try to get from environment
        guard let envKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"],
              !envKey.isEmpty else {
            return false
        }

        // Migrate to Keychain
        do {
            try SecureKeyManager.shared.saveGeminiAPIKey(envKey)
            return true
        } catch {
            AppLogger.error("Failed to migrate API key: \(error.localizedDescription)", category: AppLogger.data)
            return false
        }
    }

    // MARK: - Diagnostic Information

    /// Provides diagnostic information about API key configuration.
    ///
    /// - Returns: A dictionary with diagnostic details
    static func getDiagnostics() -> [String: Any] {
        var diagnostics: [String: Any] = [:]

        // Check Keychain
        let hasKeychainKey = SecureKeyManager.shared.hasGeminiAPIKey()
        diagnostics["keychain_configured"] = hasKeychainKey

        // Check environment
        let hasEnvKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] != nil
        diagnostics["environment_variable_set"] = hasEnvKey

        // Check final resolved key
        let hasResolvedKey = !Constants.API.apiKey.isEmpty
        diagnostics["resolved_key_available"] = hasResolvedKey

        // Key format validation (without revealing the key)
        if hasResolvedKey {
            let key = Constants.API.apiKey
            diagnostics["key_length"] = key.count
            diagnostics["key_prefix_valid"] = key.hasPrefix("AIza")
            diagnostics["key_format_valid"] = isValidFormat(key)
        }

        return diagnostics
    }

    /// Logs diagnostic information for debugging API key configuration issues.
    ///
    /// Uses AppLogger.data for structured logging instead of print statements.
    static func printDiagnostics() {
        AppLogger.debug("=== API Key Diagnostics ===", category: AppLogger.data)
        let diagnostics = getDiagnostics()
        for (key, value) in diagnostics.sorted(by: { $0.key < $1.key }) {
            AppLogger.debug("\(key): \(value)", category: AppLogger.data)
        }
        AppLogger.debug("=========================", category: AppLogger.data)
    }
}

// MARK: - SwiftUI Integration

#if canImport(SwiftUI)
import SwiftUI

@available(iOS 14.0, macOS 11.0, *)
extension View {
    /// Presents API key setup if not configured.
    ///
    /// Example:
    /// ```swift
    /// ContentView()
    ///     .requireAPIKey()
    /// ```
    func requireAPIKey() -> some View {
        modifier(APIKeyRequirementModifier())
    }
}

@available(iOS 14.0, macOS 11.0, *)
private struct APIKeyRequirementModifier: ViewModifier {
    @State private var showingSetup = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                showingSetup = APIKeyValidator.shouldShowSetup()
            }
            .sheet(isPresented: $showingSetup) {
                if #available(iOS 15.0, macOS 12.0, *) {
                    APIKeySetupView()
                } else {
                    Text("Please configure your API key in Settings")
                }
            }
    }
}

@available(iOS 14.0, macOS 11.0, *)
extension APIKeyValidator {
    /// Creates a view that shows API key status with an action button.
    ///
    /// - Returns: A SwiftUI view displaying API key status
    static func statusView() -> some View {
        APIKeyStatusView()
    }
}

@available(iOS 14.0, macOS 11.0, *)
private struct APIKeyStatusView: View {
    @State private var isConfigured = APIKeyValidator.isAPIKeyConfigured()
    @State private var showingSetup = false

    var body: some View {
        HStack {
            Image(systemName: isConfigured ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(isConfigured ? .green : .orange)

            Text(APIKeyValidator.getStatusMessage())
                .font(.subheadline)

            Spacer()

            if !isConfigured {
                Button("Setup") {
                    showingSetup = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
        .sheet(isPresented: $showingSetup) {
            if #available(iOS 15.0, macOS 12.0, *) {
                APIKeySetupView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            isConfigured = APIKeyValidator.isAPIKeyConfigured()
        }
    }
}
#endif
