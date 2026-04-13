import SwiftUI

// MARK: - Quick Launcher Models

struct LauncherItem: Identifiable {
    let id = UUID()
    let icon: String
    let name: String
    let subtitle: String
    let section: LauncherSection
    let action: () -> Void
}

enum LauncherSection: String {
    case suggested = "Suggested Actions"
    case quickOpen = "Quick Open"
    case recent = "Recent"
}

// MARK: - Quick Launcher ViewModel

@Observable
class QuickLauncherViewModel {
    var query = ""
    var isVisible = false

    var allItems: [LauncherItem] {
        [
            LauncherItem(icon: "\u{1F4AC}", name: "Chat with Miss M", subtitle: "Ask anything", section: .suggested, action: {}),
            LauncherItem(icon: "\u{1F4E7}", name: "Draft Email", subtitle: "AI-powered email writer", section: .suggested, action: {}),
            LauncherItem(icon: "\u{1F345}", name: "Start Pomodoro", subtitle: "25-min focus session", section: .suggested, action: {}),
            LauncherItem(icon: "\u{1F4DD}", name: "New Reminder", subtitle: "Add to Reminders", section: .suggested, action: {}),
            LauncherItem(icon: "\u{1F4C4}", name: "Read PDF", subtitle: "Drop & analyse with AI", section: .quickOpen, action: {}),
            LauncherItem(icon: "\u{1F4F7}", name: "Screenshot OCR", subtitle: "Capture & extract text", section: .quickOpen, action: {}),
            LauncherItem(icon: "\u{1F310}", name: "Safari Reader", subtitle: "Read current page", section: .quickOpen, action: {}),
            LauncherItem(icon: "\u{1F4C1}", name: "File Centre", subtitle: "Drop any file for AI", section: .quickOpen, action: {}),
            LauncherItem(icon: "\u{1F35D}", name: "Meal Planner", subtitle: "Plan this week's meals", section: .recent, action: {}),
            LauncherItem(icon: "\u{1F6D2}", name: "Grocery List", subtitle: "Shopping list", section: .recent, action: {}),
            LauncherItem(icon: "\u{1F4B0}", name: "Budget", subtitle: "Track expenses", section: .recent, action: {}),
        ]
    }

    var filteredItems: [LauncherItem] {
        if query.isEmpty { return allItems }
        return allItems.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.subtitle.localizedCaseInsensitiveContains(query)
        }
    }

    var groupedItems: [(String, [LauncherItem])] {
        let grouped = Dictionary(grouping: filteredItems) { $0.section.rawValue }
        let order: [LauncherSection] = [.suggested, .quickOpen, .recent]
        return order.compactMap { section in
            guard let items = grouped[section.rawValue], !items.isEmpty else { return nil }
            return (section.rawValue, items)
        }
    }
}

// MARK: - Quick Launcher View

struct QuickLauncherView: View {
    let claudeService: ClaudeService
    @State private var viewModel = QuickLauncherViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack(spacing: 8) {
                Text("\u{265B}")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.Colors.rosePrimary)
                TextField("What would you like to do?", text: $viewModel.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundColor(Theme.Colors.textPrimary)
                Spacer()
                Text("\u{2318}\u{21E7}M")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Theme.Colors.textXSoft)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Theme.Colors.rosePale.opacity(0.5))
                    .cornerRadius(4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.8))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Theme.Colors.glassBorder),
                alignment: .bottom
            )

            // Results
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(viewModel.groupedItems, id: \.0) { section, items in
                        Text(section.uppercased())
                            .font(.custom("CormorantGaramond-SemiBold", size: 10))
                            .tracking(2)
                            .foregroundColor(Theme.Colors.textXSoft)
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                            .padding(.bottom, 4)

                        ForEach(items) { item in
                            Button(action: item.action) {
                                HStack(spacing: 10) {
                                    Text(item.icon)
                                        .font(.system(size: 16))
                                        .frame(width: 28, height: 28)
                                        .background(Theme.Colors.rosePale.opacity(0.5))
                                        .cornerRadius(8)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(item.name)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(Theme.Colors.textPrimary)
                                        Text(item.subtitle)
                                            .font(.system(size: 10))
                                            .foregroundColor(Theme.Colors.textSoft)
                                    }
                                    Spacer()
                                    Image(systemName: "return")
                                        .font(.system(size: 9))
                                        .foregroundColor(Theme.Colors.textXSoft)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(Color.clear)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.bottom, 10)
            }

            // Footer
            HStack(spacing: 16) {
                footerKey("\u{21A9}", "Select")
                footerKey("\u{2191}\u{2193}", "Navigate")
                footerKey("Esc", "Close")
            }
            .padding(.horizontal, 16)
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

    func footerKey(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(Theme.Colors.textXSoft)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Theme.Colors.rosePale.opacity(0.4))
                .cornerRadius(3)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(Theme.Colors.textXSoft)
        }
    }
}
