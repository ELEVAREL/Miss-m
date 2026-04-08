import AppIntents

// MARK: - Siri Shortcuts Provider (Phase 7)
// App Intents — 8 voice commands for Siri integration

// MARK: - Ask Miss M Intent
struct AskMissMIntent: AppIntent {
    static var title: LocalizedStringResource = "Ask Miss M"
    static var description = IntentDescription("Ask Miss M AI assistant a question")

    @Parameter(title: "Question")
    var question: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let apiKey = KeychainManager.loadAPIKey() else {
            return .result(dialog: "Please set up your API key in Miss M first.")
        }

        let service = ClaudeService(apiKey: apiKey)
        let response = try await service.ask(question)
        return .result(dialog: IntentDialog(stringLiteral: response))
    }
}

// MARK: - Start Pomodoro Intent
struct StartPomodoroIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Pomodoro Timer"
    static var description = IntentDescription("Start a 25-minute focus session")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        return .result(dialog: "Pomodoro timer started — 25 minutes of focus time! Open Miss M to see the timer.")
    }
}

// MARK: - Get Today's Schedule Intent
struct GetScheduleIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Today's Schedule"
    static var description = IntentDescription("Read today's calendar events and reminders")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let events = await CalendarService.shared.getEventsToday()
        let reminders = await RemindersService.shared.getRemindersDueToday()

        var lines: [String] = []
        if events.isEmpty {
            lines.append("No events today.")
        } else {
            lines.append("Today's events:")
            for event in events {
                lines.append("• \(event.title) at \(event.timeString)")
            }
        }

        if !reminders.isEmpty {
            lines.append("\nReminders due today:")
            for reminder in reminders {
                lines.append("• \(reminder.title)")
            }
        }

        return .result(dialog: IntentDialog(stringLiteral: lines.joined(separator: "\n")))
    }
}

// MARK: - Add Reminder Intent
struct AddReminderIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Reminder"
    static var description = IntentDescription("Add a new reminder via Miss M")

    @Parameter(title: "Reminder")
    var reminderText: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await RemindersService.shared.addReminder(title: reminderText)
        return .result(dialog: "Done! Added reminder: \(reminderText)")
    }
}

// MARK: - Send Message to NyRiian Intent
struct MessageNyRiianIntent: AppIntent {
    static var title: LocalizedStringResource = "Message NyRiian"
    static var description = IntentDescription("Send an iMessage to NyRiian")

    @Parameter(title: "Message")
    var message: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let phone = KeychainManager.loadPhoneNumber() else {
            return .result(dialog: "Phone number not configured in Miss M.")
        }
        try await MessagesService.send(message, to: phone)
        return .result(dialog: "Message sent to NyRiian!")
    }
}

// MARK: - Check Wellness Intent
struct CheckWellnessIntent: AppIntent {
    static var title: LocalizedStringResource = "Check My Wellness"
    static var description = IntentDescription("Get today's health and wellness summary")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let summary = await HealthService.shared.wellnessSummary()
        return .result(dialog: IntentDialog(stringLiteral: "Here's your wellness today:\n\(summary)"))
    }
}

// MARK: - What's Due Intent
struct WhatsDueIntent: AppIntent {
    static var title: LocalizedStringResource = "What's Due This Week"
    static var description = IntentDescription("Check upcoming assignment deadlines")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let deadlines = await RemindersService.shared.upcomingDeadlines()
        if deadlines.isEmpty {
            return .result(dialog: "No upcoming deadlines this week. You're all clear!")
        }

        var lines = ["Upcoming deadlines:"]
        for deadline in deadlines {
            lines.append("• \(deadline.title)")
        }
        return .result(dialog: IntentDialog(stringLiteral: lines.joined(separator: "\n")))
    }
}

// MARK: - Morning Briefing Intent
struct MorningBriefingIntent: AppIntent {
    static var title: LocalizedStringResource = "Morning Briefing"
    static var description = IntentDescription("Get your Miss M morning briefing")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let apiKey = KeychainManager.loadAPIKey() else {
            return .result(dialog: "Please set up your API key in Miss M first.")
        }

        let events = await CalendarService.shared.getEventsToday()
        let reminders = await RemindersService.shared.getRemindersDueToday()

        let service = ClaudeService(apiKey: apiKey)
        let prompt = """
        Generate a brief morning briefing for Miss M. She has \(events.count) events today and \(reminders.count) tasks due. \
        Keep it under 3 sentences. Be warm and encouraging.
        """

        let response = try await service.ask(prompt)
        return .result(dialog: IntentDialog(stringLiteral: response))
    }
}

// MARK: - App Shortcuts Provider
struct MissMShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: AskMissMIntent(), phrases: [
            "Ask \(.applicationName)",
            "Hey \(.applicationName)"
        ], shortTitle: "Ask Miss M", systemImageName: "sparkles")

        AppShortcut(intent: GetScheduleIntent(), phrases: [
            "What's on today \(.applicationName)",
            "Today's schedule \(.applicationName)"
        ], shortTitle: "Today's Schedule", systemImageName: "calendar")

        AppShortcut(intent: AddReminderIntent(), phrases: [
            "Add reminder \(.applicationName)",
            "Remind me \(.applicationName)"
        ], shortTitle: "Add Reminder", systemImageName: "bell")

        AppShortcut(intent: StartPomodoroIntent(), phrases: [
            "Start studying \(.applicationName)",
            "Focus mode \(.applicationName)"
        ], shortTitle: "Start Pomodoro", systemImageName: "timer")

        AppShortcut(intent: MessageNyRiianIntent(), phrases: [
            "Message NyRiian \(.applicationName)",
            "Text my husband \(.applicationName)"
        ], shortTitle: "Message NyRiian", systemImageName: "message")

        AppShortcut(intent: CheckWellnessIntent(), phrases: [
            "How am I doing \(.applicationName)",
            "Check wellness \(.applicationName)"
        ], shortTitle: "Check Wellness", systemImageName: "heart")

        AppShortcut(intent: WhatsDueIntent(), phrases: [
            "What's due \(.applicationName)",
            "Deadlines \(.applicationName)"
        ], shortTitle: "What's Due", systemImageName: "list.clipboard")

        AppShortcut(intent: MorningBriefingIntent(), phrases: [
            "Morning briefing \(.applicationName)",
            "Good morning \(.applicationName)"
        ], shortTitle: "Morning Briefing", systemImageName: "sun.max")
    }
}
