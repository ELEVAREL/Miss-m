import EventKit
import Foundation

// MARK: - Reminders Service
// Reads and writes reminders using EventKit — Phase 1

@Observable
class RemindersService {
    static let shared = RemindersService()

    private let store = EKEventStore()
    var authorizationStatus: EKAuthorizationStatus = .notDetermined

    init() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
    }

    // MARK: - Request Access
    func requestAccess() async throws -> Bool {
        if #available(macOS 14.0, *) {
            let granted = try await store.requestFullAccessToReminders()
            authorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
            return granted
        } else {
            let granted = try await store.requestAccess(to: .reminder)
            authorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
            return granted
        }
    }

    // MARK: - Get Incomplete Reminders
    func getIncompleteReminders() async -> [MissMReminder] {
        guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess ||
              EKEventStore.authorizationStatus(for: .reminder) == .authorized else {
            return []
        }

        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: nil
        )

        let reminders = await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }

        return reminders.map { reminder in
            MissMReminder(
                title: reminder.title ?? "Untitled",
                dueDate: reminder.dueDateComponents?.date,
                priority: reminder.priority,
                notes: reminder.notes,
                isCompleted: reminder.isCompleted,
                listName: reminder.calendar.title
            )
        }
        .sorted { lhs, rhs in
            // Sort by due date (soonest first), nil dates last
            switch (lhs.dueDate, rhs.dueDate) {
            case let (l?, r?): return l < r
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return lhs.title < rhs.title
            }
        }
    }

    // MARK: - Get Reminders Due Today
    func getRemindersDueToday() async -> [MissMReminder] {
        let all = await getIncompleteReminders()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return all }

        return all.filter { reminder in
            guard let due = reminder.dueDate else { return false }
            return due >= today && due < tomorrow
        }
    }

    // MARK: - Add Reminder
    func addReminder(title: String, dueDate: Date? = nil, notes: String? = nil, priority: Int = 0) async throws {
        guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess ||
              EKEventStore.authorizationStatus(for: .reminder) == .authorized else {
            throw RemindersServiceError.notAuthorized
        }

        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.notes = notes
        reminder.priority = priority
        reminder.calendar = store.defaultCalendarForNewReminders()

        if let dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: dueDate
            )
        }

        try store.save(reminder, commit: true)
    }

    // MARK: - Complete Reminder
    func completeReminder(title: String) async throws {
        guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess ||
              EKEventStore.authorizationStatus(for: .reminder) == .authorized else {
            throw RemindersServiceError.notAuthorized
        }

        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: nil
        )

        let reminders = await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }

        guard let match = reminders.first(where: {
            $0.title?.lowercased() == title.lowercased()
        }) else {
            throw RemindersServiceError.notFound(title)
        }

        match.isCompleted = true
        try store.save(match, commit: true)
    }

    // MARK: - Format for Briefing
    func todaySummary() async -> String {
        let reminders = await getIncompleteReminders()
        if reminders.isEmpty { return "No pending reminders — all clear!" }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        let lines = reminders.prefix(5).map { reminder in
            if let due = reminder.dueDate {
                return "• \(reminder.title) (due \(formatter.string(from: due)))"
            }
            return "• \(reminder.title)"
        }

        let remaining = reminders.count > 5 ? "\n  + \(reminders.count - 5) more" : ""
        return lines.joined(separator: "\n") + remaining
    }

    // MARK: - Upcoming Deadlines (next 7 days)
    func upcomingDeadlines() async -> [MissMReminder] {
        let all = await getIncompleteReminders()
        let calendar = Calendar.current
        guard let weekFromNow = calendar.date(byAdding: .day, value: 7, to: Date()) else { return [] }

        return all.filter { reminder in
            guard let due = reminder.dueDate else { return false }
            return due <= weekFromNow
        }
    }

    enum RemindersServiceError: Error, LocalizedError {
        case notAuthorized
        case notFound(String)

        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "Reminders access not granted. Please allow in System Settings → Privacy → Reminders."
            case .notFound(let title):
                return "Couldn't find reminder: \(title)"
            }
        }
    }
}

// MARK: - Reminder Model
struct MissMReminder: Identifiable {
    let id = UUID()
    let title: String
    let dueDate: Date?
    let priority: Int
    let notes: String?
    let isCompleted: Bool
    let listName: String

    var priorityLabel: String {
        switch priority {
        case 1...4: return "High"
        case 5: return "Medium"
        case 6...9: return "Low"
        default: return "None"
        }
    }

    var isOverdue: Bool {
        guard let due = dueDate else { return false }
        return due < Date() && !isCompleted
    }

    var dueDateString: String {
        guard let due = dueDate else { return "No due date" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: due)
    }
}
