import Security
import Foundation

// MARK: - Keychain Manager
// Stores API key to Application Support file so it persists across rebuilds
// (Keychain rejects ad-hoc signed apps after each rebuild)

enum KeychainManager {
    private static var configURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = support.appendingPathComponent("com.missm.assistant", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent(".missm-config")
    }

    // MARK: - API Key
    static func saveAPIKey(_ key: String) throws {
        var config = loadConfig()
        config["api_key"] = key
        saveConfig(config)
    }

    static func loadAPIKey() -> String? {
        loadConfig()["api_key"]
    }

    static func deleteAPIKey() throws {
        var config = loadConfig()
        config.removeValue(forKey: "api_key")
        saveConfig(config)
    }

    // MARK: - Phone Number
    static func savePhoneNumber(_ number: String) throws {
        var config = loadConfig()
        config["phone"] = number
        saveConfig(config)
    }

    static func loadPhoneNumber() -> String? {
        loadConfig()["phone"]
    }

    // MARK: - Generic Settings
    static func saveSetting(_ key: String, value: String) {
        var config = loadConfig()
        config[key] = value
        saveConfig(config)
    }

    static func loadSetting(_ key: String) -> String? {
        loadConfig()[key]
    }

    // MARK: - Private
    private static func loadConfig() -> [String: String] {
        guard let data = try? Data(contentsOf: configURL),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return dict
    }

    private static func saveConfig(_ config: [String: String]) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        try? data.write(to: configURL, options: .atomic)
    }

    enum KeychainError: Error, LocalizedError {
        case saveFailed(OSStatus)
        case deleteFailed(OSStatus)

        var errorDescription: String? {
            switch self {
            case .saveFailed(let status): return "Save failed: \(status)"
            case .deleteFailed(let status): return "Delete failed: \(status)"
            }
        }
    }
}
