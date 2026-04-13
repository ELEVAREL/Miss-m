import SwiftUI

// MARK: - Menu Bar Mini View
// Compact ♛ popover: stats + next event + quick chat

struct MenuBarMiniView: View {
    let claudeService: ClaudeService
    @State private var nextEvent = "Loading..."
    @State private var taskCount = 0
    @State private var quickMessage = ""
    @State private var aiReply = ""
    @State private var isAsking = false

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // Greeting
                HStack {
                    Text("Mini View")
                        .font(Theme.Fonts.display(18))
                        .foregroundColor(Theme.Colors.rosePrimary)
                    Spacer()
                }
                .padding(.horizontal, 14)

                // Stats Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    MiniStatCard(icon: "\u{1F4C5}", value: "Today", label: "Events")
                    MiniStatCard(icon: "\u{2705}", value: "\(taskCount)", label: "Tasks")
                    MiniStatCard(icon: "\u{23F0}", value: timeString, label: "Now")
                    MiniStatCard(icon: "\u{2600}\u{FE0F}", value: dayName, label: "Day")
                }
                .padding(.horizontal, 14)

                // Next Event
                VStack(alignment: .leading, spacing: 4) {
                    Text("\u{1F4C5} NEXT UP")
                        .font(.custom("CormorantGaramond-SemiBold", size: 11))
                        .tracking(2)
                        .foregroundColor(Theme.Colors.textSoft)
                    Text(nextEvent)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.textPrimary)
                }
                .glassCard(padding: 10)
                .padding(.horizontal, 14)

                // Quick Chat
                VStack(alignment: .leading, spacing: 6) {
                    Text("\u{1F4AC} QUICK ASK")
                        .font(.custom("CormorantGaramond-SemiBold", size: 11))
                        .tracking(2)
                        .foregroundColor(Theme.Colors.textSoft)

                    if !aiReply.isEmpty {
                        Text(aiReply)
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.textPrimary)
                            .padding(8)
                            .background(Color.white.opacity(0.6))
                            .cornerRadius(10)
                    }

                    HStack(spacing: 6) {
                        TextField("Ask Miss M...", text: $quickMessage)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11))
                            .padding(8)
                            .background(Color.white.opacity(0.7))
                            .cornerRadius(8)
                            .onSubmit { Task { await askAI() } }
                        Button(action: { Task { await askAI() } }) {
                            if isAsking {
                                ProgressView().scaleEffect(0.5)
                            } else {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(Theme.Colors.rosePrimary)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(quickMessage.isEmpty || isAsking)
                    }
                }
                .glassCard(padding: 10)
                .padding(.horizontal, 14)

                // Quick Actions
                VStack(alignment: .leading, spacing: 6) {
                    Text("QUICK ACTIONS")
                        .font(.custom("CormorantGaramond-SemiBold", size: 11))
                        .tracking(2)
                        .foregroundColor(Theme.Colors.textSoft)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            QuickActionChip(icon: "\u{1F4E7}", label: "Draft Email")
                            QuickActionChip(icon: "\u{1F345}", label: "Pomodoro")
                            QuickActionChip(icon: "\u{1F4DD}", label: "New Reminder")
                            QuickActionChip(icon: "\u{1F6D2}", label: "Grocery")
                        }
                    }
                }
                .glassCard(padding: 10)
                .padding(.horizontal, 14)

                Spacer().frame(height: 14)
            }
            .padding(.top, 10)
        }
        .task {
            nextEvent = await CalendarService.shared.nextEventSummary()
            taskCount = await RemindersService.shared.incompleteCount()
        }
    }

    var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm"
        return f.string(from: Date())
    }

    var dayName: String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: Date())
    }

    func askAI() async {
        guard !quickMessage.isEmpty else { return }
        isAsking = true
        do {
            aiReply = try await claudeService.ask(quickMessage)
            quickMessage = ""
        } catch {
            aiReply = "Sorry, couldn't get an answer right now."
        }
        isAsking = false
    }
}

// MARK: - Mini Stat Card

struct MiniStatCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            Text(icon).font(.system(size: 14))
            Text(value)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Theme.Colors.textPrimary)
            Text(label)
                .font(.system(size: 8))
                .foregroundColor(Theme.Colors.textXSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.6))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.glassBorder, lineWidth: 0.5))
    }
}

// MARK: - Quick Action Chip

struct QuickActionChip: View {
    let icon: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Text(icon).font(.system(size: 10))
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.Colors.textMedium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.7))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Colors.roseLight, lineWidth: 1))
    }
}
