import EventKit
import Foundation

// MARK: - Calendar Service
// Reads and writes events using EventKit — Phase 1

@Observable
class CalendarService {
    static let shared = CalendarService()

    private let store = EKEventStore()
    var authorizationStatus: EKAuthorizationStatus = .notDetermined

    init() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    // MARK: - Request Access
    func requestAccess() async throws -> Bool {
        if #available(macOS 14.0, *) {
            let granted = try await store.requestFullAccessToEvents()
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            return granted
        } else {
            let granted = try await store.requestAccess(to: .event)
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            return granted
        }
    }

    // MARK: - Get Today's Events
    func getEventsToday() async -> [CalendarEvent] {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess ||
              EKEventStore.authorizationStatus(for: .event) == .authorized else {
            return []
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }

        let predicate = store.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let events = store.events(matching: predicate)

        return events.map { event in
            CalendarEvent(
                title: event.title ?? "Untitled",
                startDate: event.startDate,
                endDate: event.endDate,
                location: event.location,
                isAllDay: event.isAllDay,
                calendarName: event.calendar.title
            )
        }
        .sorted { $0.startDate < $1.startDate }
    }

    // MARK: - Get Events for Date Range
    func getEvents(from startDate: Date, to endDate: Date) async -> [CalendarEvent] {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess ||
              EKEventStore.authorizationStatus(for: .event) == .authorized else {
            return []
        }

        let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = store.events(matching: predicate)

        return events.map { event in
            CalendarEvent(
                title: event.title ?? "Untitled",
                startDate: event.startDate,
                endDate: event.endDate,
                location: event.location,
                isAllDay: event.isAllDay,
                calendarName: event.calendar.title
            )
        }
        .sorted { $0.startDate < $1.startDate }
    }

    // MARK: - Add Event
    func addEvent(title: String, startDate: Date, endDate: Date, notes: String? = nil) async throws {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess ||
              EKEventStore.authorizationStatus(for: .event) == .authorized else {
            throw CalendarServiceError.notAuthorized
        }

        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.notes = notes
        event.calendar = store.defaultCalendarForNewEvents

        try store.save(event, span: .thisEvent)
    }

    // MARK: - Format for Briefing
    func todaySummary() async -> String {
        let events = await getEventsToday()
        if events.isEmpty { return "No events today — free day!" }

        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"

        let lines = events.map { event in
            if event.isAllDay {
                return "• \(event.title) (all day)"
            }
            return "• \(formatter.string(from: event.startDate)) — \(event.title)"
        }
        return lines.joined(separator: "\n")
    }

    enum CalendarServiceError: Error, LocalizedError {
        case notAuthorized

        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "Calendar access not granted. Please allow in System Settings → Privacy → Calendars."
            }
        }
    }
}

// MARK: - Calendar Event Model
struct CalendarEvent: Identifiable {
    let id = UUID()
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let isAllDay: Bool
    let calendarName: String

    var timeString: String {
        if isAllDay { return "All Day" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: startDate)
    }
}
