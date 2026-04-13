import EventKit
import Foundation

// MARK: - Calendar Service
// Phase 1: Read access to Apple Calendar via EventKit

@Observable
class CalendarService {
    static let shared = CalendarService()

    private let store = EKEventStore()
    var authorizationStatus: EKAuthorizationStatus = .notDetermined

    private init() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    // MARK: - Request Access
    func requestAccess() async -> Bool {
        // Try the modern API first (macOS 14.0+), fall back to legacy if it fails
        do {
            let granted = try await store.requestFullAccessToEvents()
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            return granted
        } catch {
            // Fallback to legacy requestAccess(to:) for compatibility
            return await withCheckedContinuation { continuation in
                store.requestAccess(to: .event) { granted, _ in
                    self.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    // MARK: - Get Today's Events
    func getEventsToday() async -> [EKEvent] {
        // Request access if not yet authorized
        if authorizationStatus != .fullAccess && authorizationStatus != .authorized {
            let granted = await requestAccess()
            if !granted { return [] }
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }

        let predicate = store.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        return store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
    }

    // MARK: - Get Events for Date Range
    func getEvents(from start: Date, to end: Date) -> [EKEvent] {
        guard authorizationStatus == .fullAccess else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
    }

    // MARK: - Add Event
    func addEvent(title: String, startDate: Date, endDate: Date, notes: String? = nil) throws {
        guard authorizationStatus == .fullAccess else {
            throw CalendarError.noAccess
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
        if events.isEmpty { return "No events scheduled today" }

        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"

        return events.map { event in
            let time = formatter.string(from: event.startDate)
            return "\(time) \u{2014} \(event.title ?? "Untitled")"
        }.joined(separator: "\n")
    }

    // MARK: - Next Event Summary (for Menu Bar Mini)
    func nextEventSummary() async -> String {
        let events = await getEventsToday()
        let now = Date()
        if let next = events.first(where: { $0.startDate > now }) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "\(formatter.string(from: next.startDate)) — \(next.title ?? "Event")"
        }
        return "No more events today"
    }

    enum CalendarError: Error, LocalizedError {
        case noAccess

        var errorDescription: String? {
            "Calendar access not granted. Please enable in System Settings \u{2192} Privacy \u{2192} Calendars."
        }
    }
}
