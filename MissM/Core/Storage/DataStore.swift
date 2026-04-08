import Foundation

// MARK: - DataStore
// Actor-based JSON persistence for Miss M's local data
// Stores assignments, flashcards, study plans, essays, marketing analyses

actor DataStore {
    static let shared = DataStore()

    private let fileManager = FileManager.default

    private var storeDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("com.missm.assistant", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Generic Save/Load
    private func fileURL(for key: String) -> URL {
        storeDirectory.appendingPathComponent("\(key).json")
    }

    func save<T: Encodable>(_ value: T, for key: String) throws {
        let data = try JSONEncoder().encode(value)
        try data.write(to: fileURL(for: key), options: .atomic)
    }

    func load<T: Decodable>(_ type: T.Type, for key: String) throws -> T? {
        let url = fileURL(for: key)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(type, from: data)
    }

    func delete(for key: String) throws {
        let url = fileURL(for: key)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    // MARK: - Assignments
    func saveAssignments(_ assignments: [Assignment]) throws {
        try save(assignments, for: "assignments")
    }

    func loadAssignments() throws -> [Assignment] {
        try load([Assignment].self, for: "assignments") ?? []
    }

    // MARK: - Flashcard Decks
    func saveDecks(_ decks: [FlashcardDeck]) throws {
        try save(decks, for: "flashcard-decks")
    }

    func loadDecks() throws -> [FlashcardDeck] {
        try load([FlashcardDeck].self, for: "flashcard-decks") ?? []
    }

    // MARK: - Essays
    func saveEssays(_ essays: [Essay]) throws {
        try save(essays, for: "essays")
    }

    func loadEssays() throws -> [Essay] {
        try load([Essay].self, for: "essays") ?? []
    }

    // MARK: - Marketing Analyses
    func saveMarketingAnalyses(_ analyses: [MarketingAnalysis]) throws {
        try save(analyses, for: "marketing-analyses")
    }

    func loadMarketingAnalyses() throws -> [MarketingAnalysis] {
        try load([MarketingAnalysis].self, for: "marketing-analyses") ?? []
    }

    // MARK: - Study Plans
    func saveStudyPlans(_ plans: [StudyPlan]) throws {
        try save(plans, for: "study-plans")
    }

    func loadStudyPlans() throws -> [StudyPlan] {
        try load([StudyPlan].self, for: "study-plans") ?? []
    }
}

// MARK: - Data Models

struct Assignment: Codable, Identifiable {
    let id: UUID
    var title: String
    var course: String
    var dueDate: Date
    var status: AssignmentStatus
    var priority: AssignmentPriority
    var notes: String?
    var progress: Double // 0.0 to 1.0

    init(id: UUID = UUID(), title: String, course: String, dueDate: Date, status: AssignmentStatus = .todo, priority: AssignmentPriority = .medium, notes: String? = nil, progress: Double = 0.0) {
        self.id = id
        self.title = title
        self.course = course
        self.dueDate = dueDate
        self.status = status
        self.priority = priority
        self.notes = notes
        self.progress = progress
    }

    enum AssignmentStatus: String, Codable, CaseIterable {
        case todo = "To Do"
        case inProgress = "In Progress"
        case done = "Done"
    }

    enum AssignmentPriority: String, Codable, CaseIterable {
        case high = "High"
        case medium = "Medium"
        case low = "Low"

        var color: String {
            switch self {
            case .high: return "#E91E8C"
            case .medium: return "#F06292"
            case .low: return "#9A6B80"
            }
        }
    }

    var daysUntilDue: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
    }

    var isOverdue: Bool { dueDate < Date() && status != .done }

    var progressValue: Double {
        if status == .done { return 1.0 }
        return progress
    }

    var progressLabel: String {
        if status == .done { return "Complete" }
        let pct = Int(progress * 100)
        if pct == 0 { return "Not started" }
        return "\(pct)%"
    }
}

struct FlashcardDeck: Codable, Identifiable {
    let id: UUID
    var title: String
    var course: String
    var cards: [Flashcard]
    var createdAt: Date

    init(id: UUID = UUID(), title: String, course: String, cards: [Flashcard] = [], createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.course = course
        self.cards = cards
        self.createdAt = createdAt
    }

    var masteredCount: Int { cards.filter { $0.isMastered }.count }
}

struct Flashcard: Codable, Identifiable {
    let id: UUID
    var front: String
    var back: String
    var isMastered: Bool

    init(id: UUID = UUID(), front: String, back: String, isMastered: Bool = false) {
        self.id = id
        self.front = front
        self.back = back
        self.isMastered = isMastered
    }
}

struct Essay: Codable, Identifiable {
    let id: UUID
    var title: String
    var course: String
    var outline: [OutlineItem]
    var content: String
    var citations: [Citation]
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), title: String, course: String = "", outline: [OutlineItem] = [], content: String = "", citations: [Citation] = [], createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.course = course
        self.outline = outline
        self.content = content
        self.citations = citations
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct OutlineItem: Codable, Identifiable {
    let id: UUID
    var text: String
    var level: Int

    init(id: UUID = UUID(), text: String, level: Int = 0) {
        self.id = id
        self.text = text
        self.level = level
    }
}

struct Citation: Codable, Identifiable {
    let id: UUID
    var author: String
    var title: String
    var year: String
    var source: String

    init(id: UUID = UUID(), author: String, title: String, year: String, source: String = "") {
        self.id = id
        self.author = author
        self.title = title
        self.year = year
        self.source = source
    }

    var formatted: String {
        "\(author) (\(year)). \(title).\(source.isEmpty ? "" : " \(source).")"
    }
}

struct MarketingAnalysis: Codable, Identifiable {
    let id: UUID
    var title: String
    var type: AnalysisType
    var content: String
    var createdAt: Date

    init(id: UUID = UUID(), title: String, type: AnalysisType, content: String = "", createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.type = type
        self.content = content
        self.createdAt = createdAt
    }

    enum AnalysisType: String, Codable, CaseIterable {
        case swot = "SWOT"
        case stp = "STP"
        case persona = "Persona"
        case campaign = "Campaign"
        case pestle = "PESTLE"
    }
}

struct StudyPlan: Codable, Identifiable {
    let id: UUID
    var title: String
    var sessions: [StudySession]
    var createdAt: Date

    init(id: UUID = UUID(), title: String, sessions: [StudySession] = [], createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.sessions = sessions
        self.createdAt = createdAt
    }
}

struct StudySession: Codable, Identifiable {
    let id: UUID
    var subject: String
    var date: Date
    var durationMinutes: Int
    var isCompleted: Bool

    init(id: UUID = UUID(), subject: String, date: Date, durationMinutes: Int = 25, isCompleted: Bool = false) {
        self.id = id
        self.subject = subject
        self.date = date
        self.durationMinutes = durationMinutes
        self.isCompleted = isCompleted
    }
}
