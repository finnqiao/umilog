import Foundation
import Security

/// Provides secure storage for sensitive data using the iOS Keychain.
/// Used primarily for database encryption key management.
public enum KeychainService {
    private static let service = "app.umilog"
    private static let dbKeyAccount = "database-encryption-key"

    // MARK: - Database Encryption Key

    /// Retrieves or generates the database encryption key.
    /// The key is stored securely in the Keychain and bound to this device.
    /// - Returns: A base64-encoded 32-byte encryption key
    /// - Throws: KeychainError if key operations fail
    public static func getDatabaseKey() throws -> String {
        // Try to retrieve existing key
        if let existingKey = try? retrieveKey(account: dbKeyAccount) {
            return existingKey
        }

        // Generate new 32-byte key
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw KeychainError.keyGenerationFailed
        }

        let key = Data(bytes).base64EncodedString()
        try storeKey(key, account: dbKeyAccount)
        return key
    }

    /// Deletes the database encryption key (for testing or reset scenarios).
    public static func deleteDatabaseKey() throws {
        try deleteKey(account: dbKeyAccount)
    }

    // MARK: - Generic Keychain Operations

    private static func storeKey(_ key: String, account: String) throws {
        guard let data = key.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        // First try to delete any existing item
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new item
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            // Key is only accessible when device is unlocked and only on this device
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.storageFailed(status)
        }
    }

    private static func retrieveKey(account: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            throw KeychainError.retrievalFailed(status)
        }

        return key
    }

    private static func deleteKey(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deletionFailed(status)
        }
    }

    // MARK: - Errors

    public enum KeychainError: Error, LocalizedError {
        case keyGenerationFailed
        case encodingFailed
        case storageFailed(OSStatus)
        case retrievalFailed(OSStatus)
        case deletionFailed(OSStatus)

        public var errorDescription: String? {
            switch self {
            case .keyGenerationFailed:
                return "Failed to generate secure random key"
            case .encodingFailed:
                return "Failed to encode key data"
            case .storageFailed(let status):
                return "Failed to store key in Keychain (status: \(status))"
            case .retrievalFailed(let status):
                return "Failed to retrieve key from Keychain (status: \(status))"
            case .deletionFailed(let status):
                return "Failed to delete key from Keychain (status: \(status))"
            }
        }
    }
}
