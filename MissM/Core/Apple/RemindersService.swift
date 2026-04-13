import EventKit
import Foundation

// MARK: - Reminders Service
// Phase 1: Read + write access to Apple Reminders via EventKit

@Observable
class RemindersService {
    static let shared = RemindersService()

    private let store = EKEventStore()
    var authorizationStatus: EKAuthorizationStatus = .notDetermined

    private init() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
    }

    // MARK: - Request Access
    func requestAccess() async -> Bool {
        do {
            let granted = try await store.requestFullAccessToReminders()
            authorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
            return granted
        } catch {
            authorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
            return false
        }
    }

    // MARK: - Get Incomplete Reminders
    func getIncompleteReminders() async -> [EKReminder] {
        guard authorizationStatus == .fullAccess else { return [] }

        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: nil
        )

        return await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }

    // MARK: - Get Reminders Due Today
    func getRemindersDueToday() async -> [EKReminder] {
        guard authorizationStatus == .fullAccess else { return [] }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }

        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: startOfDay,
            ending: endOfDay,
            calendars: nil
        )

        return await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }

    // MARK: - Add Reminder
    func addReminder(title: String, dueDate: Date? = nil, notes: String? = nil, priority: Int = 0) throws {
        guard authorizationStatus == .fullAccess else {
            throw RemindersError.noAccess
        }

        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.notes = notes
        reminder.priority = priority
        reminder.calendar = store.defaultCalendarForNewReminders()

        if let dueDate = dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: dueDate
            )
        }

        try store.save(reminder, commit: true)
    }

    // MARK: - Complete Reminder
    func completeReminder(_ reminder: EKReminder) throws {
        reminder.isCompleted = true
        reminder.completionDate = Date()
        try store.save(reminder, commit: true)
    }

    // MARK: - Format for Briefing
    func todaySummary() async -> String {
        let reminders = await getIncompleteReminders()
        if reminders.isEmpty { return "No pending reminders" }

        let upcoming = reminders.prefix(5)
        return upcoming.map { reminder in
            let priority = reminder.priority > 0 ? " [!]" : ""
            return "- \(reminder.title ?? "Untitled")\(priority)"
        }.joined(separator: "\n")
    }

    // MARK: - Incomplete Count (for Menu Bar Mini)
    func incompleteCount() async -> Int {
        let reminders = await getIncompleteReminders()
        return reminders.count
    }

    enum RemindersError: Error, LocalizedError {
        case noAccess

        var errorDescription: String? {
            "Reminders access not granted. Please enable in System Settings \u{2192} Privacy \u{2192} Reminders."
        }
    }
}
