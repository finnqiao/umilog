import Foundation
import CryptoKit
import Security

/// Handles E2E encryption for sensitive dive log fields
/// Key is stored in iCloud Keychain for cross-device availability
public final class FieldEncryptor {
    private let symmetricKey: SymmetricKey

    private static let keychainService = "app.umilog.sync"
    private static let keychainAccount = "encryption-key"
    private static let keySizeInBits = 256

    public init() throws {
        if let existingKey = try Self.loadKeyFromKeychain() {
            self.symmetricKey = existingKey
        } else {
            let newKey = SymmetricKey(size: .bits256)
            try Self.saveKeyToKeychain(newKey)
            self.symmetricKey = newKey
        }
    }

    /// Encrypt a string value
    public func encrypt(_ plaintext: String) throws -> Data {
        let plaintextData = Data(plaintext.utf8)
        let sealedBox = try AES.GCM.seal(plaintextData, using: symmetricKey)
        guard let combined = sealedBox.combined else {
            throw EncryptionError.sealingFailed
        }
        return combined
    }

    /// Decrypt data back to string
    public func decrypt(_ ciphertext: Data) throws -> String {
        let sealedBox = try AES.GCM.SealedBox(combined: ciphertext)
        let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)
        guard let plaintext = String(data: decryptedData, encoding: .utf8) else {
            throw EncryptionError.decodingFailed
        }
        return plaintext
    }

    /// Encrypt a Data value (for binary data)
    public func encryptData(_ plaintext: Data) throws -> Data {
        let sealedBox = try AES.GCM.seal(plaintext, using: symmetricKey)
        guard let combined = sealedBox.combined else {
            throw EncryptionError.sealingFailed
        }
        return combined
    }

    /// Decrypt data back to Data
    public func decryptData(_ ciphertext: Data) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: ciphertext)
        return try AES.GCM.open(sealedBox, using: symmetricKey)
    }

    // MARK: - Keychain Operations

    private static func loadKeyFromKeychain() throws -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecAttrSynchronizable as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let keyData = result as? Data else {
                throw EncryptionError.keychainReadFailed
            }
            return SymmetricKey(data: keyData)
        case errSecItemNotFound:
            return nil
        default:
            throw EncryptionError.keychainReadFailed
        }
    }

    private static func saveKeyToKeychain(_ key: SymmetricKey) throws {
        let keyData = key.withUnsafeBytes { Data($0) }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: keyData,
            kSecAttrSynchronizable as String: true,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status != errSecSuccess && status != errSecDuplicateItem {
            throw EncryptionError.keychainWriteFailed
        }
    }

    public enum EncryptionError: Error, LocalizedError {
        case sealingFailed
        case decodingFailed
        case keychainReadFailed
        case keychainWriteFailed

        public var errorDescription: String? {
            switch self {
            case .sealingFailed: return "Failed to seal encrypted data"
            case .decodingFailed: return "Failed to decode decrypted data"
            case .keychainReadFailed: return "Failed to read encryption key from keychain"
            case .keychainWriteFailed: return "Failed to write encryption key to keychain"
            }
        }
    }
}
