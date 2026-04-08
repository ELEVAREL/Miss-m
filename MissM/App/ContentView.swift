import SwiftUI

// MARK: - Main Content View
// Root view shown when Miss M clicks the menu bar icon

struct ContentView: View {
    @State private var selectedTab: AppTab = .chat
    @State private var claudeService: ClaudeService? = {
        guard let key = KeychainManager.loadAPIKey() else { return nil }
        return ClaudeService(apiKey: key)
    }()
    @State private var showOnboarding = false

    var body: some View {
        Group {
            if claudeService == nil {
                OnboardingView { apiKey in
                    try KeychainManager.saveAPIKey(apiKey)
                    claudeService = ClaudeService(apiKey: apiKey)
                }
            } else {
                MainAppView(
                    selectedTab: $selectedTab,
                    claudeService: claudeService!
                )
            }
        }
        .frame(width: 420, height: 620)
        .background(Theme.Gradients.background)
    }
}

// MARK: - App Tabs
enum AppTab: String, CaseIterable {
    case chat      = "✦"
    case today     = "☀️"
    case school    = "📚"
    case home      = "🏠"
    case wellness  = "🌙"
    case settings  = "⚙️"

    var label: String {
        switch self {
        case .chat:     return "Chat"
        case .today:    return "Today"
        case .school:   return "School"
        case .home:     return "Home"
        case .wellness: return "Wellness"
        case .settings: return "Settings"
        }
    }
}

// MARK: - Main App View
struct MainAppView: View {
    @Binding var selectedTab: AppTab
    let claudeService: ClaudeService

    var body: some View {
        VStack(spacing: 0) {
            // Header
            AppHeader()

            // Tab content
            Group {
                switch selectedTab {
                case .chat:
                    ChatView(claudeService: claudeService)
                case .today:
                    TodayView()
                case .school:
                    SchoolView(claudeService: claudeService)
                case .home:
                    HomeHubView(claudeService: claudeService)
                case .wellness:
                    WellnessView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Bottom tab bar
            TabBar(selected: $selectedTab)
        }
    }
}

// MARK: - App Header
struct AppHeader: View {
    var body: some View {
        HStack {
            Text("♛")
                .font(.title2)
            VStack(alignment: .leading, spacing: 1) {
                Text("Miss M")
                    .font(.custom("PlayfairDisplay-BoldItalic", size: 16))
                    .foregroundColor(Theme.Colors.rosePrimary)
                Text("Personal AI Assistant")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Theme.Colors.textSoft)
                    .tracking(1.5)
                    .textCase(.uppercase)
            }
            Spacer()
            // API status dot
            HStack(spacing: 5) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                    .shadow(color: Color.green.opacity(0.7), radius: 4)
                Text("Active")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Theme.Colors.textSoft)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.Colors.glassWhite)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Theme.Colors.glassBorder),
            alignment: .bottom
        )
    }
}

// MARK: - Tab Bar
struct TabBar: View {
    @Binding var selected: AppTab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button(action: { selected = tab }) {
                    VStack(spacing: 3) {
                        Text(tab.rawValue)
                            .font(.system(size: 14))
                        Text(tab.label)
                            .font(.system(size: 9, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        selected == tab
                        ? Theme.Gradients.rosePrimary
                        : LinearGradient(colors: [.clear], startPoint: .top, endPoint: .bottom)
                    )
                    .foregroundColor(selected == tab ? .white : Theme.Colors.textSoft)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Theme.Colors.glassWhite)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Theme.Colors.glassBorder),
            alignment: .top
        )
    }
}

// MARK: - Onboarding View
// MARK: - 5-Step Onboarding (matches docs/design/14-onboarding.html)
struct OnboardingView: View {
    @State private var step = 1
    @State private var apiKey = ""
    @State private var phoneNumber = ""
    @State private var calendarGranted = false
    @State private var remindersGranted = false
    let onSave: (String) throws -> Void

    var body: some View {
        VStack(spacing: 0) {
            switch step {
            case 1: welcomeStep
            case 2: apiKeyStep
            case 3: permissionsStep
            case 4: phoneStep
            case 5: doneStep
            default: welcomeStep
            }
        }
        .animation(.easeInOut(duration: 0.3), value: step)
    }

    // MARK: Step 1 — Welcome
    private var welcomeStep: some View {
        VStack(spacing: 0) {
            // Hero gradient header
            VStack(spacing: 8) {
                Text("♛").font(.system(size: 48))
                Text("Welcome,\nMiss M")
                    .font(.custom("PlayfairDisplay-Italic", size: 30))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Text("Your personal AI assistant is ready.\nLet's set everything up in just 2 minutes.")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .background(Theme.Gradients.heroCard)

            // Feature grid
            VStack(spacing: 14) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    OnboardingFeatureItem(icon: "🤖", name: "AI Chat", sub: "Ask anything, anytime")
                    OnboardingFeatureItem(icon: "💬", name: "iMessage AI", sub: "Text your Mac from iPhone")
                    OnboardingFeatureItem(icon: "🌅", name: "Morning Brief", sub: "Daily 7:30am update")
                    OnboardingFeatureItem(icon: "📚", name: "School Tools", sub: "Essays, assignments, study")
                }

                Button("Get Started →") { step = 2 }
                    .buttonStyle(RoseButtonStyle())
                    .frame(maxWidth: .infinity)

                StepDots(current: 1, total: 5)
            }
            .padding(24)

            Spacer()
        }
    }

    // MARK: Step 2 — API Key
    private var apiKeyStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 14) {
                    Text("🔑").font(.system(size: 36))
                    Text("Add Your API Key")
                        .font(.custom("PlayfairDisplay-Italic", size: 22))
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text("Your Claude API key powers Miss M's intelligence.\nIt's stored securely in macOS Keychain — never anywhere else.")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.textSoft)
                        .multilineTextAlignment(.center)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("ANTHROPIC API KEY")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.5)
                            .foregroundColor(Theme.Colors.textSoft)
                        SecureField("sk-ant-api03-...", text: $apiKey)
                            .textFieldStyle(.plain)
                            .padding(11)
                            .background(Color.white.opacity(0.85))
                            .cornerRadius(13)
                            .overlay(RoundedRectangle(cornerRadius: 13).stroke(Theme.Colors.roseLight, lineWidth: 1.5))
                        Text("Get your key at platform.anthropic.com · ~$24 in credits lasts 4-8 months")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.textXSoft)
                    }
                    .padding(.horizontal, 4)

                    Button("Save Key Securely →") {
                        try? KeychainManager.saveAPIKey(apiKey)
                        step = 3
                    }
                    .buttonStyle(RoseButtonStyle())
                    .frame(maxWidth: .infinity)
                    .disabled(apiKey.isEmpty)

                    Button("← Back") { step = 1 }
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.textXSoft)
                        .buttonStyle(.plain)

                    StepDots(current: 2, total: 5)
                }
                .padding(28)
            }
            Spacer()
        }
    }

    // MARK: Step 3 — Permissions
    private var permissionsStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 14) {
                    Text("🔐").font(.system(size: 36))
                    Text("Grant Permissions")
                        .font(.custom("PlayfairDisplay-Italic", size: 22))
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text("Miss M needs access to a few Apple apps to help you best. Tap each to allow.")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.textSoft)
                        .multilineTextAlignment(.center)

                    // Permission items
                    PermissionItem(icon: "📅", iconBg: Theme.Colors.rosePrimary.opacity(0.1), name: "Apple Calendar", sub: "Read & add events", isGranted: calendarGranted) {
                        Task {
                            calendarGranted = (try? await CalendarService.shared.requestAccess()) ?? false
                        }
                    }
                    PermissionItem(icon: "🔔", iconBg: Color.orange.opacity(0.1), name: "Apple Reminders", sub: "Read & create reminders", isGranted: remindersGranted) {
                        Task {
                            remindersGranted = (try? await RemindersService.shared.requestAccess()) ?? false
                        }
                    }
                    PermissionItem(icon: "💬", iconBg: Color.green.opacity(0.1), name: "Messages", sub: "Send iMessages on your behalf", isGranted: false, action: nil)
                    PermissionItem(icon: "🎙", iconBg: Color.purple.opacity(0.1), name: "Microphone", sub: "Voice input (optional)", isGranted: false, action: nil)

                    Button("Continue →") { step = 4 }
                        .buttonStyle(RoseButtonStyle())
                        .frame(maxWidth: .infinity)

                    StepDots(current: 3, total: 5)
                }
                .padding(28)
            }
            Spacer()
        }
    }

    // MARK: Step 4 — Phone Number
    private var phoneStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 14) {
                    Text("📱").font(.system(size: 36))
                    Text("Your iPhone Number")
                        .font(.custom("PlayfairDisplay-Italic", size: 22))
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text("Miss M will send your morning briefing and reply to your iMessages at this number. Stored securely in Keychain.")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.textSoft)
                        .multilineTextAlignment(.center)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("YOUR PHONE NUMBER")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.5)
                            .foregroundColor(Theme.Colors.textSoft)
                        TextField("+1 (555) 000-0000", text: $phoneNumber)
                            .textFieldStyle(.plain)
                            .padding(11)
                            .background(Color.white.opacity(0.85))
                            .cornerRadius(13)
                            .overlay(RoundedRectangle(cornerRadius: 13).stroke(Theme.Colors.roseLight, lineWidth: 1.5))
                        Text("This is the number the AI will text — should be your iPhone number")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.textXSoft)
                    }
                    .padding(.horizontal, 4)

                    Button("Almost Done →") {
                        if !phoneNumber.isEmpty {
                            try? KeychainManager.savePhoneNumber(phoneNumber)
                        }
                        step = 5
                    }
                    .buttonStyle(RoseButtonStyle())
                    .frame(maxWidth: .infinity)

                    StepDots(current: 4, total: 5)
                }
                .padding(28)
            }
            Spacer()
        }
    }

    // MARK: Step 5 — Done
    private var doneStep: some View {
        VStack(spacing: 16) {
            Spacer()

            // Green checkmark
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color.green, Color(hex: "#66BB6A")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 64, height: 64)
                    .shadow(color: Color.green.opacity(0.3), radius: 12)
                Text("✓")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
            }
            .scaleEffect(1)
            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: step)

            VStack(spacing: 4) {
                Text("You're all set,")
                    .font(.custom("PlayfairDisplay-Italic", size: 24))
                    .foregroundColor(Theme.Colors.textPrimary)
                Text("Miss M!")
                    .font(.custom("PlayfairDisplay-Italic", size: 24))
                    .foregroundColor(Theme.Colors.rosePrimary)
            }

            Text("Your AI assistant is live. You'll receive your first morning briefing tomorrow at 7:30am. You can text your Mac from anywhere and I'll always reply. 💬")
                .font(.system(size: 12))
                .foregroundColor(Theme.Colors.textSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            // Suggested prompts
            VStack(alignment: .leading, spacing: 6) {
                Text("READY TO TRY")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.5)
                    .foregroundColor(Theme.Colors.rosePrimary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("💬 **\"What's on my calendar today?\"**")
                    Text("📚 **\"Help me write my essay\"**")
                    Text("🎯 **\"Quiz me on marketing theory\"**")
                    Text("💙 **\"Text my husband I'm on my way\"**")
                }
                .font(.system(size: 12))
                .foregroundColor(Theme.Colors.textMedium)
            }
            .padding(16)
            .background(Theme.Colors.rosePrimary.opacity(0.06))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.Colors.rosePrimary.opacity(0.14), lineWidth: 1))
            .cornerRadius(16)
            .padding(.horizontal, 20)

            Button("Open Miss M →") {
                try? onSave(apiKey)
            }
            .buttonStyle(RoseButtonStyle())
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 28)

            StepDots(current: 5, total: 5, allDone: true)

            Spacer()
        }
    }
}

// MARK: - Onboarding Components
struct OnboardingFeatureItem: View {
    let icon: String
    let name: String
    let sub: String

    var body: some View {
        VStack(spacing: 5) {
            Text(icon).font(.system(size: 20))
            Text(name)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Theme.Colors.textPrimary)
            Text(sub)
                .font(.system(size: 9))
                .foregroundColor(Theme.Colors.textSoft)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color.white.opacity(0.7))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.Colors.glassBorder, lineWidth: 1))
        .cornerRadius(14)
    }
}

struct PermissionItem: View {
    let icon: String
    let iconBg: Color
    let name: String
    let sub: String
    let isGranted: Bool
    let action: (() -> Void)?

    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: 12) {
                Text(icon)
                    .font(.system(size: 17))
                    .frame(width: 34, height: 34)
                    .background(iconBg)
                    .cornerRadius(10)
                VStack(alignment: .leading, spacing: 1) {
                    Text(name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text(sub)
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.textSoft)
                }
                Spacer()
                Text(isGranted ? "✓ Granted" : "Allow →")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isGranted ? Color.green : Theme.Colors.rosePrimary)
            }
            .padding(12)
            .background(isGranted ? Color(hex: "#F5FFF8").opacity(0.85) : Color.white.opacity(0.65))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(isGranted ? Color.green.opacity(0.3) : Theme.Colors.glassBorder, lineWidth: 1))
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }
}

struct StepDots: View {
    let current: Int
    let total: Int
    var allDone: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...total, id: \.self) { i in
                Circle()
                    .fill(dotColor(for: i))
                    .frame(width: 8, height: 8)
                    .scaleEffect(i == current && !allDone ? 1.2 : 1.0)
                    .animation(.easeOut(duration: 0.3), value: current)
            }
        }
        .padding(.top, 4)
    }

    private func dotColor(for index: Int) -> Color {
        if allDone { return Color.green }
        if index == current { return Theme.Colors.rosePrimary }
        if index < current { return Color.green }
        return Theme.Colors.rosePrimary.opacity(0.18)
    }
}

// MARK: - Today View (Phase 1+2)
struct TodayView: View {
    @State private var events: [CalendarEvent] = []
    @State private var reminders: [MissMReminder] = []
    @State private var greeting: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Greeting card
                VStack(alignment: .leading, spacing: 6) {
                    Text(greetingText)
                        .font(.custom("PlayfairDisplay-Italic", size: 20))
                        .foregroundColor(.white)
                    Text(dateString)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Theme.Gradients.heroCard)
                .cornerRadius(Theme.Radius.md)
                .padding(.horizontal, 16)

                // Today's schedule
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("📅").font(.system(size: 12))
                        Text("TODAY'S SCHEDULE")
                            .font(.custom("CormorantGaramond-SemiBold", size: 10))
                            .tracking(2)
                            .foregroundColor(Theme.Colors.textSoft)
                        Spacer()
                        Text("\(events.count) events")
                            .font(.system(size: 9))
                            .foregroundColor(Theme.Colors.textXSoft)
                    }

                    if events.isEmpty {
                        Text("No events today — enjoy the free time!")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.textSoft)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(events.prefix(5)) { event in
                            HStack(spacing: 8) {
                                Text(event.timeString)
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(Theme.Colors.rosePrimary)
                                    .frame(width: 55, alignment: .leading)
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(Theme.Colors.rosePrimary)
                                    .frame(width: 2, height: 20)
                                Text(event.title)
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.Colors.textPrimary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .padding(12)
                .glassCard(padding: 0)
                .padding(.horizontal, 16)

                // Reminders
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("✅").font(.system(size: 12))
                        Text("REMINDERS")
                            .font(.custom("CormorantGaramond-SemiBold", size: 10))
                            .tracking(2)
                            .foregroundColor(Theme.Colors.textSoft)
                        Spacer()
                        Text("\(reminders.count) pending")
                            .font(.system(size: 9))
                            .foregroundColor(Theme.Colors.textXSoft)
                    }

                    if reminders.isEmpty {
                        Text("All clear — no pending reminders!")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.textSoft)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(reminders.prefix(5)) { reminder in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(reminder.isOverdue ? Color.red : Theme.Colors.roseMid)
                                    .frame(width: 6, height: 6)
                                Text(reminder.title)
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.Colors.textPrimary)
                                    .lineLimit(1)
                                Spacer()
                                if let due = reminder.dueDate {
                                    Text(shortDate(due))
                                        .font(.system(size: 9))
                                        .foregroundColor(reminder.isOverdue ? .red : Theme.Colors.textXSoft)
                                }
                            }
                        }
                    }
                }
                .padding(12)
                .glassCard(padding: 0)
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 10)
        }
        .task {
            events = await CalendarService.shared.getEventsToday()
            reminders = await RemindersService.shared.getIncompleteReminders()
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good Morning, Miss M" }
        if hour < 17 { return "Good Afternoon, Miss M" }
        return "Good Evening, Miss M"
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM yyyy"
        return formatter.string(from: Date())
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - School View (Phase 2) — Sub-navigation hub
struct SchoolView: View {
    let claudeService: ClaudeService
    @State private var selectedFeature: SchoolFeature? = nil

    enum SchoolFeature: String, CaseIterable {
        case assignments = "Assignments"
        case essay = "Essay Writer"
        case study = "Study & Pomodoro"
        case flashcards = "Flashcards"
        case marketing = "Marketing Tools"
        case calendar = "Calendar"
        case macTools = "Mac Tools"

        var icon: String {
            switch self {
            case .assignments: return "📋"
            case .essay: return "✍️"
            case .study: return "⏱"
            case .flashcards: return "🃏"
            case .marketing: return "📊"
            case .calendar: return "📅"
            case .macTools: return "🖥"
            }
        }

        var description: String {
            switch self {
            case .assignments: return "Kanban board for tracking"
            case .essay: return "Outline, draft & cite"
            case .study: return "Focus timer & planner"
            case .flashcards: return "Study with flip cards"
            case .marketing: return "SWOT, STP, Persona & more"
            case .calendar: return "Full calendar view"
            case .macTools: return "PDF reader & screenshot OCR"
            }
        }
    }

    var body: some View {
        if let feature = selectedFeature {
            VStack(spacing: 0) {
                // Back button
                HStack {
                    Button(action: { selectedFeature = nil }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("School")
                        }
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.rosePrimary)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)

                // Feature view
                featureView(for: feature)
            }
        } else {
            // Feature grid
            ScrollView {
                VStack(spacing: 12) {
                    // Header
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SCHOOL")
                            .font(.custom("CormorantGaramond-SemiBold", size: 11))
                            .tracking(2.5)
                            .foregroundColor(Theme.Colors.textSoft)
                        Text("Academic Tools")
                            .font(.custom("PlayfairDisplay-Italic", size: 20))
                            .foregroundColor(Theme.Colors.rosePrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)

                    // Feature cards
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(SchoolFeature.allCases, id: \.self) { feature in
                            Button(action: { selectedFeature = feature }) {
                                VStack(spacing: 8) {
                                    Text(feature.icon)
                                        .font(.system(size: 24))
                                    Text(feature.rawValue)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(Theme.Colors.textPrimary)
                                    Text(feature.description)
                                        .font(.system(size: 9))
                                        .foregroundColor(Theme.Colors.textSoft)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(14)
                                .glassCard(padding: 0)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 10)
            }
        }
    }

    @ViewBuilder
    private func featureView(for feature: SchoolFeature) -> some View {
        switch feature {
        case .assignments:
            AssignmentsView(claudeService: claudeService)
        case .essay:
            EssayView(claudeService: claudeService)
        case .study:
            StudyView()
        case .flashcards:
            FlashcardsView(claudeService: claudeService)
        case .marketing:
            MarketingView(claudeService: claudeService)
        case .calendar:
            CalendarFullView()
        case .macTools:
            MacToolsView(claudeService: claudeService)
        }
    }
}

// HomeHubView is in MissM/Features/Home/HomeHubView.swift
// MessagesView is in MissM/Features/Messages/MessagesView.swift
