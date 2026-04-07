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

// MARK: - Placeholder Views (Claude Code will fill these in)
struct TodayView: View {
    var body: some View {
        ScrollView { Text("Today — Claude Code will build this") .padding() }
    }
}
struct SchoolView: View {
    let claudeService: ClaudeService
    var body: some View {
        ScrollView { Text("School — Claude Code will build this") .padding() }
    }
}
struct HomeView: View {
    var body: some View {
        ScrollView { Text("Home — Claude Code will build this") .padding() }
    }
}
