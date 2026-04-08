import SwiftUI
import AppKit

// MARK: - Quick Launcher View (Phase 7)
// Cmd+Shift+M spotlight-style launcher — natural language to any feature

struct QuickLauncherView: View {
    let claudeService: ClaudeService
    @State private var query = ""
    @State private var results: [LauncherResult] = []
    @State private var selectedIndex = 0

    var body: some View {
        VStack(spacing: 0) {
            // Search input
            HStack(spacing: 10) {
                Text("♛")
                    .font(.system(size: 18))
                    .foregroundColor(Theme.Colors.rosePrimary)

                TextField("What do you need, Miss M?", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .onChange(of: query) { search() }

                if !query.isEmpty {
                    Button(action: { query = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.textXSoft)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.95))

            Divider()

            // Results
            if results.isEmpty && !query.isEmpty {
                VStack(spacing: 8) {
                    Text("No matches")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.textSoft)
                    Text("Try: \"assignments\", \"essay\", \"timer\", \"budget\"")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.textXSoft)
                }
                .padding(20)
            } else if query.isEmpty {
                // Quick actions
                VStack(alignment: .leading, spacing: 4) {
                    Text("QUICK ACTIONS")
                        .font(.custom("CormorantGaramond-SemiBold", size: 9))
                        .tracking(2)
                        .foregroundColor(Theme.Colors.textSoft)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    ForEach(LauncherResult.quickActions) { result in
                        LauncherRow(result: result, isSelected: false)
                    }
                }
                .padding(.bottom, 8)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                            LauncherRow(result: result, isSelected: index == selectedIndex)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 300)
            }
        }
        .background(Theme.Colors.roseUltra)
        .cornerRadius(Theme.Radius.lg)
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
        .frame(width: 420)
    }

    private func search() {
        let q = query.lowercased()
        guard !q.isEmpty else { results = []; return }

        results = LauncherResult.allFeatures.filter { feature in
            feature.title.lowercased().contains(q) ||
            feature.keywords.contains(where: { $0.contains(q) })
        }
        selectedIndex = 0
    }
}

// MARK: - Launcher Row
struct LauncherRow: View {
    let result: LauncherResult
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(result.icon)
                .font(.system(size: 16))
                .frame(width: 28, height: 28)
                .background(isSelected ? Theme.Colors.rosePrimary.opacity(0.15) : Color.clear)
                .cornerRadius(6)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.Colors.textPrimary)
                Text(result.subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.Colors.textSoft)
            }

            Spacer()

            if let shortcut = result.shortcut {
                Text(shortcut)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Theme.Colors.textXSoft)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.5))
                    .cornerRadius(4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(isSelected ? Theme.Colors.rosePale : Color.clear)
    }
}

// MARK: - Launcher Result Model
struct LauncherResult: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let keywords: [String]
    let shortcut: String?

    static let quickActions: [LauncherResult] = [
        LauncherResult(icon: "✦", title: "Ask Miss M AI", subtitle: "Chat with your assistant", keywords: ["chat", "ask", "help"], shortcut: "⌘1"),
        LauncherResult(icon: "📅", title: "Today's Schedule", subtitle: "View calendar + reminders", keywords: ["today", "schedule"], shortcut: "⌘2"),
        LauncherResult(icon: "⏱", title: "Start Pomodoro", subtitle: "Begin a focus session", keywords: ["timer", "focus", "study"], shortcut: nil),
        LauncherResult(icon: "💬", title: "Message NyRiian", subtitle: "Quick message to husband", keywords: ["message", "text", "husband"], shortcut: nil),
    ]

    static let allFeatures: [LauncherResult] = [
        // Chat
        LauncherResult(icon: "✦", title: "Chat", subtitle: "Talk to Miss M AI", keywords: ["chat", "ask", "ai", "help", "assistant"], shortcut: nil),
        // School
        LauncherResult(icon: "📋", title: "Assignments", subtitle: "Kanban board", keywords: ["assignments", "homework", "kanban", "todo", "tasks"], shortcut: nil),
        LauncherResult(icon: "✍️", title: "Essay Writer", subtitle: "Outline, draft & cite", keywords: ["essay", "write", "paper", "academic", "draft"], shortcut: nil),
        LauncherResult(icon: "⏱", title: "Study Planner", subtitle: "Pomodoro timer & schedule", keywords: ["study", "pomodoro", "timer", "focus", "planner"], shortcut: nil),
        LauncherResult(icon: "🃏", title: "Flashcards", subtitle: "Study with flip cards", keywords: ["flashcard", "quiz", "review", "cards", "study"], shortcut: nil),
        LauncherResult(icon: "📊", title: "Marketing Tools", subtitle: "SWOT, STP, Persona, PESTLE", keywords: ["marketing", "swot", "stp", "persona", "pestle", "campaign", "analysis"], shortcut: nil),
        LauncherResult(icon: "📅", title: "Calendar", subtitle: "Month view + events", keywords: ["calendar", "events", "schedule", "month"], shortcut: nil),
        // Home
        LauncherResult(icon: "🍽", title: "Meal Planner", subtitle: "7-day meal plan", keywords: ["meal", "food", "dinner", "breakfast", "lunch", "cook"], shortcut: nil),
        LauncherResult(icon: "🛒", title: "Grocery List", subtitle: "Shopping checklist", keywords: ["grocery", "shopping", "buy", "store", "list"], shortcut: nil),
        LauncherResult(icon: "💰", title: "Budget", subtitle: "Track spending", keywords: ["budget", "money", "spending", "expense", "finance", "save"], shortcut: nil),
        LauncherResult(icon: "📧", title: "Email Drafter", subtitle: "AI-powered email writing", keywords: ["email", "mail", "professor", "draft", "send"], shortcut: nil),
        // Messages
        LauncherResult(icon: "💬", title: "Messages", subtitle: "iMessage centre", keywords: ["message", "imessage", "text", "sms", "chat"], shortcut: nil),
        LauncherResult(icon: "💕", title: "Message NyRiian", subtitle: "Quick message husband", keywords: ["nyriian", "husband", "love", "partner"], shortcut: nil),
        // Tools
        LauncherResult(icon: "📄", title: "PDF Reader", subtitle: "Read & summarise PDFs", keywords: ["pdf", "document", "read", "summarise"], shortcut: nil),
        LauncherResult(icon: "📸", title: "Screenshot OCR", subtitle: "Extract text from screen", keywords: ["screenshot", "ocr", "capture", "text", "image"], shortcut: nil),
        // Settings
        LauncherResult(icon: "⚙️", title: "Settings", subtitle: "API key & permissions", keywords: ["settings", "config", "api", "key", "setup"], shortcut: nil),
    ]
}
