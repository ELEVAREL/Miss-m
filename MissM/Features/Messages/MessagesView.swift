import SwiftUI

// MARK: - Messages View (Phase 3)
// iMessage monitor + auto-reply controls + NyRiian quick chat

struct MessagesView: View {
    let claudeService: ClaudeService
    @State private var viewModel: MessagesViewModel

    init(claudeService: ClaudeService) {
        self.claudeService = claudeService
        self._viewModel = State(initialValue: MessagesViewModel(claudeService: claudeService))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("IMESSAGE")
                            .font(.custom("CormorantGaramond-SemiBold", size: 11))
                            .tracking(2.5)
                            .foregroundColor(Theme.Colors.textSoft)
                        Text("Message Centre")
                            .font(.custom("PlayfairDisplay-Italic", size: 18))
                            .foregroundColor(Theme.Colors.rosePrimary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)

                // NyRiian quick card (always pinned #1)
                NyRiianCard(viewModel: viewModel)
                    .padding(.horizontal, 16)

                // Auto-reply toggle
                AutoReplyCard(viewModel: viewModel)
                    .padding(.horizontal, 16)

                // Briefing schedule
                BriefingCard(viewModel: viewModel)
                    .padding(.horizontal, 16)

                // Quick compose
                QuickComposeCard(viewModel: viewModel)
                    .padding(.horizontal, 16)
            }
            .padding(.vertical, 10)
        }
    }
}

// MARK: - NyRiian Card (always #1)
struct NyRiianCard: View {
    let viewModel: MessagesViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Hero header
            HStack(spacing: 12) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(Theme.Gradients.heroCard)
                        .frame(width: 44, height: 44)
                    Text("N")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("NyRiian")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Text("💕")
                            .font(.system(size: 12))
                    }
                    Text("Husband")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
                Image(systemName: "pin.fill")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.Colors.gold)
            }
            .padding(14)
            .background(Theme.Gradients.heroCard)
            .cornerRadius(Theme.Radius.md, corners: [.topLeft, .topRight])

            // Quick chips
            VStack(spacing: 8) {
                Text("QUICK MESSAGES")
                    .font(.custom("CormorantGaramond-SemiBold", size: 9))
                    .tracking(2)
                    .foregroundColor(Theme.Colors.textSoft)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(viewModel.nyriianChips, id: \.self) { chip in
                        Button(action: { viewModel.sendToNyRiian(chip) }) {
                            Text(chip)
                                .font(.system(size: 10))
                                .foregroundColor(Theme.Colors.textMedium)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(Color.white.opacity(0.7))
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.Colors.roseLight, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }

                if viewModel.isSending {
                    HStack(spacing: 4) {
                        ProgressView().scaleEffect(0.5)
                        Text("Sending...").font(.system(size: 9)).foregroundColor(Theme.Colors.textSoft)
                    }
                }

                if let status = viewModel.sendStatus {
                    Text(status)
                        .font(.system(size: 9))
                        .foregroundColor(status.contains("Sent") ? .green : .red)
                }
            }
            .padding(12)
            .background(Theme.Colors.glassWhite)
            .cornerRadius(Theme.Radius.md, corners: [.bottomLeft, .bottomRight])
        }
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(Theme.Colors.glassBorder, lineWidth: 1)
        )
        .shadow(color: Theme.Colors.shadow, radius: 10, x: 0, y: 4)
    }
}

// MARK: - Auto Reply Card
struct AutoReplyCard: View {
    let viewModel: MessagesViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("🤖").font(.system(size: 14))
                Text("AUTO-REPLY")
                    .font(.custom("CormorantGaramond-SemiBold", size: 10))
                    .tracking(2)
                    .foregroundColor(Theme.Colors.textSoft)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { viewModel.isAutoReplyEnabled },
                    set: { viewModel.toggleAutoReply($0) }
                ))
                .toggleStyle(.switch)
                .scaleEffect(0.7)
            }

            Text(viewModel.isAutoReplyEnabled
                 ? "Claude is monitoring incoming messages and replying on your behalf."
                 : "Enable to let Claude auto-reply to your iMessages.")
                .font(.system(size: 10))
                .foregroundColor(Theme.Colors.textSoft)

            if viewModel.isAutoReplyEnabled {
                HStack(spacing: 6) {
                    Circle().fill(Color.green).frame(width: 6, height: 6)
                        .shadow(color: .green.opacity(0.5), radius: 3)
                    Text("Polling every 10 seconds")
                        .font(.system(size: 9))
                        .foregroundColor(.green)
                }
            }
        }
        .padding(12)
        .glassCard(padding: 0)
    }
}

// MARK: - Briefing Card
struct BriefingCard: View {
    let viewModel: MessagesViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("🌅").font(.system(size: 14))
                Text("DAILY BRIEFINGS")
                    .font(.custom("CormorantGaramond-SemiBold", size: 10))
                    .tracking(2)
                    .foregroundColor(Theme.Colors.textSoft)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { viewModel.isBriefingEnabled },
                    set: { viewModel.toggleBriefing($0) }
                ))
                .toggleStyle(.switch)
                .scaleEffect(0.7)
            }

            VStack(spacing: 6) {
                BriefingRow(emoji: "☀️", label: "Morning Briefing", time: "7:30 AM", detail: "Schedule, deadlines, weather")
                BriefingRow(emoji: "🌙", label: "Evening Wind-Down", time: "9:00 PM", detail: "Day recap, rest reminder")
                BriefingRow(emoji: "📋", label: "Sunday Plan", time: "7:00 PM", detail: "Weekly overview")
            }
        }
        .padding(12)
        .glassCard(padding: 0)
    }
}

struct BriefingRow: View {
    let emoji: String
    let label: String
    let time: String
    let detail: String

    var body: some View {
        HStack(spacing: 8) {
            Text(emoji).font(.system(size: 12))
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.Colors.textPrimary)
                Text(detail)
                    .font(.system(size: 9))
                    .foregroundColor(Theme.Colors.textXSoft)
            }
            Spacer()
            Text(time)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(Theme.Colors.rosePrimary)
        }
    }
}

// MARK: - Quick Compose Card
struct QuickComposeCard: View {
    let viewModel: MessagesViewModel
    @State private var recipient = ""
    @State private var message = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("COMPOSE")
                .font(.custom("CormorantGaramond-SemiBold", size: 10))
                .tracking(2)
                .foregroundColor(Theme.Colors.textSoft)

            TextField("Phone number or contact name", text: $recipient)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .padding(8)
                .background(Color.white.opacity(0.7))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.Colors.roseLight, lineWidth: 1))

            HStack(spacing: 6) {
                TextField("Message...", text: $message)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .padding(8)
                    .background(Color.white.opacity(0.7))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.Colors.roseLight, lineWidth: 1))

                Button(action: {
                    viewModel.sendMessage(message, to: recipient)
                    message = ""
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Theme.Colors.rosePrimary)
                }
                .buttonStyle(.plain)
                .disabled(recipient.isEmpty || message.isEmpty)
            }
        }
        .padding(12)
        .glassCard(padding: 0)
    }
}

// MARK: - Corner Radius Helper
extension View {
    func cornerRadius(_ radius: CGFloat, corners: [Corner]) -> some View {
        clipShape(RoundedCornerShape(radius: radius, corners: corners))
    }
}

enum Corner { case topLeft, topRight, bottomLeft, bottomRight }

struct RoundedCornerShape: Shape {
    var radius: CGFloat
    var corners: [Corner]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tl = corners.contains(.topLeft) ? radius : 0
        let tr = corners.contains(.topRight) ? radius : 0
        let bl = corners.contains(.bottomLeft) ? radius : 0
        let br = corners.contains(.bottomRight) ? radius : 0

        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        if tr > 0 { path.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr), radius: tr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false) }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        if br > 0 { path.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br), radius: br, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false) }
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        if bl > 0 { path.addArc(center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl), radius: bl, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false) }
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        if tl > 0 { path.addArc(center: CGPoint(x: rect.minX + tl, y: rect.minY + tl), radius: tl, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false) }
        path.closeSubpath()
        return path
    }
}

// MARK: - Messages ViewModel
@Observable
class MessagesViewModel {
    var isAutoReplyEnabled = false
    var isBriefingEnabled = true
    var isSending = false
    var sendStatus: String? = nil

    private let claudeService: ClaudeService
    private var monitor: MessageMonitor?
    private var briefingScheduler: BriefingScheduler?

    init(claudeService: ClaudeService) {
        self.claudeService = claudeService
    }

    var nyriianChips: [String] {
        ["On my way home 🏠", "Miss you 💕", "What's for dinner? 🍽", "Running late ⏰", "Can you pick up...? 🛒", "Love you 🩷"]
    }

    func sendToNyRiian(_ message: String) {
        guard let phone = KeychainManager.loadPhoneNumber() else {
            sendStatus = "No phone number set — go to Settings"
            return
        }
        isSending = true
        sendStatus = nil
        Task {
            do {
                try await MessagesService.send(message, to: phone)
                await MainActor.run {
                    isSending = false
                    sendStatus = "Sent to NyRiian ✓"
                }
                try? await Task.sleep(for: .seconds(3))
                await MainActor.run { sendStatus = nil }
            } catch {
                await MainActor.run {
                    isSending = false
                    sendStatus = "Couldn't send — is Messages signed in?"
                }
            }
        }
    }

    func sendMessage(_ message: String, to recipient: String) {
        isSending = true
        Task {
            do {
                try await MessagesService.send(message, to: recipient)
                await MainActor.run {
                    isSending = false
                    sendStatus = "Message sent ✓"
                }
            } catch {
                await MainActor.run {
                    isSending = false
                    sendStatus = "Couldn't send — is Messages signed in?"
                }
            }
        }
    }

    func toggleAutoReply(_ enabled: Bool) {
        isAutoReplyEnabled = enabled
        if enabled {
            guard let phone = KeychainManager.loadPhoneNumber() else { return }
            monitor = MessageMonitor(phoneNumber: phone, claudeService: claudeService)
            monitor?.start()
        } else {
            monitor?.stop()
            monitor = nil
        }
    }

    func toggleBriefing(_ enabled: Bool) {
        isBriefingEnabled = enabled
        if enabled {
            guard let phone = KeychainManager.loadPhoneNumber() else { return }
            briefingScheduler = BriefingScheduler(claudeService: claudeService, phoneNumber: phone)
            briefingScheduler?.start()
        } else {
            briefingScheduler?.stop()
            briefingScheduler = nil
        }
    }
}
