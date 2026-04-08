import SwiftUI

// MARK: - Chat Message Model
struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    var content: String
    var state: MessageState = .complete
    var toolCalls: [ToolCall] = []

    enum Role { case user, assistant }

    enum MessageState {
        case thinking
        case toolRunning(String)
        case toolComplete(String)
        case streaming
        case complete
    }

    struct ToolCall: Identifiable {
        let id = UUID()
        let name: String
        var isComplete: Bool = false
        var result: String? = nil

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
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.messages) { message in
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

            // Input row
            HStack(spacing: 8) {
                TextField("Ask me anything, Miss M…", text: $viewModel.inputText)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(13)
                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(Theme.Colors.roseLight, lineWidth: 1.5))
                    .onSubmit { viewModel.send() }

                Button(action: { viewModel.isListening.toggle() }) {
                    Text("🎙")
                        .frame(width: 36, height: 36)
                        .background(viewModel.isListening ? Theme.Gradients.rosePrimary : LinearGradient(colors: [Color.white.opacity(0.8)], startPoint: .top, endPoint: .bottom))
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

    var quickPrompts: [String] {
        ["📅 My calendar today", "✍️ Help my essay", "🎯 Quiz me", "🛒 Shopping list", "📧 Email draft"]
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
                    }
                }

                // Main bubble
                switch message.state {
                case .thinking:
                    ThinkingBubble()
                case .streaming, .complete:
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
                            .cornerRadius(message.role == .user ? 16 : 16)
                            .overlay(
                                Group {
                                    if message.role == .assistant {
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white.opacity(0.9), lineWidth: 1)
                                    }
                                }
                            )
                            .shadow(color: Theme.Colors.shadow, radius: 5, x: 0, y: 2)
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
            Text(tool.isComplete ? tool.displayName.replacingOccurrences(of: "…", with: "") : tool.displayName)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(tool.isComplete ? .green : Color.blue)
            Spacer()
            if tool.isComplete {
                Text("✓").font(.system(size: 11)).foregroundColor(.green)
            } else {
                ProgressView().scaleEffect(0.6)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 5)
        .background(tool.isComplete ? Color(red: 0.95, green: 1, blue: 0.96) : Color(red: 0.95, green: 0.97, blue: 1))
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(tool.isComplete ? Color.green.opacity(0.25) : Color.blue.opacity(0.2), lineWidth: 1))
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

// WellnessView moved to MissM/Features/Wellness/WellnessView.swift
// SettingsView moved to MissM/Features/Settings/SettingsView.swift
