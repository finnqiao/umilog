import Foundation
import LocalAuthentication
import os

private let logger = Logger(subsystem: "app.umilog", category: "AppLock")

/// Service for managing app lock with Face ID/Touch ID
public actor AppLockService {
    public static let shared = AppLockService()

    private let keychainService = "app.umilog"
    private let lockEnabledKey = "app-lock-enabled"

    // MARK: - Lock State Management

    /// Whether app lock is enabled (stored in Keychain)
    public func isLockEnabled() -> Bool {
        return getLockPreference()
    }

    /// Enable or disable app lock
    /// - Parameter enabled: Whether to enable lock
    /// - Returns: True if the preference was saved successfully
    @discardableResult
    public func setLockEnabled(_ enabled: Bool) async -> Bool {
        if enabled {
            // Verify biometrics are available before enabling
            guard canUseBiometrics() else {
                logger.warning("Cannot enable lock: biometrics not available")
                return false
            }
        }

        saveLockPreference(enabled)
        logger.info("App lock \(enabled ? "enabled" : "disabled")")
        return true
    }

    // MARK: - Authentication

    /// Check if biometric authentication is available
    public func canUseBiometrics() -> Bool {
        let context = LAContext()
        var error: NSError?
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)

        if let error = error {
            logger.debug("Biometrics not available: \(error.localizedDescription)")
        }

        return canEvaluate
    }

    /// Returns the biometry type available on device
    public func biometryType() -> LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }

    /// Authenticate with biometrics
    /// - Parameter reason: The reason shown to the user
    /// - Returns: True if authentication succeeded, false otherwise
    public func authenticate(reason: String = "Unlock UmiLog") async -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = "Use Passcode"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // Fall back to device passcode if biometrics unavailable
            guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
                logger.error("No authentication method available: \(error?.localizedDescription ?? "unknown")")
                return false
            }

            // Use device passcode
            do {
                let result = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
                logger.info("Passcode authentication \(result ? "succeeded" : "failed")")
                return result
            } catch {
                logger.error("Passcode authentication error: \(error.localizedDescription)")
                return false
            }
        }

        // Use biometrics
        do {
            let result = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
            logger.info("Biometric authentication \(result ? "succeeded" : "failed")")
            return result
        } catch let error as LAError {
            switch error.code {
            case .userFallback:
                // User tapped "Use Passcode" - try device passcode
                return await authenticateWithPasscode(reason: reason)
            case .userCancel:
                logger.info("User cancelled authentication")
                return false
            default:
                logger.error("Biometric authentication error: \(error.localizedDescription)")
                return false
            }
        } catch {
            logger.error("Biometric authentication error: \(error.localizedDescription)")
            return false
        }
    }

    private func authenticateWithPasscode(reason: String) async -> Bool {
        let context = LAContext()
        do {
            let result = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            logger.info("Passcode fallback authentication \(result ? "succeeded" : "failed")")
            return result
        } catch {
            logger.error("Passcode fallback error: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Keychain Storage

    private func getLockPreference() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: lockEnabledKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return false // Default to unlocked
        }

        return value == "true"
    }

    private func saveLockPreference(_ enabled: Bool) {
        let value = enabled ? "true" : "false"
        guard let data = value.data(using: .utf8) else { return }

        // Delete existing
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: lockEnabledKey
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: lockEnabledKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            logger.error("Failed to save lock preference: \(status)")
        }
    }

    /// Clears the lock preference (for debug/reset scenarios)
    public func resetLockPreference() {
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: lockEnabledKey
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        logger.info("Lock preference reset")
    }
}
