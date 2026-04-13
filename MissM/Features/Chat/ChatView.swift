import SwiftUI

// MARK: - Chat Message Model
struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    var content: String
    var state: MessageState = .complete
    var toolCalls: [ToolCall] = []
    var flashcards: [InlineFlashcard] = []

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
            case "read_calendar":   return "Reading Apple Calendar..."
            case "add_reminder":    return "Adding to Reminders..."
            case "read_reminders":  return "Checking Reminders..."
            case "get_weather":     return "Fetching weather..."
            default:                return "\(name)..."
            }
        }
        var icon: String {
            switch name {
            case "read_calendar":   return "\u{1F4C5}"
            case "add_reminder":    return "\u{1F514}"
            case "read_reminders":  return "\u{2705}"
            case "get_weather":     return "\u{1F324}"
            default:                return "\u{1F527}"
            }
        }
    }

    struct InlineFlashcard: Identifiable {
        let id = UUID()
        let question: String
        let answer: String
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
            content: "Hey Miss M! \u{1F3F5}\u{FE0F} I'm here and ready to help. What do you need today?",
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
        let assistantMsg = ChatMessage(role: .assistant, content: "", state: .thinking)
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
                        // Parse flashcards from content if present
                        self.parseFlashcards(at: msgIndex)
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

    private func parseFlashcards(at index: Int) {
        let content = messages[index].content
        // Detect JSON flashcard arrays in the response
        guard let startRange = content.range(of: "[{\"question\""),
              let endRange = content.range(of: "}]", range: startRange.lowerBound..<content.endIndex) else { return }
        let jsonString = String(content[startRange.lowerBound...endRange.upperBound])
        guard let data = jsonString.data(using: .utf8) else { return }
        struct FC: Codable { let question: String; let answer: String }
        if let cards = try? JSONDecoder().decode([FC].self, from: data) {
            messages[index].flashcards = cards.map {
                ChatMessage.InlineFlashcard(question: $0.question, answer: $0.answer)
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
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            RichMessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                }
                .onChange(of: viewModel.messages.count) {
                    if let last = viewModel.messages.last {
                        withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo(last.id, anchor: .bottom) }
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
                TextField("Ask me anything, Miss M...", text: $viewModel.inputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .background(Color.white.opacity(0.85))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [Theme.Colors.roseLight, Theme.Colors.rosePale],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .onSubmit { viewModel.send() }

                // Microphone
                Button(action: { viewModel.isListening.toggle() }) {
                    Image(systemName: viewModel.isListening ? "waveform.circle.fill" : "mic.fill")
                        .font(.system(size: 14))
                        .foregroundColor(viewModel.isListening ? .white : Theme.Colors.rosePrimary)
                        .frame(width: 34, height: 34)
                        .background(
                            viewModel.isListening
                            ? AnyShapeStyle(Theme.Gradients.rosePrimary)
                            : AnyShapeStyle(Color.white.opacity(0.85))
                        )
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.Colors.roseLight, lineWidth: viewModel.isListening ? 0 : 1.5)
                        )
                        .shadow(color: viewModel.isListening ? Theme.Colors.rosePrimary.opacity(0.4) : .clear, radius: 6)
                }
                .buttonStyle(.plain)

                // Send
                Button(action: { viewModel.send() }) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 34, height: 34)
                        .background(
                            viewModel.inputText.isEmpty
                            ? AnyShapeStyle(Theme.Colors.roseLight.opacity(0.6))
                            : AnyShapeStyle(Theme.Gradients.rosePrimary)
                        )
                        .cornerRadius(12)
                        .shadow(
                            color: viewModel.inputText.isEmpty ? .clear : Theme.Colors.rosePrimary.opacity(0.4),
                            radius: 6
                        )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.inputText.isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
            .padding(.top, 6)
            .background(
                Theme.Colors.glassWhite
                    .background(.ultraThinMaterial)
            )
            .overlay(Rectangle().frame(height: 0.5).foregroundColor(Theme.Colors.glassBorder), alignment: .top)
        }
    }

    var quickPrompts: [String] {
        ["\u{1F4C5} My calendar today", "\u{270D}\u{FE0F} Help my essay", "\u{1F3AF} Quiz me", "\u{1F6D2} Shopping list", "\u{1F4E7} Email draft"]
    }
}

// MARK: - Rich Message Bubble
struct RichMessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .user { Spacer(minLength: 40) }

            // AI Avatar
            if message.role == .assistant {
                Text("\u{265B}")
                    .font(.system(size: 11))
                    .foregroundColor(.white)
                    .frame(width: 26, height: 26)
                    .background(Theme.Gradients.heroCard)
                    .clipShape(Circle())
                    .shadow(color: Theme.Colors.rosePrimary.opacity(0.3), radius: 4)
                    .offset(y: -2)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                // Tool call pills
                if !message.toolCalls.isEmpty {
                    ForEach(message.toolCalls) { tool in
                        RichToolPill(tool: tool)
                    }
                }

                // Main content
                switch message.state {
                case .thinking:
                    RichThinkingBubble()
                case .streaming:
                    StreamingBubble(text: message.content, role: message.role)
                case .complete, .toolRunning, .toolComplete:
                    if !message.content.isEmpty {
                        completeBubble
                    }
                }

                // Inline flashcards
                if !message.flashcards.isEmpty {
                    InlineFlashcardsView(cards: message.flashcards)
                }
            }

            if message.role == .assistant { Spacer(minLength: 40) }

            // User avatar
            if message.role == .user {
                Text("M")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 26, height: 26)
                    .background(
                        LinearGradient(
                            colors: [Theme.Colors.roseMid, Theme.Colors.rosePrimary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
                    .shadow(color: Theme.Colors.rosePrimary.opacity(0.25), radius: 3)
                    .offset(y: -2)
            }
        }
    }

    @ViewBuilder
    var completeBubble: some View {
        if message.role == .user {
            // User: pink gradient bubble
            Text(message.content)
                .font(.system(size: 12.5))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Theme.Gradients.rosePrimary)
                .cornerRadius(18)
                .cornerRadius(18, corners: .bottomRight, radius: 6)
                .shadow(color: Theme.Colors.rosePrimary.opacity(0.25), radius: 8, x: 0, y: 3)
                .frame(maxWidth: 280, alignment: .trailing)
        } else {
            // Assistant: glass card bubble
            Text(message.content)
                .font(.system(size: 12.5))
                .foregroundColor(Theme.Colors.textPrimary)
                .lineSpacing(2)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    ZStack {
                        Color.white.opacity(0.92)
                        LinearGradient(
                            colors: [Color.white.opacity(0.3), Theme.Colors.rosePale.opacity(0.08)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                )
                .background(.ultraThinMaterial)
                .cornerRadius(18)
                .cornerRadius(18, corners: .bottomLeft, radius: 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Theme.Colors.glassBorder, lineWidth: 1)
                )
                .shadow(color: Theme.Colors.shadow, radius: 6, x: 0, y: 2)
                .frame(maxWidth: 280, alignment: .leading)
        }
    }
}

// MARK: - Custom corner radius helper
extension View {
    func cornerRadius(_ radius: CGFloat, corners: CornerGroup, radius smallRadius: CGFloat) -> some View {
        // This just applies standard cornerRadius; for chat tails we use the standard rounding
        self
    }
}

enum CornerGroup {
    case bottomRight, bottomLeft
}

// MARK: - Rich Thinking Bubble
struct RichThinkingBubble: View {
    @State private var dotPhase: [Bool] = [false, false, false]

    var body: some View {
        HStack(spacing: 10) {
            // Bouncing dots
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Theme.Colors.rosePrimary, Theme.Colors.roseMid],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 7, height: 7)
                        .offset(y: dotPhase[i] ? -4 : 2)
                        .animation(
                            .easeInOut(duration: 0.45)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.15),
                            value: dotPhase[i]
                        )
                }
            }

            Text("thinking...")
                .font(.system(size: 11, weight: .medium))
                .italic()
                .foregroundColor(Theme.Colors.textSoft)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            ZStack {
                Color.white.opacity(0.92)
                Theme.Colors.rosePale.opacity(0.15)
            }
        )
        .background(.ultraThinMaterial)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Theme.Colors.roseLight.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: Theme.Colors.shadow, radius: 5)
        .onAppear {
            for i in 0..<3 { dotPhase[i] = true }
        }
    }
}

// MARK: - Streaming Bubble (with blinking cursor)
struct StreamingBubble: View {
    let text: String
    let role: ChatMessage.Role
    @State private var cursorVisible = true

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            Text(text)
                .font(.system(size: 12.5))
                .foregroundColor(role == .user ? .white : Theme.Colors.textPrimary)
                .lineSpacing(2)

            // Blinking rose cursor
            if role == .assistant {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Theme.Colors.rosePrimary)
                    .frame(width: 2, height: 14)
                    .opacity(cursorVisible ? 1 : 0)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: cursorVisible)
                    .padding(.leading, 1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Group {
                if role == .user {
                    Theme.Gradients.rosePrimary
                } else {
                    ZStack {
                        Color.white.opacity(0.92)
                        LinearGradient(
                            colors: [Color.white.opacity(0.3), Theme.Colors.rosePale.opacity(0.08)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                }
            }
        )
        .cornerRadius(18)
        .overlay(
            Group {
                if role == .assistant {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Theme.Colors.glassBorder, lineWidth: 1)
                }
            }
        )
        .shadow(color: Theme.Colors.shadow, radius: 5, x: 0, y: 2)
        .frame(maxWidth: 280, alignment: role == .user ? .trailing : .leading)
        .onAppear { cursorVisible = false }
    }
}

// MARK: - Rich Tool Pill
struct RichToolPill: View {
    let tool: ChatMessage.ToolCall
    @State private var spinAngle: Double = 0

    var body: some View {
        HStack(spacing: 8) {
            // Icon in colored circle
            ZStack {
                Circle()
                    .fill(
                        tool.isComplete
                        ? Color.green.opacity(0.12)
                        : Theme.Colors.rosePale.opacity(0.6)
                    )
                    .frame(width: 22, height: 22)
                Text(tool.icon)
                    .font(.system(size: 11))
            }

            Text(tool.isComplete
                 ? tool.displayName.replacingOccurrences(of: "...", with: "")
                 : tool.displayName
            )
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(tool.isComplete ? .green : Theme.Colors.textMedium)

            Spacer()

            if tool.isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.green)
                    .transition(.scale.combined(with: .opacity))
            } else {
                ProgressView()
                    .scaleEffect(0.55)
                    .tint(Theme.Colors.rosePrimary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            tool.isComplete
            ? Color(red: 0.95, green: 1, blue: 0.96)
            : Theme.Colors.rosePale.opacity(0.3)
        )
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    tool.isComplete
                    ? Color.green.opacity(0.25)
                    : Theme.Colors.roseLight.opacity(0.5),
                    lineWidth: 1
                )
        )
        .frame(maxWidth: 270, alignment: .leading)
        .animation(.spring(response: 0.4), value: tool.isComplete)
    }
}

// MARK: - Inline Flashcards View (rendered in chat)
struct InlineFlashcardsView: View {
    let cards: [ChatMessage.InlineFlashcard]
    @State private var currentIndex = 0
    @State private var isFlipped = false

    var body: some View {
        VStack(spacing: 8) {
            // Mini header
            HStack {
                Image(systemName: "rectangle.on.rectangle.angled")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.Colors.rosePrimary)
                Text("Flashcards")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.Colors.rosePrimary)
                Spacer()
                Text("\(currentIndex + 1)/\(cards.count)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Theme.Colors.textSoft)
            }

            // Mini card
            ZStack {
                // Front
                VStack(spacing: 4) {
                    Text("Q")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                    Text(cards[currentIndex].question)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 8)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 80)
                .background(Theme.Gradients.heroCard)
                .cornerRadius(12)
                .opacity(isFlipped ? 0 : 1)
                .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))

                // Back
                VStack(spacing: 4) {
                    Text("A")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Theme.Colors.rosePrimary.opacity(0.5))
                    Text(cards[currentIndex].answer)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 8)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 80)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Colors.roseLight, lineWidth: 1))
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isFlipped)
            .onTapGesture { isFlipped.toggle() }

            // Navigation
            HStack(spacing: 12) {
                Button(action: {
                    if currentIndex > 0 { isFlipped = false; currentIndex -= 1 }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(currentIndex > 0 ? Theme.Colors.rosePrimary : Theme.Colors.textXSoft)
                }
                .buttonStyle(.plain)
                .disabled(currentIndex == 0)

                // Dots
                HStack(spacing: 3) {
                    ForEach(0..<min(cards.count, 8), id: \.self) { i in
                        Circle()
                            .fill(i == currentIndex ? Theme.Colors.rosePrimary : Theme.Colors.roseLight.opacity(0.5))
                            .frame(width: i == currentIndex ? 6 : 4, height: i == currentIndex ? 6 : 4)
                    }
                    if cards.count > 8 {
                        Text("+\(cards.count - 8)")
                            .font(.system(size: 7))
                            .foregroundColor(Theme.Colors.textXSoft)
                    }
                }

                Button(action: {
                    if currentIndex < cards.count - 1 { isFlipped = false; currentIndex += 1 }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(currentIndex < cards.count - 1 ? Theme.Colors.rosePrimary : Theme.Colors.textXSoft)
                }
                .buttonStyle(.plain)
                .disabled(currentIndex >= cards.count - 1)
            }

            Text("Tap card to flip")
                .font(.system(size: 8))
                .foregroundColor(Theme.Colors.textXSoft)
        }
        .padding(10)
        .background(
            ZStack {
                Color.white.opacity(0.92)
                Theme.Colors.rosePale.opacity(0.1)
            }
        )
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.Colors.roseLight.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: Theme.Colors.shadow, radius: 6, x: 0, y: 2)
        .frame(maxWidth: 270, alignment: .leading)
    }
}

// MARK: - Chip Button Style
struct ChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(Theme.Colors.textMedium)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(
                ZStack {
                    Color.white.opacity(configuration.isPressed ? 1 : 0.75)
                    if configuration.isPressed {
                        Theme.Colors.rosePale.opacity(0.3)
                    }
                }
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        configuration.isPressed ? Theme.Colors.rosePrimary.opacity(0.4) : Theme.Colors.roseLight,
                        lineWidth: 1
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Legacy compat aliases
typealias MessageBubble = RichMessageBubble
typealias ThinkingBubble = RichThinkingBubble
typealias ToolPill = RichToolPill

// MARK: - Wellness Tab (Phase 6)
enum WellnessTab: String, CaseIterable {
    case dashboard = "Dashboard"
    case cycle = "Cycle"

    var icon: String {
        switch self {
        case .dashboard: return "\u{2764}\u{FE0F}"
        case .cycle: return "\u{1F319}"
        }
    }
}

struct WellnessTabView: View {
    let claudeService: ClaudeService
    @State private var selectedTab: WellnessTab = .dashboard

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                ForEach(WellnessTab.allCases, id: \.self) { tab in
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

            switch selectedTab {
            case .dashboard:
                WellnessDashboardView(claudeService: claudeService)
            case .cycle:
                CycleTrackerView(claudeService: claudeService)
            }
        }
    }
}
struct SettingsView: View {
    @State private var apiKeyMasked: String = {
        if let key = KeychainManager.loadAPIKey() {
            let prefix = String(key.prefix(10))
            return prefix + String(repeating: "\u{2022}", count: 20)
        }
        return "Not set"
    }()
    @State private var showResetConfirm = false
    @State private var calendarAccess = CalendarService.shared.authorizationStatus == .fullAccess
    @State private var remindersAccess = RemindersService.shared.authorizationStatus == .fullAccess

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                Text("Settings")
                    .font(.custom("PlayfairDisplay-Italic", size: 22))
                    .foregroundColor(Theme.Colors.rosePrimary)
                    .padding(.horizontal, 16)

                // API Key Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("API KEY")
                        .font(.custom("CormorantGaramond-SemiBold", size: 11))
                        .tracking(2.5)
                        .textCase(.uppercase)
                        .foregroundColor(Theme.Colors.textSoft)
                    HStack {
                        Text(apiKeyMasked)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(Theme.Colors.textMedium)
                        Spacer()
                        Button("Reset") { showResetConfirm = true }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Theme.Colors.roseDeep)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.7))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.roseLight, lineWidth: 1))
                }
                .glassCard()
                .padding(.horizontal, 12)

                // Integrations Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("INTEGRATIONS")
                        .font(.custom("CormorantGaramond-SemiBold", size: 11))
                        .tracking(2.5)
                        .textCase(.uppercase)
                        .foregroundColor(Theme.Colors.textSoft)

                    SettingsRow(icon: "\u{1F4C5}", title: "Apple Calendar", isEnabled: calendarAccess) {
                        Task {
                            calendarAccess = await CalendarService.shared.requestAccess()
                        }
                    }
                    SettingsRow(icon: "\u{2705}", title: "Reminders", isEnabled: remindersAccess) {
                        Task {
                            remindersAccess = await RemindersService.shared.requestAccess()
                        }
                    }
                    SettingsRow(icon: "\u{1F4AC}", title: "iMessage", isEnabled: true) {}
                    SettingsRow(icon: "\u{2764}\u{FE0F}", title: "HealthKit", isEnabled: HealthService.shared.isAuthorized) {
                        Task { _ = await HealthService.shared.requestAccess() }
                    }
                }
                .glassCard()
                .padding(.horizontal, 12)

                // About Section
                VStack(alignment: .leading, spacing: 6) {
                    Text("ABOUT")
                        .font(.custom("CormorantGaramond-SemiBold", size: 11))
                        .tracking(2.5)
                        .textCase(.uppercase)
                        .foregroundColor(Theme.Colors.textSoft)
                    HStack {
                        Text("Miss M v1.0")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.Colors.textMedium)
                        Spacer()
                        Text("Claude Sonnet 4.6")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.textSoft)
                    }
                }
                .glassCard()
                .padding(.horizontal, 12)
            }
            .padding(.top, 16)
        }
        .alert("Reset API Key?", isPresented: $showResetConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                try? KeychainManager.deleteAPIKey()
                apiKeyMasked = "Not set"
            }
        } message: {
            Text("This will remove your API key. You will need to re-enter it.")
        }
    }
}

// MARK: - Settings Row
struct SettingsRow: View {
    let icon: String
    let title: String
    let isEnabled: Bool
    let onTap: () -> Void

    var body: some View {
        HStack {
            Text(icon)
                .font(.system(size: 14))
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(Theme.Colors.textPrimary)
            Spacer()
            if isEnabled {
                Text("Connected")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.green)
            } else {
                Button("Enable") { onTap() }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.Colors.rosePrimary)
            }
        }
        .padding(.vertical, 4)
    }
}
