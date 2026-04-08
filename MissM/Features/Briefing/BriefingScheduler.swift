import Foundation
import EventKit

// MARK: - Briefing Scheduler
// Sends Miss M a morning iMessage every day at 7:30am

@Observable
class BriefingScheduler {
    var isEnabled = true
    var morningTime = DateComponents(hour: 7, minute: 30)
    var eveningTime = DateComponents(hour: 21, minute: 0)

    private let claudeService: ClaudeService
    private let phoneNumber: String
    private var timer: Timer?

    init(claudeService: ClaudeService, phoneNumber: String) {
        self.claudeService = claudeService
        self.phoneNumber = phoneNumber
    }

    func start() {
        // Check every minute if it's time to send a briefing
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

        // Morning briefing: weekdays at 7:30am
        if now.hour == morningTime.hour && now.minute == morningTime.minute
            && (2...6).contains(now.weekday ?? 0) {
            await sendMorningBriefing()
        }

        // Evening wind-down: daily at 9pm
        if now.hour == eveningTime.hour && now.minute == eveningTime.minute {
            await sendEveningWindDown()
        }
    }

    private func sendMorningBriefing() async {
        let context = await buildContext()
        let prompt = """
        Generate a warm, concise morning briefing for Miss M. Include:
        - A friendly good morning greeting using her name
        - Today's date
        - Her schedule today (if any): \(context.schedule)
        - Upcoming deadlines: \(context.deadlines)
        - Weather: \(context.weather)
        - 2-3 encouraging words
        - Remind her she can reply to ask anything
        Keep it under 150 words. Use emojis naturally.
        """
        do {
            let message = try await claudeService.ask(prompt)
            try await MessagesService.send(message, to: phoneNumber)
        } catch {
            print("Morning briefing error: \(error)")
        }
    }

    private func sendEveningWindDown() async {
        let prompt = """
        Generate a brief evening wind-down message for Miss M.
        - Recap the day positively (keep it general)
        - Give a gentle reminder to rest
        - Brief preview that tomorrow is a new day
        Keep it under 80 words. Warm and encouraging.
        """
        do {
            let message = try await claudeService.ask(prompt)
            try await MessagesService.send(message, to: phoneNumber)
        } catch {
            print("Evening wind-down error: \(error)")
        }
    }

    private func buildContext() async -> BriefingContext {
        let schedule = await CalendarService.shared.todaySummary()
        let deadlines = await RemindersService.shared.todaySummary()
        return BriefingContext(
            schedule: schedule,
            deadlines: deadlines,
            weather: "Check weather outside"
        )
    }

    struct BriefingContext {
        let schedule: String
        let deadlines: String
        let weather: String
    }
}
