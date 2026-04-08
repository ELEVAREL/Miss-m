import SwiftUI

// MARK: - Chat Message Model
struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    var content: String
    var state: MessageState = .complete
    var toolCalls: [ToolCall] = []
    let timestamp: Date

    init(role: Role, content: String, state: MessageState = .complete, toolCalls: [ToolCall] = []) {
        self.role = role
        self.content = content
        self.state = state
        self.toolCalls = toolCalls
        self.timestamp = Date()
    }

    enum Role { case user, assistant }

    enum MessageState {
        case thinking
        case toolRunning(String)
        case toolComplete(String)
        case streaming
        case complete
    }

    var timestampString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: timestamp)
    }

    struct ToolCall: Identifiable {
        let id = UUID()
        let name: String
        var isComplete: Bool = false
        var result: String? = nil
        var resultItems: [RichCardItem] = []

        var displayName: String {
            switch name {
            case "read_calendar":   return "Reading Apple Calendar…"
            case "add_reminder":    return "Adding to Reminders…"
            case "send_imessage":   return "Sending iMessage…"
            case "read_reminders":  return "Checking Reminders…"
            case "get_weather":     return "Fetching weather…"
            default:                return "\(name)…"
            }
        }
        var completeName: String {
            switch name {
            case "read_calendar":   return "Read calendar events"
            case "add_reminder":    return "Reminder added"
            case "send_imessage":   return "iMessage sent"
            case "read_reminders":  return "Checked reminders"
            case "get_weather":     return "Weather fetched"
            default:                return name
            }
        }
        var icon: String {
            switch name {
            case "read_calendar":   return "📅"
            case "add_reminder":    return "🔔"
            case "send_imessage":   return "💬"
            case "read_reminders":  return "✅"
            case "get_weather":     return "🌤"
            default:                return "🔧"
            }
        }
        var richCardTitle: String? {
            switch name {
            case "read_calendar":   return "📅 Today's Events"
            case "read_reminders":  return "✅ Reminders"
            default:                return nil
            }
        }
    }

    struct RichCardItem: Identifiable {
        let id = UUID()
        let title: String
        let detail: String
        let dotColor: String // hex
    }
}

// MARK: - Chat ViewModel
@Observable
class ChatViewModel {
    var messages: [ChatMessage] = []
    var inputText = ""
    var isListening = false
    var isProcessing = false

    private let claudeService: ClaudeService

    init(claudeService: ClaudeService) {
        self.claudeService = claudeService
        // Welcome message
        messages.append(ChatMessage(
            role: .assistant,
            content: "Hey Miss M! 🩷 I'm here and ready to help. What do you need today?",
            state: .complete
        ))
    }

    func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        sendMessage(text)
    }

    func sendMessage(_ text: String) {
        // Add user message
        messages.append(ChatMessage(role: .user, content: text, state: .complete))

        // Add thinking placeholder
        var assistantMsg = ChatMessage(role: .assistant, content: "", state: .thinking)
        messages.append(assistantMsg)
        let msgIndex = messages.count - 1

        isProcessing = true

        Task { @MainActor in
            // Build history for API
            let history = messages.dropLast().map {
                ClaudeMessage(role: $0.role == .user ? "user" : "assistant", content: $0.content)
            }

            await claudeService.streamChat(messages: Array(history)) { [weak self] event in
                guard let self else { return }
                Task { @MainActor in
                    switch event.type {
                    case .contentDelta(let text):
                        self.messages[msgIndex].content += text
                        self.messages[msgIndex].state = .streaming
                    case .toolUse(let name):
                        let tool = ChatMessage.ToolCall(name: name)
                        self.messages[msgIndex].toolCalls.append(tool)
                        self.messages[msgIndex].state = .toolRunning(name)
                    case .done:
                        self.messages[msgIndex].state = .complete
                        self.isProcessing = false
                    case .error(let err):
                        self.messages[msgIndex].content = "Sorry Miss M, something went wrong: \(err)"
                        self.messages[msgIndex].state = .complete
                        self.isProcessing = false
                    default:
                        break
                    }
                }
            }
        }
    }
}

// MARK: - Chat Header (per design: gradient bar with avatar, title, status, actions)
struct ChatHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            // AI avatar
            Text("✦")
                .font(.system(size: 15))
                .foregroundColor(.white)
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.2))
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 2))

            VStack(alignment: .leading, spacing: 1) {
                Text("Miss M AI")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 5, height: 5)
                    Text("Active · Sonnet 4.6")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.75))
                }
            }

            Spacer()

            // Action buttons
            HStack(spacing: 7) {
                ChatHeaderButton(icon: "🎙")
                ChatHeaderButton(icon: "📎")
                ChatHeaderButton(icon: "⋯")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [Theme.Colors.rosePrimary, Theme.Colors.roseDeep],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

struct ChatHeaderButton: View {
    let icon: String
    @State private var isHovered = false

    var body: some View {
        Text(icon)
            .font(.system(size: 14))
            .frame(width: 30, height: 30)
            .background(isHovered ? Color.white.opacity(0.28) : Color.white.opacity(0.15))
            .cornerRadius(9)
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.white.opacity(0.22), lineWidth: 1))
            .onHover { isHovered = $0 }
    }
}

// MARK: - Chat View
struct ChatView: View {
    let claudeService: ClaudeService
    @State private var viewModel: ChatViewModel
    @State private var scrollProxy: ScrollViewProxy? = nil

    init(claudeService: ClaudeService) {
        self.claudeService = claudeService
        self._viewModel = State(initialValue: ChatViewModel(claudeService: claudeService))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            ChatHeader()

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                            // Show timestamp before first message or when gap > 5 min
                            if index == 0 || shouldShowTimestamp(at: index) {
                                Text(timestampLabel(for: message))
                                    .font(.system(size: 9))
                                    .foregroundColor(Theme.Colors.textXSoft)
                                    .tracking(0.5)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 6)
                            }
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(14)
                }
                .onChange(of: viewModel.messages.count) {
                    if let last = viewModel.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            // Quick chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(quickPrompts, id: \.self) { prompt in
                        Button(prompt) { viewModel.sendMessage(prompt) }
                            .buttonStyle(ChipButtonStyle())
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }

            // Input row or voice waveform
            if viewModel.isListening {
                // Voice input mode (State 7 per design)
                VoiceInputRow(isListening: $viewModel.isListening) { transcript in
                    viewModel.inputText = transcript
                }
            } else {
                HStack(spacing: 8) {
                    TextField("Ask me anything, Miss M…", text: $viewModel.inputText)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(13)
                        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Theme.Colors.roseLight, lineWidth: 1.5))
                        .onSubmit { viewModel.send() }

                    Button(action: { viewModel.isListening = true }) {
                        Text("🎙")
                            .frame(width: 36, height: 36)
                            .background(LinearGradient(colors: [Color.white.opacity(0.8)], startPoint: .top, endPoint: .bottom))
                            .cornerRadius(11)
                            .overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.Colors.roseLight, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)

                    Button(action: { viewModel.send() }) {
                        Text("↑")
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Theme.Gradients.rosePrimary)
                            .cornerRadius(11)
                            .shadow(color: Theme.Colors.rosePrimary.opacity(0.35), radius: 6)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.inputText.isEmpty)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
                .padding(.top, 6)
                .background(Color.white.opacity(0.5))
                .overlay(Rectangle().frame(height: 1).foregroundColor(Theme.Colors.glassBorder), alignment: .top)
            }
        }
    }

    var quickPrompts: [String] {
        ["📅 My calendar today", "✍️ Help my essay", "🎯 Quiz me", "🛒 Shopping list"]
    }

    private func shouldShowTimestamp(at index: Int) -> Bool {
        guard index > 0 else { return true }
        let prev = viewModel.messages[index - 1].timestamp
        let curr = viewModel.messages[index].timestamp
        return curr.timeIntervalSince(prev) > 300 // 5 min gap
    }

    private func timestampLabel(for message: ChatMessage) -> String {
        let cal = Calendar.current
        let now = Date()
        if cal.isDateInToday(message.timestamp) {
            return "Today · \(message.timestampString)"
        } else if cal.isDateInYesterday(message.timestamp) {
            return "Yesterday · \(message.timestampString)"
        } else {
            let df = DateFormatter()
            df.dateFormat = "MMM d · h:mm a"
            return df.string(from: message.timestamp)
        }
    }
}

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 7) {
            if message.role == .user { Spacer() }

            if message.role == .assistant {
                // AI avatar
                Text("✦")
                    .font(.system(size: 10))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(Theme.Gradients.rosePrimary)
                    .clipShape(Circle())
                    .offset(y: -2)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 5) {
                // Tool calls
                if !message.toolCalls.isEmpty {
                    ForEach(message.toolCalls) { tool in
                        ToolPill(tool: tool)
                        // Rich card after tool completes with items
                        if tool.isComplete, let cardTitle = tool.richCardTitle, !tool.resultItems.isEmpty {
                            RichCard(title: cardTitle, items: tool.resultItems)
                        }
                    }
                }

                // Main bubble
                switch message.state {
                case .thinking:
                    ThinkingBubble()
                case .streaming:
                    if !message.content.isEmpty {
                        HStack(spacing: 0) {
                            Text(message.content)
                                .font(.system(size: 12.5))
                                .foregroundColor(Theme.Colors.textPrimary)
                            // Blinking rose cursor
                            StreamingCursor()
                        }
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .background(Color.white.opacity(0.92))
                        .clipShape(BubbleShape(isUser: false))
                        .overlay(BubbleShape(isUser: false).stroke(Color.white.opacity(0.9), lineWidth: 1))
                        .shadow(color: Color(hex: "#C2185B").opacity(0.07), radius: 5, x: 0, y: 2)
                        .frame(maxWidth: 280, alignment: .leading)
                    }
                case .complete:
                    if !message.content.isEmpty {
                        Text(message.content)
                            .font(.system(size: 12.5))
                            .foregroundColor(message.role == .user ? .white : Theme.Colors.textPrimary)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 9)
                            .background(
                                message.role == .user
                                ? AnyView(Theme.Gradients.rosePrimary)
                                : AnyView(Color.white.opacity(0.92))
                            )
                            .clipShape(BubbleShape(isUser: message.role == .user))
                            .overlay(
                                Group {
                                    if message.role == .assistant {
                                        BubbleShape(isUser: false)
                                            .stroke(Color.white.opacity(0.9), lineWidth: 1)
                                    }
                                }
                            )
                            .shadow(color: Color(hex: "#C2185B").opacity(0.07), radius: 5, x: 0, y: 2)
                            .frame(maxWidth: 280, alignment: message.role == .user ? .trailing : .leading)
                    }
                default:
                    EmptyView()
                }
            }

            if message.role == .assistant { Spacer() }

            if message.role == .user {
                // User avatar
                Text("M")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(LinearGradient(colors: [Theme.Colors.roseLight, Theme.Colors.rosePrimary], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(Circle())
                    .offset(y: -2)
            }
        }
    }
}

// MARK: - Rich Card (per design: embedded result card after tool completion)
struct RichCard: View {
    let title: String
    let items: [ChatMessage.RichCardItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundColor(Theme.Colors.rosePrimary)
            }
            .padding(.bottom, 8)

            // Rows
            ForEach(items) { item in
                HStack(spacing: 7) {
                    Circle()
                        .fill(Color(hex: item.dotColor))
                        .frame(width: 7, height: 7)
                    Text(item.title)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text(item.detail)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Theme.Colors.rosePrimary)
                }
                .padding(.vertical, 6)
                if item.id != items.last?.id {
                    Divider()
                        .background(Theme.Colors.rosePrimary.opacity(0.05))
                }
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(Color.white)
        .cornerRadius(13)
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Theme.Colors.rosePrimary.opacity(0.12), lineWidth: 1))
        .shadow(color: Color(hex: "#C2185B").opacity(0.06), radius: 4, x: 0, y: 2)
        .frame(maxWidth: 260, alignment: .leading)
    }
}

// MARK: - Voice Input Row (per design: pulsing mic, waveform, timer)
// Now wired to SFSpeechRecognizer (Phase 7)
struct VoiceInputRow: View {
    @Binding var isListening: Bool
    var onTranscript: ((String) -> Void)? = nil
    @State private var seconds = 0
    @State private var timer: Timer? = nil
    @State private var voiceService = VoiceInputService.shared

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                // Pulsing mic icon
                VoiceMicButton()

                VoiceWaveform()

                if voiceService.transcribedText.isEmpty {
                    Text("Listening to Miss M…")
                        .font(.system(size: 11))
                        .italic()
                        .foregroundColor(Theme.Colors.textSoft)
                } else {
                    Text(voiceService.transcribedText)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(2)
                }

                Spacer()

                // Timer
                Text(timerString)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.Colors.rosePrimary)

                Button(action: { stopListening() }) {
                    Text("Done")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Theme.Gradients.rosePrimary)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(Color.white.opacity(0.85))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.Colors.roseLight, lineWidth: 1))
        .cornerRadius(18)
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
        .padding(.top, 6)
        .onAppear { startListening() }
        .onDisappear { timer?.invalidate(); voiceService.stopListening() }
    }

    private var timerString: String {
        let m = seconds / 60
        let s = seconds % 60
        return "\(m):\(String(format: "%02d", s))"
    }

    private func startListening() {
        seconds = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            seconds += 1
        }

        Task {
            await voiceService.requestAuthorization()
            if voiceService.isAuthorized {
                try? voiceService.startListening()
            }
        }
    }

    private func stopListening() {
        timer?.invalidate()
        voiceService.stopListening()

        // Pass transcript to chat input
        let text = voiceService.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            onTranscript?(text)
        }

        isListening = false
    }
}

struct VoiceMicButton: View {
    @State private var pulsing = false

    var body: some View {
        Text("🎙")
            .font(.system(size: 14))
            .frame(width: 32, height: 32)
            .background(
                LinearGradient(colors: [Theme.Colors.rosePrimary, Theme.Colors.roseDeep],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(Circle())
            .shadow(color: Theme.Colors.rosePrimary.opacity(pulsing ? 0.4 : 0), radius: pulsing ? 10 : 0)
            .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulsing)
            .onAppear { pulsing = true }
    }
}

// MARK: - Thinking Bubble
struct ThinkingBubble: View {
    @State private var phase = 0.0

    var body: some View {
        HStack(spacing: 9) {
            Text("🧠")
                .font(.system(size: 13))
                .rotationEffect(.degrees(phase))
                .animation(.linear(duration: 2.5).repeatForever(autoreverses: false), value: phase)
                .onAppear { phase = 360 }
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Theme.Colors.roseMid)
                        .frame(width: 5, height: 5)
                        .scaleEffect(phase > Double(i * 120) ? 1 : 0.5)
                        .animation(.easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.15), value: phase)
                }
            }
            Text("Miss M AI is thinking…")
                .font(.system(size: 11))
                .italic()
                .foregroundColor(Theme.Colors.textSoft)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.9))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.Colors.roseLight.opacity(0.6), lineWidth: 1))
        .shadow(color: Theme.Colors.shadow, radius: 5)
    }
}

// MARK: - Tool Pill
struct ToolPill: View {
    let tool: ChatMessage.ToolCall

    var body: some View {
        HStack(spacing: 7) {
            Text(tool.icon)
                .font(.system(size: 10))
                .frame(width: 20, height: 20)
                .background(tool.isComplete ? Color.green.opacity(0.12) : Color.blue.opacity(0.1))
                .clipShape(Circle())
            Text(tool.isComplete ? tool.completeName : tool.displayName)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(tool.isComplete ? Color(red: 0.18, green: 0.49, blue: 0.20) : Color.blue)
            Spacer()
            if tool.isComplete {
                Text("✓")
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0.20, green: 0.78, blue: 0.35))
            } else {
                ProgressView().scaleEffect(0.6)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 5)
        .background(tool.isComplete ? Color(red: 0.95, green: 1, blue: 0.96).opacity(0.95) : Color(red: 0.95, green: 0.97, blue: 1))
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(tool.isComplete ? Color.green.opacity(0.25) : Color.blue.opacity(0.22), lineWidth: 1))
        .shadow(color: (tool.isComplete ? Color.green : Color.blue).opacity(0.07), radius: 4, x: 0, y: 2)
        .frame(maxWidth: 260, alignment: .leading)
    }
}

// MARK: - Chip Button Style
struct ChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(Theme.Colors.textMedium)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.white.opacity(configuration.isPressed ? 1 : 0.75))
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.Colors.roseLight, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

// MARK: - Streaming Cursor (blinking rose bar)
struct StreamingCursor: View {
    @State private var visible = true

    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Theme.Colors.rosePrimary)
            .frame(width: 2, height: 14)
            .opacity(visible ? 1 : 0)
            .animation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true), value: visible)
            .onAppear { visible = false }
    }
}

// MARK: - Asymmetric Bubble Shape (per design: 16/16/16/4 corners)
struct BubbleShape: Shape {
    let isUser: Bool

    func path(in rect: CGRect) -> Path {
        let tl: CGFloat = 16
        let tr: CGFloat = 16
        let bl: CGFloat = isUser ? 16 : 4
        let br: CGFloat = isUser ? 4 : 16

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr), radius: tr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        path.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br), radius: br, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl), radius: bl, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        path.addArc(center: CGPoint(x: rect.minX + tl, y: rect.minY + tl), radius: tl, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }
}

// MARK: - Voice Waveform (7-bar animated, per design)
struct VoiceWaveform: View {
    @State private var animating = false
    let barCount = 7

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.Gradients.rosePrimary)
                    .frame(width: 3, height: animating ? CGFloat.random(in: 8...24) : 6)
                    .animation(
                        .easeInOut(duration: 0.4)
                        .repeatForever(autoreverses: true)
                        .delay(Double(i) * 0.1),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
    }
}

// WellnessView moved to MissM/Features/Wellness/WellnessView.swift
// SettingsView moved to MissM/Features/Settings/SettingsView.swift
