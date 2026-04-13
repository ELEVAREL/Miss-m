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
    @State private var touchID = TouchIDManager()
    @State private var isLocked = false

    var body: some View {
        Group {
            if isLocked && touchID.lockEnabled {
                TouchIDLockView(isLocked: $isLocked, touchID: touchID)
            } else if claudeService == nil {
                OnboardingView { apiKey in
                    try KeychainManager.saveAPIKey(apiKey)
                    claudeService = ClaudeService(apiKey: apiKey)
                }
            } else {
                MainAppView(
                    selectedTab: $selectedTab,
                    claudeService: claudeService!
                )
                .withNotifications()
            }
        }
        .frame(minWidth: 520, idealWidth: 780, maxWidth: .infinity, minHeight: 500, idealHeight: 720, maxHeight: .infinity)
        .background(Theme.Gradients.background)
        .preferredColorScheme(.light)
    }
}

// MARK: - App Tabs
enum AppTab: String, CaseIterable {
    case chat      = "✦"
    case today     = "☀️"
    case school    = "📚"
    case home      = "🏠"
    case planner   = "🧠"
    case tools     = "🔧"
    case wellness  = "💗"
    case settings  = "⚙️"

    var label: String {
        switch self {
        case .chat:     return "Chat"
        case .today:    return "Today"
        case .school:   return "School"
        case .home:     return "Home"
        case .planner:  return "Planner"
        case .tools:    return "Tools"
        case .wellness: return "Health"
        case .settings: return "Settings"
        }
    }
}

// MARK: - Main App View (Sidebar + Content)
struct MainAppView: View {
    @Binding var selectedTab: AppTab
    let claudeService: ClaudeService

    var body: some View {
        HStack(spacing: 0) {
            // Left Sidebar
            Sidebar(selected: $selectedTab)

            // Divider
            Rectangle()
                .fill(Theme.Colors.glassBorder)
                .frame(width: 1)

            // Main Content
            VStack(spacing: 0) {
                Group {
                    switch selectedTab {
                    case .chat:
                        ChatView(claudeService: claudeService)
                    case .today:
                        TodayView(claudeService: claudeService)
                    case .school:
                        SchoolView(claudeService: claudeService)
                    case .home:
                        HomeView(claudeService: claudeService)
                    case .planner:
                        SmartPlannerView(claudeService: claudeService)
                    case .tools:
                        MacToolsView(claudeService: claudeService)
                    case .wellness:
                        WellnessTabView(claudeService: claudeService)
                    case .settings:
                        SettingsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Sidebar
struct Sidebar: View {
    @Binding var selected: AppTab

    var body: some View {
        VStack(spacing: 4) {
            // Logo
            VStack(spacing: 4) {
                Text("\u{265B}")
                    .font(.system(size: 28))
                Text("Miss M")
                    .font(.custom("PlayfairDisplay-BoldItalic", size: 14))
                    .foregroundColor(Theme.Colors.rosePrimary)
            }
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Nav items
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button(action: { selected = tab }) {
                    HStack(spacing: 10) {
                        Text(tab.rawValue)
                            .font(.system(size: 18))
                        Text(tab.label)
                            .font(.system(size: 13, weight: selected == tab ? .semibold : .regular))
                            .foregroundColor(selected == tab ? .white : Theme.Colors.textMedium)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        selected == tab
                        ? Theme.Gradients.rosePrimary
                        : LinearGradient(colors: [Color.clear], startPoint: .top, endPoint: .bottom)
                    )
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
            }

            Spacer()

            // Status
            HStack(spacing: 5) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                    .shadow(color: Color.green.opacity(0.7), radius: 4)
                Text("Active")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Theme.Colors.textSoft)
            }
            .padding(.bottom, 16)
        }
        .frame(width: 160)
        .background(Color.white.opacity(0.4))
        .background(.ultraThinMaterial)
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
                    .font(.system(size: 14))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .padding(12)
                    .background(Theme.Colors.rosePale)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Theme.Colors.roseLight, lineWidth: 1.5)
                    )
                    .padding(.horizontal, 24)
                Button("Get Started \u{2192}") {
                    try? onSave(apiKey)
                }
                .buttonStyle(RoseButtonStyle())
                .disabled(apiKey.isEmpty)
            }
            Text("Get your API key at console.anthropic.com")
                .font(.system(size: 11))
                .foregroundColor(Theme.Colors.textXSoft)
            Spacer()
        }
    }
}

// MARK: - Placeholder Views (Claude Code will fill these in)
// MARK: - Today Tab Enum
enum TodayTab: String, CaseIterable {
    case overview = "Overview"
    case reminders = "Reminders"

    var icon: String {
        switch self {
        case .overview: return "\u{2600}\u{FE0F}"
        case .reminders: return "\u{2705}"
        }
    }
}

struct TodayView: View {
    let claudeService: ClaudeService
    @State private var selectedTab: TodayTab = .overview

    var body: some View {
        VStack(spacing: 0) {
            // Sub-tabs
            HStack(spacing: 6) {
                ForEach(TodayTab.allCases, id: \.self) { tab in
                    Button(action: { selectedTab = tab }) {
                        HStack(spacing: 3) {
                            Text(tab.icon).font(.system(size: 10))
                            Text(tab.rawValue).font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(selectedTab == tab ? .white : Theme.Colors.textMedium)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(selectedTab == tab ? Theme.Gradients.rosePrimary : LinearGradient(colors: [Color.white.opacity(0.6)], startPoint: .top, endPoint: .bottom))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(selectedTab == tab ? Color.clear : Theme.Colors.roseLight, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Theme.Colors.glassWhite)
            .overlay(Rectangle().frame(height: 1).foregroundColor(Theme.Colors.glassBorder), alignment: .bottom)

            // Content
            switch selectedTab {
            case .overview:
                TodayOverviewView(claudeService: claudeService)
            case .reminders:
                RemindersListView()
            }
        }
    }
}

// MARK: - Today Overview
struct TodayOverviewView: View {
    let claudeService: ClaudeService
    @State private var todayEvents: String = ""
    @State private var todayReminders: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Greeting Card
                VStack(spacing: 6) {
                    Text("Good \(greetingTime), Miss M")
                        .font(Theme.Fonts.display(20))
                        .foregroundColor(.white)
                    Text(dateString)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(Theme.Gradients.heroCard)
                .cornerRadius(Theme.Radius.lg)
                .padding(.horizontal, 14)

                // Today's Schedule
                VStack(alignment: .leading, spacing: 6) {
                    Text("\u{1F4C5} TODAY'S SCHEDULE")
                        .font(.custom("CormorantGaramond-SemiBold", size: 11))
                        .tracking(2)
                        .foregroundColor(Theme.Colors.textSoft)
                    Text(todayEvents.isEmpty ? "Loading..." : todayEvents)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.textMedium)
                }
                .glassCard(padding: 10)
                .padding(.horizontal, 14)

                // Tasks
                VStack(alignment: .leading, spacing: 6) {
                    Text("\u{2705} TASKS")
                        .font(.custom("CormorantGaramond-SemiBold", size: 11))
                        .tracking(2)
                        .foregroundColor(Theme.Colors.textSoft)
                    Text(todayReminders.isEmpty ? "Loading..." : todayReminders)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.textMedium)
                }
                .glassCard(padding: 10)
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
            .padding(.top, 10)
        }
        .task {
            todayEvents = await CalendarService.shared.todaySummary()
            todayReminders = await RemindersService.shared.todaySummary()
        }
    }

    var greetingTime: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "morning" }
        if hour < 17 { return "afternoon" }
        return "evening"
    }

    var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: Date())
    }
}
// MARK: - School Tab Enum
enum SchoolTab: String, CaseIterable {
    case assignments = "Assignments"
    case essay = "Essay"
    case writing = "Writing"
    case study = "Study"
    case flashcards = "Cards"
    case marketing = "Marketing"
    case research = "Research"
    case calendar = "Calendar"

    var icon: String {
        switch self {
        case .assignments: return "\u{1F4CB}"
        case .essay: return "\u{270D}\u{FE0F}"
        case .writing: return "\u{2728}"
        case .study: return "\u{1F345}"
        case .flashcards: return "\u{1F0CF}"
        case .marketing: return "\u{1F4CA}"
        case .research: return "\u{1F50D}"
        case .calendar: return "\u{1F4C5}"
        }
    }
}

struct SchoolView: View {
    let claudeService: ClaudeService
    @State private var selectedTab: SchoolTab = .assignments

    var body: some View {
        VStack(spacing: 0) {
            // School sub-tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(SchoolTab.allCases, id: \.self) { tab in
                        Button(action: { selectedTab = tab }) {
                            HStack(spacing: 3) {
                                Text(tab.icon)
                                    .font(.system(size: 9))
                                Text(tab.rawValue)
                                    .font(.system(size: 9, weight: .medium))
                            }
                            .foregroundColor(selectedTab == tab ? .white : Theme.Colors.textMedium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(selectedTab == tab ? Theme.Gradients.rosePrimary : LinearGradient(colors: [Color.white.opacity(0.6)], startPoint: .top, endPoint: .bottom))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(selectedTab == tab ? Color.clear : Theme.Colors.roseLight, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .background(Theme.Colors.glassWhite)
            .overlay(Rectangle().frame(height: 1).foregroundColor(Theme.Colors.glassBorder), alignment: .bottom)

            // Tab content
            Group {
                switch selectedTab {
                case .assignments:
                    AssignmentsView(claudeService: claudeService)
                case .essay:
                    EssayWriterView(claudeService: claudeService)
                case .writing:
                    SmartWritingView(claudeService: claudeService)
                case .study:
                    StudyPlannerView(claudeService: claudeService)
                case .flashcards:
                    FlashcardsView(claudeService: claudeService)
                case .marketing:
                    MarketingToolsView(claudeService: claudeService)
                case .research:
                    ResearchView(claudeService: claudeService)
                case .calendar:
                    CalendarFullView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
// MARK: - Mac Tools Tab Enum
enum MacToolsTab: String, CaseIterable {
    case pdf = "PDF"
    case screenshot = "OCR"
    case safari = "Safari"
    case files = "Files"
    case pomodoro = "Timer"
    case voice = "Voice"
    case notes = "Notes"
    case system = "System"
    case mini = "Mini"
    case launcher = "Launch"

    var icon: String {
        switch self {
        case .pdf: return "\u{1F4C4}"
        case .screenshot: return "\u{1F4F7}"
        case .safari: return "\u{1F310}"
        case .files: return "\u{1F4C1}"
        case .pomodoro: return "\u{1F345}"
        case .voice: return "\u{1F399}\u{FE0F}"
        case .notes: return "\u{1F4DD}"
        case .system: return "\u{1F5A5}"
        case .mini: return "\u{265B}"
        case .launcher: return "\u{26A1}"
        }
    }
}

struct MacToolsView: View {
    let claudeService: ClaudeService
    @State private var selectedTab: MacToolsTab = .pdf

    var body: some View {
        VStack(spacing: 0) {
            // Sub-tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(MacToolsTab.allCases, id: \.self) { tab in
                        Button(action: { selectedTab = tab }) {
                            HStack(spacing: 3) {
                                Text(tab.icon).font(.system(size: 9))
                                Text(tab.rawValue).font(.system(size: 9, weight: .medium))
                            }
                            .foregroundColor(selectedTab == tab ? .white : Theme.Colors.textMedium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(selectedTab == tab ? Theme.Gradients.rosePrimary : LinearGradient(colors: [Color.white.opacity(0.6)], startPoint: .top, endPoint: .bottom))
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selectedTab == tab ? Color.clear : Theme.Colors.roseLight, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .background(Theme.Colors.glassWhite)
            .overlay(Rectangle().frame(height: 1).foregroundColor(Theme.Colors.glassBorder), alignment: .bottom)

            // Content
            Group {
                switch selectedTab {
                case .pdf:
                    PDFDropzoneView(claudeService: claudeService)
                case .screenshot:
                    ScreenshotOCRView(claudeService: claudeService)
                case .safari:
                    SafariCompanionView(claudeService: claudeService)
                case .files:
                    FileCommandCentreView(claudeService: claudeService)
                case .pomodoro:
                    PomodoroMenuBarView(claudeService: claudeService)
                case .voice:
                    VoiceInputView(claudeService: claudeService)
                case .notes:
                    AppleNotesSyncView(claudeService: claudeService)
                case .system:
                    SystemDashboardView()
                case .mini:
                    MenuBarMiniView(claudeService: claudeService)
                case .launcher:
                    QuickLauncherView(claudeService: claudeService)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct HomeView: View {
    let claudeService: ClaudeService
    @State private var selectedTab: HomeTab = .hub

    var body: some View {
        VStack(spacing: 0) {
            // Sub-tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(HomeTab.allCases, id: \.self) { tab in
                        Button(action: { selectedTab = tab }) {
                            HStack(spacing: 3) {
                                Text(tab.icon).font(.system(size: 9))
                                Text(tab.rawValue).font(.system(size: 9, weight: .medium))
                            }
                            .foregroundColor(selectedTab == tab ? .white : Theme.Colors.textMedium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(selectedTab == tab ? Theme.Gradients.rosePrimary : LinearGradient(colors: [Color.white.opacity(0.6)], startPoint: .top, endPoint: .bottom))
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selectedTab == tab ? Color.clear : Theme.Colors.roseLight, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .background(Theme.Colors.glassWhite)
            .overlay(Rectangle().frame(height: 1).foregroundColor(Theme.Colors.glassBorder), alignment: .bottom)

            // Content
            Group {
                switch selectedTab {
                case .hub:
                    HomeHubView(claudeService: claudeService, selectedTab: $selectedTab)
                case .meals:
                    MealPlannerView(claudeService: claudeService)
                case .grocery:
                    GroceryListView()
                case .budget:
                    BudgetTrackerView()
                case .email:
                    EmailDrafterView(claudeService: claudeService)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
