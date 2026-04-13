import Foundation
import EventKit

// MARK: - Briefing Scheduler
// Sends Miss M automated iMessages: morning briefing, evening wind-down,
// Sunday weekly plan, and deadline warnings

@Observable
class BriefingScheduler {
    var isEnabled = true
    var morningEnabled = true
    var eveningEnabled = true
    var sundayPlanEnabled = true
    var deadlineWarningsEnabled = true
    var morningTime = DateComponents(hour: 7, minute: 30)
    var eveningTime = DateComponents(hour: 21, minute: 0)
    var sundayPlanTime = DateComponents(hour: 19, minute: 0)

    private let claudeService: ClaudeService
    private let phoneNumber: String
    private var timer: Timer?
    private var lastMorningSent: Date?
    private var lastEveningSent: Date?
    private var lastSundaySent: Date?
    private var lastDeadlineCheckDate: Date?

    init(claudeService: ClaudeService, phoneNumber: String) {
        self.claudeService = claudeService
        self.phoneNumber = phoneNumber
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { await self?.checkAndSend() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    @MainActor
    private func checkAndSend() async {
        guard isEnabled else { return }
        let now = Calendar.current.dateComponents([.hour, .minute, .weekday], from: Date())
        let today = Calendar.current.startOfDay(for: Date())

        // Morning briefing: weekdays at 7:30am
        if morningEnabled,
           now.hour == morningTime.hour,
           now.minute == morningTime.minute,
           (2...6).contains(now.weekday ?? 0),
           lastMorningSent != today {
            lastMorningSent = today
            await sendMorningBriefing()
        }

        // Evening wind-down: daily at 9pm
        if eveningEnabled,
           now.hour == eveningTime.hour,
           now.minute == eveningTime.minute,
           lastEveningSent != today {
            lastEveningSent = today
            await sendEveningWindDown()
        }

        // Sunday weekly plan: Sundays at 7pm
        if sundayPlanEnabled,
           now.weekday == 1,
           now.hour == sundayPlanTime.hour,
           now.minute == sundayPlanTime.minute,
           lastSundaySent != today {
            lastSundaySent = today
            await sendSundayWeeklyPlan()
        }

        // Deadline warnings: check once each morning at briefing time
        if deadlineWarningsEnabled,
           now.hour == morningTime.hour,
           now.minute == morningTime.minute,
           lastDeadlineCheckDate != today {
            lastDeadlineCheckDate = today
            await checkDeadlineWarnings()
        }
    }

    // MARK: - Morning Briefing (real data)

    private func sendMorningBriefing() async {
        let context = await buildContext()

        let prompt = """
        Generate a warm morning briefing for Miss M using this EXACT format:

        Good morning Miss M! \u{2600}\u{FE0F}

        [Day], [Date]

        \u{1F4DA} [Most urgent deadline from reminders] \u{2014} [X] days left
        \u{1F4C5} [Event times from calendar]
        \u{2705} [X] tasks today

        [1 line encouragement]
        Reply to ask me anything \u{1F4AC}

        Real data:
        - Today's calendar: \(context.schedule)
        - Incomplete reminders: \(context.deadlines)
        Keep it under 150 words. Use the real data above.
        """
        do {
            let message = try await claudeService.ask(prompt)
            try await MessagesService.send(message, to: phoneNumber)
        } catch {
            // Silently fail — don't crash the app over a failed briefing
        }
    }

    // MARK: - Evening Wind-Down

    private func sendEveningWindDown() async {
        let context = await buildContext()

        let prompt = """
        Generate a brief evening wind-down message for Miss M.
        - Recap the day positively based on her schedule: \(context.schedule)
        - Mention tasks completed if any
        - Gentle reminder to rest
        - Brief positive preview for tomorrow
        Keep it under 80 words. Warm and encouraging. Use 1-2 emojis.
        """
        do {
            let message = try await claudeService.ask(prompt)
            try await MessagesService.send(message, to: phoneNumber)
        } catch {}
    }

    // MARK: - Sunday Weekly Plan

    private func sendSundayWeeklyPlan() async {
        let cal = Calendar.current
        guard let weekStart = cal.date(byAdding: .day, value: 1, to: Date()),
              let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart) else { return }

        let events = CalendarService.shared.getEvents(from: weekStart, to: weekEnd)
        let reminders = await RemindersService.shared.getIncompleteReminders()

        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE h:mm a"

        let eventsList = events.prefix(10).map { "\(formatter.string(from: $0.startDate)) - \($0.title ?? "Untitled")" }.joined(separator: "\n")
        let remindersList = reminders.prefix(8).map { "- \($0.title ?? "Untitled")" }.joined(separator: "\n")

        let prompt = """
        Generate a Sunday evening weekly plan message for Miss M. Format:

        Happy Sunday Miss M! \u{1F31F} Here's your week ahead:

        [List key events by day]
        [List top tasks/deadlines]
        [1 motivational closing line]

        Real data:
        Events this week:
        \(eventsList.isEmpty ? "No events scheduled yet" : eventsList)

        Pending tasks:
        \(remindersList.isEmpty ? "No pending reminders" : remindersList)

        Keep it under 200 words. Organised by day.
        """
        do {
            let message = try await claudeService.ask(prompt)
            try await MessagesService.send(message, to: phoneNumber)
        } catch {}
    }

    // MARK: - Deadline Warnings (3d / 1d / morning of)

    private func checkDeadlineWarnings() async {
        let reminders = await RemindersService.shared.getIncompleteReminders()
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        for reminder in reminders {
            guard let dueComponents = reminder.dueDateComponents,
                  let dueDate = cal.date(from: dueComponents) else { continue }

            let daysUntil = cal.dateComponents([.day], from: today, to: cal.startOfDay(for: dueDate)).day ?? 999

            var warningMessage: String?

            switch daysUntil {
            case 3:
                warningMessage = "\u{26A0}\u{FE0F} Miss M, heads up! \"\(reminder.title ?? "A task")\" is due in 3 days. Want me to help you plan your time? \u{1F4AC}"
            case 1:
                warningMessage = "\u{1F6A8} Miss M! \"\(reminder.title ?? "A task")\" is due TOMORROW! Let me know if you need help finishing up. You've got this! \u{1F4AA}"
            case 0:
                warningMessage = "\u{2757} Good morning Miss M \u{2014} \"\(reminder.title ?? "A task")\" is due TODAY. Focus mode activated! \u{1F3AF} Reply if you need anything."
            default:
                break
            }

            if let message = warningMessage {
                try? await MessagesService.send(message, to: phoneNumber)
            }
        }
    }

    // MARK: - Build Real Context

    private func buildContext() async -> BriefingContext {
        let schedule = await CalendarService.shared.todaySummary()
        let deadlines = await RemindersService.shared.todaySummary()
        return BriefingContext(schedule: schedule, deadlines: deadlines)
    }

    struct BriefingContext {
        let schedule: String
        let deadlines: String
    }
}
