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
                    HomeView()
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
struct OnboardingView: View {
    @State private var apiKey = ""
    @State private var isLoading = false
    let onSave: (String) throws -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("♛")
                .font(.system(size: 48))
            Text("Welcome, Miss M")
                .font(.custom("PlayfairDisplay-Italic", size: 28))
                .foregroundColor(Theme.Colors.rosePrimary)
            Text("Enter your Anthropic API key to get started.\nYour key is stored securely in macOS Keychain.")
                .font(.system(size: 13))
                .foregroundColor(Theme.Colors.textSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            VStack(spacing: 10) {
                SecureField("sk-ant-...", text: $apiKey)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Theme.Colors.roseLight, lineWidth: 1.5)
                    )
                    .padding(.horizontal, 24)
                Button("Get Started →") {
                    try? onSave(apiKey)
                }
                .buttonStyle(RoseButtonStyle())
                .disabled(apiKey.isEmpty)
            }
            Text("Get your API key at platform.anthropic.com")
                .font(.system(size: 11))
                .foregroundColor(Theme.Colors.textXSoft)
            Spacer()
        }
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

        var icon: String {
            switch self {
            case .assignments: return "📋"
            case .essay: return "✍️"
            case .study: return "⏱"
            case .flashcards: return "🃏"
            case .marketing: return "📊"
            case .calendar: return "📅"
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
        }
    }
}

// MARK: - Placeholder Views (future phases)
struct HomeView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("🏠").font(.system(size: 36))
                Text("Home Hub")
                    .font(.custom("PlayfairDisplay-Italic", size: 20))
                    .foregroundColor(Theme.Colors.rosePrimary)
                Text("Meal planning, grocery lists, budget tracking,\nand email drafting — coming in Phase 4.")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.textSoft)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
        }
    }
}
