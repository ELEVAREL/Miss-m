import Foundation

// MARK: - DataStore
// Actor-based JSON persistence for Phase 2+ data (assignments, meals, budget, grocery, flashcards)

actor DataStore {
    static let shared = DataStore()

    private let fileManager = FileManager.default
    private var baseURL: URL {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = support.appendingPathComponent("com.missm.assistant", isDirectory: true)
        try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir
    }

    // MARK: - Generic Save/Load
    func save<T: Encodable>(_ value: T, to filename: String) throws {
        let url = baseURL.appendingPathComponent(filename)
        let data = try JSONEncoder().encode(value)
        try data.write(to: url, options: .atomic)
    }

    func load<T: Decodable>(_ type: T.Type, from filename: String) throws -> T {
        let url = baseURL.appendingPathComponent(filename)
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(type, from: data)
    }

    func loadOrDefault<T: Decodable>(_ type: T.Type, from filename: String, default defaultValue: T) -> T {
        (try? load(type, from: filename)) ?? defaultValue
    }

    func delete(_ filename: String) throws {
        let url = baseURL.appendingPathComponent(filename)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
}
