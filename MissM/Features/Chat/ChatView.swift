import SwiftUI
import Speech

// MARK: - Chat Message Model
struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    var content: String
    var state: MessageState = .complete
    var toolCalls: [ToolCall] = []
    var flashcards: [InlineFlashcard] = []

    enum Role { case user, assistant }

    var isComplete: Bool {
        if case .complete = state { return true }
        return false
    }

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
            case "web_search":      return "Searching the web..."
            case "read_health":     return "Reading health data..."
            case "check_cycle":     return "Checking cycle phase..."
            case "check_preferences": return "Checking food preferences..."
            default:                return "\(name)..."
            }
        }
        var icon: String {
            switch name {
            case "read_calendar":   return "\u{1F4C5}"
            case "add_reminder":    return "\u{1F514}"
            case "read_reminders":  return "\u{2705}"
            case "get_weather":     return "\u{1F324}"
            case "web_search":      return "\u{1F310}"
            case "read_health":     return "\u{2764}\u{FE0F}"
            case "check_cycle":     return "\u{1F319}"
            case "check_preferences": return "\u{1F37D}\u{FE0F}"
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

            // Gather live context so Claude has real data
            var context = await gatherLiveContext()
            var contextualPrompt = ClaudeService.buildContextualPrompt(context: context)

            let userText = text.lowercased()

            // Smart action detection — show what Miss M is doing
            let workoutTriggers = ["workout", "exercise", "fitness", "gym", "training"]
            let mealTriggers = ["meal", "food", "recipe", "dinner", "lunch", "breakfast", "cook"]
            let planTriggers = ["plan my", "schedule", "plan for", "weekly plan", "organize"]
            let studyTriggers = ["study", "flashcard", "quiz", "essay", "assignment"]

            if workoutTriggers.contains(where: { userText.contains($0) }) {
                self.messages[msgIndex].toolCalls.append(ChatMessage.ToolCall(name: "read_health"))
                self.messages[msgIndex].toolCalls.append(ChatMessage.ToolCall(name: "check_cycle"))
                self.messages[msgIndex].toolCalls.append(ChatMessage.ToolCall(name: "read_calendar"))
                self.messages[msgIndex].state = .toolRunning("read_health")
                // Animate tool completion
                try? await Task.sleep(for: .milliseconds(400))
                self.markToolComplete(at: msgIndex, name: "read_health")
                try? await Task.sleep(for: .milliseconds(300))
                self.markToolComplete(at: msgIndex, name: "check_cycle")
                try? await Task.sleep(for: .milliseconds(300))
                self.markToolComplete(at: msgIndex, name: "read_calendar")
                self.messages[msgIndex].state = .thinking
                NotificationManager.shared.info("Building your workout", message: "Checking your \(context.cyclePhase) phase and schedule...", icon: "\u{1F4AA}")
            } else if mealTriggers.contains(where: { userText.contains($0) }) {
                self.messages[msgIndex].toolCalls.append(ChatMessage.ToolCall(name: "check_preferences"))
                self.messages[msgIndex].toolCalls.append(ChatMessage.ToolCall(name: "check_cycle"))
                self.messages[msgIndex].state = .toolRunning("check_preferences")
                try? await Task.sleep(for: .milliseconds(400))
                self.markToolComplete(at: msgIndex, name: "check_preferences")
                try? await Task.sleep(for: .milliseconds(300))
                self.markToolComplete(at: msgIndex, name: "check_cycle")
                self.messages[msgIndex].state = .thinking
                NotificationManager.shared.info("Planning your meals", message: "Checking your preferences and cycle phase...", icon: "\u{1F35D}")
            } else if planTriggers.contains(where: { userText.contains($0) }) {
                self.messages[msgIndex].toolCalls.append(ChatMessage.ToolCall(name: "read_calendar"))
                self.messages[msgIndex].toolCalls.append(ChatMessage.ToolCall(name: "read_reminders"))
                self.messages[msgIndex].toolCalls.append(ChatMessage.ToolCall(name: "check_cycle"))
                self.messages[msgIndex].toolCalls.append(ChatMessage.ToolCall(name: "read_health"))
                self.messages[msgIndex].state = .toolRunning("read_calendar")
                for name in ["read_calendar", "read_reminders", "check_cycle", "read_health"] {
                    try? await Task.sleep(for: .milliseconds(300))
                    self.markToolComplete(at: msgIndex, name: name)
                }
                self.messages[msgIndex].state = .thinking
                NotificationManager.shared.info("Creating your smart plan", message: "Weaving schedule, meals, fitness, and cycle data...", icon: "\u{1F9E0}")
            }

            // Check if web search would help
            let searchTriggers = ["search", "look up", "find", "what is", "latest", "news", "how to", "recipe", "recommend", "best way", "research", "tell me about"]
            if searchTriggers.contains(where: { userText.contains($0) }) {
                // Add search tool pill
                self.messages[msgIndex].toolCalls.append(ChatMessage.ToolCall(name: "web_search"))
                self.messages[msgIndex].state = .toolRunning("web_search")

                let searchResults = await WebSearchService.shared.search(text)
                // Mark tool complete
                if let toolIndex = self.messages[msgIndex].toolCalls.firstIndex(where: { $0.name == "web_search" }) {
                    self.messages[msgIndex].toolCalls[toolIndex].isComplete = true
                    self.messages[msgIndex].toolCalls[toolIndex].result = "Found results"
                }
                self.messages[msgIndex].state = .thinking

                contextualPrompt += "\n\nWEB SEARCH RESULTS for \"\(text)\":\n\(searchResults)\n\nUse these results to answer her question. Summarize clearly, no asterisks."
            }

            await claudeService.streamChat(messages: Array(history), systemOverride: contextualPrompt) { [weak self] event in
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
                        // Notify completion for actionable requests
                        let content = self.messages[msgIndex].content.lowercased()
                        if content.contains("workout") || content.contains("exercise") {
                            NotificationManager.shared.success("Workout Ready", message: "Your personalized plan is ready!", icon: "\u{1F4AA}")
                        } else if content.contains("meal") || content.contains("recipe") {
                            NotificationManager.shared.success("Meal Plan Ready", message: "Your meals are planned!", icon: "\u{1F35D}")
                        }
                        // Auto-speak response if enabled
                        if ElevenLabsService.shared.autoSpeak {
                            ElevenLabsService.shared.speak(self.messages[msgIndex].content)
                        }
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

    private func markToolComplete(at msgIndex: Int, name: String) {
        if let i = messages[msgIndex].toolCalls.firstIndex(where: { $0.name == name && !$0.isComplete }) {
            messages[msgIndex].toolCalls[i].isComplete = true
        }
    }

    private func gatherLiveContext() async -> ClaudeService.LiveContext {
        var ctx = ClaudeService.LiveContext()

        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d yyyy"
        ctx.dateString = formatter.string(from: Date())

        // Cycle data
        let cycleData = await DataStore.shared.loadOrDefault(CycleData.self, from: "cycle.json", default: CycleData())
        ctx.cycleDay = cycleData.currentDay
        ctx.cycleLength = cycleData.cycleLength
        for phase in CyclePhase.allCases where phase.typicalDays.contains(cycleData.currentDay) {
            ctx.cyclePhase = phase.rawValue
            break
        }

        // Calendar & Reminders
        ctx.calendarSummary = await CalendarService.shared.todaySummary()
        ctx.remindersSummary = await RemindersService.shared.todaySummary()

        // HealthKit
        let health = HealthService.shared
        ctx.sleepHours = await health.sleepHoursLastNight()
        ctx.steps = await health.stepsToday()
        ctx.heartRate = await health.latestHeartRate()

        // Energy estimate based on sleep + cycle
        if ctx.sleepHours < 6 {
            ctx.energyLevel = "Low (poor sleep)"
        } else if ctx.cyclePhase == "Menstrual" {
            ctx.energyLevel = "Low-moderate (menstrual phase)"
        } else if ctx.cyclePhase == "Ovulation" {
            ctx.energyLevel = "High (ovulation peak)"
        } else if ctx.cyclePhase == "Follicular" {
            ctx.energyLevel = "Rising (follicular phase)"
        } else {
            ctx.energyLevel = "Moderate (luteal phase)"
        }

        // Food dislikes
        let foodPrefs = await DataStore.shared.loadOrDefault(FoodPreferences.self, from: "food-prefs.json", default: FoodPreferences())
        let allDislikes = foodPrefs.dislikedFoods + foodPrefs.allergies
        ctx.foodDislikes = allDislikes.isEmpty ? "None" : allDislikes.joined(separator: ", ")

        return ctx
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
    @State private var showVoiceMode = false
    @State private var triggerService = TriggerWordService.shared

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
                        ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                            RichMessageBubble(message: message)
                                .id(message.id)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .opacity
                                ))
                                .animation(Theme.Animations.springBounce, value: viewModel.messages.count)
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

                // Voice Mode
                Button(action: { showVoiceMode = true }) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.Colors.rosePrimary)
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.85))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.Colors.roseLight, lineWidth: 1.5)
                        )
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
        .sheet(isPresented: $showVoiceMode) {
            VoiceModeView(claudeService: claudeService, isPresented: $showVoiceMode)
                .frame(minWidth: 420, minHeight: 550)
        }
        .onAppear {
            // Wire trigger word to open voice mode
            triggerService.onTrigger = { [self] in
                showVoiceMode = true
            }
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

                // Voice playback button for assistant messages
                if message.role == .assistant && message.isComplete && !message.content.isEmpty {
                    Button(action: {
                        if ElevenLabsService.shared.isSpeaking {
                            ElevenLabsService.shared.stop()
                        } else {
                            ElevenLabsService.shared.speak(message.content)
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: ElevenLabsService.shared.isSpeaking ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.system(size: 8))
                            Text(ElevenLabsService.shared.isSpeaking ? "Stop" : "Listen")
                                .font(.system(size: 8, weight: .medium))
                        }
                        .foregroundColor(Theme.Colors.rosePrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.Colors.rosePale.opacity(0.5))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
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

    // Strip markdown asterisks/underscores from text
    var cleanContent: String {
        message.content
            .replacingOccurrences(of: "***", with: "")
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .replacingOccurrences(of: #"(?<!\w)\*(?!\s)"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?<!\s)\*(?!\w)"#, with: "", options: .regularExpression)
    }

    @ViewBuilder
    var completeBubble: some View {
        if message.role == .user {
            // User: pink gradient bubble
            Text(cleanContent)
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
            // Assistant: rich content bubble
            RichContentBubble(content: cleanContent)
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

// MARK: - Rich Content Bubble (replaces plain text for assistant messages)
// Parses text into visual blocks: headings, numbered lists, bullet lists, and prose

struct RichContentBubble: View {
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(parseBlocks().enumerated()), id: \.offset) { index, block in
                switch block {
                case .heading(let text):
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Theme.Gradients.rosePrimary)
                            .frame(width: 3, height: 14)
                        Text(text)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                    .padding(.top, index > 0 ? 4 : 0)

                case .numberedItem(let num, let text):
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(num)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 18, height: 18)
                            .background(Theme.Colors.rosePrimary)
                            .cornerRadius(9)
                        Text(text)
                            .font(.system(size: 11.5))
                            .foregroundColor(Theme.Colors.textPrimary)
                            .lineSpacing(2)
                        Spacer(minLength: 0)
                    }

                case .bulletItem(let emoji, let text):
                    HStack(alignment: .top, spacing: 6) {
                        Text(emoji)
                            .font(.system(size: 11))
                            .frame(width: 16)
                        Text(text)
                            .font(.system(size: 11.5))
                            .foregroundColor(Theme.Colors.textPrimary)
                            .lineSpacing(2)
                        Spacer(minLength: 0)
                    }

                case .text(let text):
                    Text(text)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineSpacing(3)

                case .divider:
                    Rectangle()
                        .fill(Theme.Colors.roseLight.opacity(0.4))
                        .frame(height: 1)
                        .padding(.vertical, 2)
                }
            }
        }
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
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Theme.Colors.glassBorder, lineWidth: 1)
        )
        .shadow(color: Theme.Colors.shadow, radius: 6, x: 0, y: 2)
        .frame(maxWidth: 300, alignment: .leading)
    }

    // MARK: - Content Block Types
    enum ContentBlock {
        case heading(String)
        case numberedItem(Int, String)
        case bulletItem(String, String)
        case text(String)
        case divider
    }

    // MARK: - Parser
    func parseBlocks() -> [ContentBlock] {
        let lines = content.components(separatedBy: "\n")
        var blocks: [ContentBlock] = []
        var currentText = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines — they become dividers between sections
            if trimmed.isEmpty {
                if !currentText.isEmpty {
                    blocks.append(.text(currentText.trimmingCharacters(in: .whitespacesAndNewlines)))
                    currentText = ""
                }
                continue
            }

            // Numbered list: "1. ", "2) ", etc.
            let numPattern = #"^(\d+)[.\)]\s+(.+)"#
            if let match = trimmed.range(of: numPattern, options: .regularExpression) {
                if !currentText.isEmpty {
                    blocks.append(.text(currentText.trimmingCharacters(in: .whitespacesAndNewlines)))
                    currentText = ""
                }
                let numStr = trimmed.prefix(while: { $0.isNumber })
                let num = Int(numStr) ?? 1
                let textStart = trimmed.index(after: trimmed.firstIndex(of: " ") ?? trimmed.startIndex)
                let itemText = String(trimmed[textStart...]).trimmingCharacters(in: .whitespaces)
                blocks.append(.numberedItem(num, itemText))
                continue
            }

            // Bullet with emoji: starts with emoji followed by text
            if let firstScalar = trimmed.unicodeScalars.first,
               firstScalar.value > 127 && firstScalar.properties.isEmoji {
                if !currentText.isEmpty {
                    blocks.append(.text(currentText.trimmingCharacters(in: .whitespacesAndNewlines)))
                    currentText = ""
                }
                // Get the first character cluster as emoji
                let emojiStr = String(trimmed[trimmed.startIndex..<(trimmed.index(after: trimmed.startIndex))])
                let rest = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                if !rest.isEmpty {
                    blocks.append(.bulletItem(emojiStr, rest))
                    continue
                }
            }

            // Dash bullet: "- text" or "-- text"
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("-- ") {
                if !currentText.isEmpty {
                    blocks.append(.text(currentText.trimmingCharacters(in: .whitespacesAndNewlines)))
                    currentText = ""
                }
                let text = trimmed.drop(while: { $0 == "-" || $0 == " " })
                blocks.append(.bulletItem("\u{2022}", String(text)))
                continue
            }

            // Heading detection: short line ending with ":" or ALL CAPS short line
            if trimmed.hasSuffix(":") && trimmed.count < 60 && !trimmed.contains(".") {
                if !currentText.isEmpty {
                    blocks.append(.text(currentText.trimmingCharacters(in: .whitespacesAndNewlines)))
                    currentText = ""
                }
                blocks.append(.heading(String(trimmed.dropLast()).trimmingCharacters(in: .whitespaces)))
                continue
            }

            // Regular text — accumulate
            if currentText.isEmpty {
                currentText = trimmed
            } else {
                currentText += " " + trimmed
            }
        }

        // Flush remaining text
        if !currentText.isEmpty {
            blocks.append(.text(currentText.trimmingCharacters(in: .whitespacesAndNewlines)))
        }

        return blocks
    }
}

// MARK: - Rich Thinking Bubble (Shimmer + Breathing)
struct RichThinkingBubble: View {
    @State private var dotPhase: [Bool] = [false, false, false]
    @State private var breathe = false
    @State private var shimmerPhase: CGFloat = -1

    var body: some View {
        HStack(spacing: 10) {
            // Pulsing brain
            Text("\u{1F9E0}")
                .font(.system(size: 14))
                .scaleEffect(breathe ? 1.15 : 0.95)
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: breathe)

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
                        .offset(y: dotPhase[i] ? -5 : 2)
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
                // Animated shimmer gradient
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            Theme.Colors.rosePale.opacity(0),
                            Theme.Colors.rosePrimary.opacity(0.08),
                            Theme.Colors.rosePale.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.5)
                    .offset(x: shimmerPhase * geo.size.width * 1.5 - geo.size.width * 0.25)
                }
            }
        )
        .background(.ultraThinMaterial)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Theme.Colors.roseLight.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: Theme.Colors.rosePrimary.opacity(0.12), radius: breathe ? 12 : 5)
        .scaleEffect(breathe ? 1.01 : 1.0)
        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: breathe)
        .onAppear {
            for i in 0..<3 { dotPhase[i] = true }
            breathe = true
            withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                shimmerPhase = 1
            }
        }
    }
}

// MARK: - Streaming Bubble (with blinking cursor)
struct StreamingBubble: View {
    let text: String
    let role: ChatMessage.Role
    @State private var cursorVisible = true

    var cleanText: String {
        text.replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .replacingOccurrences(of: #"(?<!\w)\*(?!\s)"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?<!\s)\*(?!\w)"#, with: "", options: .regularExpression)
    }

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            Text(cleanText)
                .font(.system(size: 12.5))
                .foregroundColor(role == .user ? .white : Theme.Colors.textPrimary)
                .lineSpacing(2)

            // Blinking rose cursor with glow
            if role == .assistant {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Theme.Colors.rosePrimary)
                    .frame(width: 2, height: 14)
                    .opacity(cursorVisible ? 1 : 0.2)
                    .shadow(color: Theme.Colors.rosePrimary.opacity(cursorVisible ? 0.6 : 0), radius: 4)
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

// MARK: - Rich Tool Pill (with spinning ring + spring completion)
struct RichToolPill: View {
    let tool: ChatMessage.ToolCall
    @State private var spinAngle: Double = 0
    @State private var checkBounce = false
    @State private var flashGreen = false

    var body: some View {
        HStack(spacing: 8) {
            // Icon with spinning ring or checkmark
            ZStack {
                if tool.isComplete {
                    Circle()
                        .fill(Color.green.opacity(flashGreen ? 0.2 : 0.1))
                        .frame(width: 26, height: 26)
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.green)
                        .scaleEffect(checkBounce ? 1.0 : 0.3)
                } else {
                    // Spinning ring
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(Theme.Colors.rosePrimary, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 22, height: 22)
                        .rotationEffect(.degrees(spinAngle))

                    Text(tool.icon)
                        .font(.system(size: 10))
                }
            }
            .frame(width: 26, height: 26)

            Text(tool.isComplete
                 ? tool.displayName.replacingOccurrences(of: "...", with: "")
                 : tool.displayName
            )
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(tool.isComplete ? Color(hex: "#2E7D32") : Theme.Colors.textMedium)

            Spacer()

            if tool.isComplete {
                Text("Done")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Color(hex: "#2E7D32"))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.12))
                    .cornerRadius(6)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            tool.isComplete
            ? Color(red: 0.95, green: 1, blue: 0.96)
            : Theme.Colors.rosePale.opacity(0.3)
        )
        .background(.ultraThinMaterial)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    tool.isComplete
                    ? Color.green.opacity(0.3)
                    : Theme.Colors.roseLight.opacity(0.4),
                    lineWidth: 1
                )
        )
        .shadow(color: tool.isComplete ? Color.green.opacity(0.1) : Theme.Colors.shadow, radius: 4, x: 0, y: 2)
        .frame(maxWidth: 270, alignment: .leading)
        .animation(Theme.Animations.springBounce, value: tool.isComplete)
        .onAppear {
            if !tool.isComplete {
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                    spinAngle = 360
                }
            }
        }
        .onChange(of: tool.isComplete) { _, isComplete in
            if isComplete {
                withAnimation(Theme.Animations.springBounce) { checkBounce = true }
                withAnimation(.easeOut(duration: 0.3)) { flashGreen = true }
                withAnimation(.easeOut(duration: 0.8).delay(0.3)) { flashGreen = false }
            }
        }
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
    case fitness = "Fitness"

    var icon: String {
        switch self {
        case .dashboard: return "\u{2764}\u{FE0F}"
        case .cycle: return "\u{1F319}"
        case .fitness: return "\u{1F4AA}"
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
            case .fitness:
                FitnessView(claudeService: claudeService)
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
    @State private var healthKitConnected = HealthService.shared.isAuthorized

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
                    SettingsRow(icon: "\u{2764}\u{FE0F}", title: "HealthKit", isEnabled: healthKitConnected) {
                        Task {
                            let result = await HealthService.shared.requestAccess()
                            healthKitConnected = result
                        }
                    }
                }
                .glassCard()
                .padding(.horizontal, 12)

                // Voice Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("MISS M'S VOICE")
                        .font(.custom("CormorantGaramond-SemiBold", size: 11))
                        .tracking(2.5)
                        .textCase(.uppercase)
                        .foregroundColor(Theme.Colors.textSoft)

                    HStack {
                        Text("Voice Responses")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.Colors.textPrimary)
                        Spacer()
                        Toggle("", isOn: Bindable(ElevenLabsService.shared).voiceEnabled)
                            .toggleStyle(.switch)
                            .scaleEffect(0.7)
                    }

                    HStack {
                        Text("Auto-Speak Replies")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.Colors.textPrimary)
                        Spacer()
                        Toggle("", isOn: Bindable(ElevenLabsService.shared).autoSpeak)
                            .toggleStyle(.switch)
                            .scaleEffect(0.7)
                    }

                    HStack {
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.rosePrimary)
                        Text("ElevenLabs")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.Colors.textPrimary)
                        Spacer()
                        if ElevenLabsService.shared.isConfigured {
                            Text("Connected")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.green)
                        } else {
                            Text("Using Apple Voice")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.Colors.textSoft)
                        }
                    }
                    .padding(.vertical, 4)

                    if ElevenLabsService.shared.isSpeaking {
                        HStack(spacing: 4) {
                            ForEach(0..<5, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Theme.Colors.rosePrimary)
                                    .frame(width: 3, height: .random(in: 6...18))
                                    .animation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true).delay(Double(i) * 0.08), value: ElevenLabsService.shared.isSpeaking)
                            }
                            Text("Speaking...")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.Colors.rosePrimary)
                        }
                    }
                }
                .glassCard()
                .padding(.horizontal, 12)

                // Trigger Word Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("HANDS-FREE")
                        .font(.custom("CormorantGaramond-SemiBold", size: 11))
                        .tracking(2.5)
                        .textCase(.uppercase)
                        .foregroundColor(Theme.Colors.textSoft)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\"Hey Miss M\" Trigger")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.Colors.textPrimary)
                            Text("Say \"Miss M\" to activate voice mode")
                                .font(.system(size: 9))
                                .foregroundColor(Theme.Colors.textSoft)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { TriggerWordService.shared.isEnabled },
                            set: { enabled in
                                if enabled {
                                    Task {
                                        let status = await withCheckedContinuation { cont in
                                            SFSpeechRecognizer.requestAuthorization { s in cont.resume(returning: s) }
                                        }
                                        if status == .authorized {
                                            TriggerWordService.shared.startListening()
                                        }
                                    }
                                } else {
                                    TriggerWordService.shared.stopListening()
                                }
                            }
                        ))
                        .toggleStyle(.switch)
                        .scaleEffect(0.7)
                    }

                    if TriggerWordService.shared.isListening {
                        HStack(spacing: 4) {
                            Circle().fill(Color.green).frame(width: 6, height: 6)
                                .shadow(color: .green.opacity(0.6), radius: 3)
                            Text("Listening for \"Miss M\"...")
                                .font(.system(size: 9))
                                .foregroundColor(Color(hex: "#26A69A"))
                        }
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
                        Text("Miss M v2.0")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.Colors.textMedium)
                        Spacer()
                        Text("Claude Sonnet 4.6")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.textSoft)
                    }
                    Text("Smart Planner \u{00B7} Fitness \u{00B7} Flo Sync \u{00B7} Auto-DND")
                        .font(.system(size: 9))
                        .foregroundColor(Theme.Colors.textXSoft)
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
