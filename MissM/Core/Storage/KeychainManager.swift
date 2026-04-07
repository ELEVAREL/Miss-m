import Security
import Foundation

// MARK: - Keychain Manager
// Securely stores Miss M's API key — never UserDefaults

enum KeychainManager {
    private static let service = "com.missm.assistant"

    // MARK: - API Key
    static func saveAPIKey(_ key: String) throws {
        try save(key, for: "anthropic-api-key")
    }

    static func loadAPIKey() -> String? {
        load(for: "anthropic-api-key")
    }

    static func deleteAPIKey() throws {
        try delete(for: "anthropic-api-key")
    }

    // MARK: - Phone Number (for iMessage)
    static func savePhoneNumber(_ number: String) throws {
        try save(number, for: "missm-phone-number")
    }

    static func loadPhoneNumber() -> String? {
        load(for: "missm-phone-number")
    }

    // MARK: - Private Helpers
    private static func save(_ value: String, for key: String) throws {
        guard let data = value.data(using: .utf8) else { return }

        // Delete existing first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    private static func load(for key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else { return nil }
        return string
    }

    private static func delete(for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    enum KeychainError: Error, LocalizedError {
        case saveFailed(OSStatus)
        case deleteFailed(OSStatus)

        var errorDescription: String? {
            switch self {
            case .saveFailed(let status): return "Keychain save failed: \(status)"
            case .deleteFailed(let status): return "Keychain delete failed: \(status)"
            }
        }
    }
}
