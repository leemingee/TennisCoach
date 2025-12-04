import Foundation
import Security

/// Secure manager for storing and retrieving sensitive data using the iOS Keychain.
///
/// This manager provides thread-safe operations for storing API keys and other sensitive
/// credentials using Apple's Security framework. All operations use proper access control
/// and error handling to ensure data security.
///
/// Example usage:
/// ```swift
/// // Save API key
/// try SecureKeyManager.shared.save(key: "my-api-key", forService: .geminiAPI)
///
/// // Retrieve API key
/// if let apiKey = try SecureKeyManager.shared.get(forService: .geminiAPI) {
///     print("Retrieved key: \(apiKey)")
/// }
///
/// // Delete API key
/// try SecureKeyManager.shared.delete(forService: .geminiAPI)
/// ```
@available(iOS 13.0, macOS 10.15, *)
final class SecureKeyManager {

    // MARK: - Singleton

    /// Shared instance for application-wide keychain access
    static let shared = SecureKeyManager()

    // MARK: - Service Identifiers

    /// Predefined service identifiers for different types of keys
    enum ServiceIdentifier: String {
        case geminiAPI = "com.tenniscoach.gemini.apikey"

        /// Returns the full service identifier with bundle ID prefix
        var serviceKey: String {
            guard let bundleID = Bundle.main.bundleIdentifier else {
                return rawValue
            }
            return "\(bundleID).\(rawValue)"
        }
    }

    // MARK: - Error Types

    /// Errors that can occur during Keychain operations
    enum KeychainError: LocalizedError {
        case duplicateItem
        case itemNotFound
        case invalidData
        case unexpectedStatus(OSStatus)
        case encodingFailed
        case decodingFailed

        var errorDescription: String? {
            switch self {
            case .duplicateItem:
                return "An item with this service already exists in the Keychain."
            case .itemNotFound:
                return "The requested item was not found in the Keychain."
            case .invalidData:
                return "The data stored in the Keychain is invalid."
            case .unexpectedStatus(let status):
                return "Keychain operation failed with status: \(status)"
            case .encodingFailed:
                return "Failed to encode data for Keychain storage."
            case .decodingFailed:
                return "Failed to decode data from Keychain."
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .duplicateItem:
                return "Try updating the existing item or delete it first."
            case .itemNotFound:
                return "Ensure the item has been saved before attempting to retrieve it."
            case .invalidData:
                return "The stored data may be corrupted. Try deleting and re-saving."
            case .unexpectedStatus:
                return "Check system logs for more details about the Keychain error."
            case .encodingFailed, .decodingFailed:
                return "Ensure the data being stored is valid UTF-8 text."
            }
        }
    }

    // MARK: - Private Properties

    private let queue = DispatchQueue(label: "com.tenniscoach.securekeymanager", attributes: .concurrent)

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Saves a key securely to the Keychain.
    ///
    /// This method stores the provided key with appropriate access control, ensuring
    /// it's only accessible when the device is unlocked and is not backed up to iCloud.
    ///
    /// - Parameters:
    ///   - key: The secret key to store (e.g., API key, token)
    ///   - service: The service identifier for this key
    /// - Throws: `KeychainError` if the save operation fails
    func save(key: String, forService service: ServiceIdentifier) throws {
        guard let data = key.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        try queue.sync(flags: .barrier) {
            // First, delete any existing item
            try? deleteInternal(forService: service)

            // Prepare query for adding new item
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service.serviceKey,
                kSecAttrAccount as String: service.rawValue,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]

            let status = SecItemAdd(query as CFDictionary, nil)

            guard status == errSecSuccess else {
                if status == errSecDuplicateItem {
                    throw KeychainError.duplicateItem
                }
                throw KeychainError.unexpectedStatus(status)
            }
        }
    }

    /// Retrieves a key from the Keychain.
    ///
    /// - Parameter service: The service identifier for the key to retrieve
    /// - Returns: The stored key as a String, or nil if not found
    /// - Throws: `KeychainError` if the retrieval operation fails
    func get(forService service: ServiceIdentifier) throws -> String? {
        try queue.sync {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service.serviceKey,
                kSecAttrAccount as String: service.rawValue,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]

            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)

            switch status {
            case errSecSuccess:
                guard let data = result as? Data,
                      let key = String(data: data, encoding: .utf8) else {
                    throw KeychainError.invalidData
                }
                return key

            case errSecItemNotFound:
                return nil

            default:
                throw KeychainError.unexpectedStatus(status)
            }
        }
    }

    /// Updates an existing key in the Keychain.
    ///
    /// - Parameters:
    ///   - key: The new key value
    ///   - service: The service identifier for the key to update
    /// - Throws: `KeychainError` if the update operation fails
    func update(key: String, forService service: ServiceIdentifier) throws {
        guard let data = key.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        try queue.sync(flags: .barrier) {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service.serviceKey,
                kSecAttrAccount as String: service.rawValue
            ]

            let attributesToUpdate: [String: Any] = [
                kSecValueData as String: data
            ]

            let status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)

            switch status {
            case errSecSuccess:
                break

            case errSecItemNotFound:
                // Item doesn't exist, create it instead
                try save(key: key, forService: service)

            default:
                throw KeychainError.unexpectedStatus(status)
            }
        }
    }

    /// Deletes a key from the Keychain.
    ///
    /// - Parameter service: The service identifier for the key to delete
    /// - Throws: `KeychainError` if the delete operation fails
    func delete(forService service: ServiceIdentifier) throws {
        try queue.sync(flags: .barrier) {
            try deleteInternal(forService: service)
        }
    }

    /// Checks if a key exists in the Keychain.
    ///
    /// - Parameter service: The service identifier to check
    /// - Returns: True if the key exists, false otherwise
    func exists(forService service: ServiceIdentifier) -> Bool {
        queue.sync {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service.serviceKey,
                kSecAttrAccount as String: service.rawValue,
                kSecReturnData as String: false
            ]

            let status = SecItemCopyMatching(query as CFDictionary, nil)
            return status == errSecSuccess
        }
    }

    /// Removes all items managed by this keychain manager.
    ///
    /// - Warning: This will delete all stored keys. Use with caution.
    /// - Throws: `KeychainError` if the operation fails
    func deleteAll() throws {
        try queue.sync(flags: .barrier) {
            // Delete all items with our service prefix
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.tenniscoach"
            ]

            let status = SecItemDelete(query as CFDictionary)

            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw KeychainError.unexpectedStatus(status)
            }
        }
    }

    // MARK: - Private Methods

    /// Internal delete method that doesn't acquire the lock.
    /// Must be called from within a queue.sync block.
    private func deleteInternal(forService service: ServiceIdentifier) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service.serviceKey,
            kSecAttrAccount as String: service.rawValue
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}

// MARK: - Convenience Methods for Gemini API

extension SecureKeyManager {

    /// Saves the Gemini API key to the Keychain.
    ///
    /// - Parameter apiKey: The Gemini API key to store
    /// - Throws: `KeychainError` if the save operation fails
    func saveGeminiAPIKey(_ apiKey: String) throws {
        try save(key: apiKey, forService: .geminiAPI)
    }

    /// Retrieves the Gemini API key from the Keychain.
    ///
    /// - Returns: The stored Gemini API key, or nil if not found
    /// - Throws: `KeychainError` if the retrieval operation fails
    func getGeminiAPIKey() throws -> String? {
        try get(forService: .geminiAPI)
    }

    /// Updates the Gemini API key in the Keychain.
    ///
    /// - Parameter apiKey: The new Gemini API key
    /// - Throws: `KeychainError` if the update operation fails
    func updateGeminiAPIKey(_ apiKey: String) throws {
        try update(key: apiKey, forService: .geminiAPI)
    }

    /// Deletes the Gemini API key from the Keychain.
    ///
    /// - Throws: `KeychainError` if the delete operation fails
    func deleteGeminiAPIKey() throws {
        try delete(forService: .geminiAPI)
    }

    /// Checks if a Gemini API key exists in the Keychain.
    ///
    /// - Returns: True if the key exists, false otherwise
    func hasGeminiAPIKey() -> Bool {
        exists(forService: .geminiAPI)
    }
}
