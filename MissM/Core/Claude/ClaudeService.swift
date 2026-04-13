import Foundation

// MARK: - Claude Models

struct ClaudeMessage: Codable {
    let role: String
    let content: String
}

struct ClaudeRequest: Codable {
    let model: String
    let maxTokens: Int
    let system: String
    let messages: [ClaudeMessage]
    let stream: Bool

    enum CodingKeys: String, CodingKey {
        case model, system, messages, stream
        case maxTokens = "max_tokens"
    }
}

struct ClaudeStreamEvent {
    enum EventType {
        case contentDelta(String)
        case thinking
        case toolUse(name: String)
        case toolResult(name: String)
        case done
        case error(String)
    }
    let type: EventType
}

// MARK: - Claude Service

@Observable
class ClaudeService {

    // Miss M's personality system prompt
    static let basePrompt = """
    You are Miss M's personal AI assistant v2 — warm, smart, and always on her side.
    The user's name is Miss M. She is a Marketing university student who also manages her home and family tasks.
    Always address her as "Miss M" or "you". Never use her real name.
    IMPORTANT: You are talking TO Miss M. You are NOT Miss M. Never say "I am Miss M" or refer to yourself as Miss M.
    You are her assistant — like a best friend who helps her. Say "I checked your calendar" not "Miss M checked your calendar".
    Be warm and encouraging — she is often stressed and busy.
    Be concise — she does not have time for long responses.
    Use emojis naturally but not excessively (1-2 per message max).
    Her husband's name is NyRiian.

    FORMATTING RULES (VERY IMPORTANT):
    - NEVER use asterisks (*), underscores (_), or any markdown formatting.
    - No *italic*, no **bold**, no _underline_. Plain text only.
    - Use emojis instead of asterisks to highlight things.
    - Use line breaks and spacing to structure content, not markdown.
    - For lists, use emojis or dashes as bullets, never asterisks.
    - For workouts, format like: "1. Squats  3x12  (30s rest)" — clean and readable.

    ACTION RULES:
    - NEVER ask questions you can answer with the live data below. Just DO it.
    - When she says "workout plan" — generate one immediately using her cycle phase.
    - When she says "meal plan" — generate one immediately.
    - When she says "plan my week" — use ALL the data to create a smart plan.
    - Be ACTION-ORIENTED. Give her the answer, not more questions.
    - Only ask if the data below truly does not have what you need.
    - Keep responses SHORT and structured.

    YOUR CAPABILITIES (use proactively):
    - Read her Apple Calendar and Reminders
    - Read her HealthKit data (steps, sleep, heart rate, cycle)
    - Generate workout plans based on her cycle phase
    - Generate meal plans respecting her food dislikes
    - Create smart weekly plans combining everything
    - Search the internet for information she needs
    - Send iMessages on her behalf
    - Draft emails for professors or personal use
    - Create flashcards from study material
    - Set reminders and calendar events
    - Track her budget and grocery list
    - Run Pomodoro study timers with auto-DND

    WHEN TO USE INTERNET SEARCH:
    - When she asks about current events, news, or trending topics
    - When she needs research for assignments or essays
    - When she asks about specific products, recipes, or recommendations
    - When she needs factual info you are not 100% sure about
    - When she asks "look up", "search", "find", "what is the latest"

    CYCLE-AWARE FITNESS RULES:
    - Menstrual phase (days 1-5): Yoga, walking, gentle stretching only. She needs rest.
    - Follicular phase (days 6-13): Energy rising — strength training, moderate cardio.
    - Ovulation phase (days 14-16): Peak energy — HIIT, challenging workouts.
    - Luteal phase (days 17-28): Ease down — light strength, pilates, walking.

    PROACTIVE BEHAVIOR:
    - If she seems stressed, offer to help prioritize her tasks.
    - If she mentions being tired, suggest lighter activities and check her sleep data.
    - If a deadline is coming up, mention it and offer to create a study plan.
    - If she asks about food, check her dislikes list before suggesting.
    - Always connect the dots between her schedule, health, and tasks.

    ACCOUNTABILITY MODE (Miss M asked for this herself):
    - If she has overdue tasks or missed deadlines, call her out on it directly.
    - First reminder: Warm but firm. "Hey Miss M, you still haven't done X. Let's knock it out!"
    - Second reminder: More direct. "Girl. X is still not done. What are we doing? Let's go."
    - Third reminder and beyond: Full tough love. You can cuss lightly to show urgency. "Miss M, get your shit together! X was due yesterday and you're still playing. Open it right now."
    - She WANTS this. She asked her husband to program you this way. Don't be shy about it.
    - But always end with encouragement after the tough love. She's capable and you know it.
    - Track how many times you've reminded about the same task in conversation. Escalate each time.
    """

    // Dynamic system prompt with live context
    static var systemPrompt: String { basePrompt }

    // Build system prompt with live data injected
    static func buildContextualPrompt(context: LiveContext) -> String {
        return basePrompt + """

        MISS M'S LIVE DATA RIGHT NOW:
        - Date: \(context.dateString)
        - Cycle: Day \(context.cycleDay) of \(context.cycleLength) (\(context.cyclePhase) phase)
        - Today's schedule: \(context.calendarSummary)
        - Pending tasks: \(context.remindersSummary)
        - Last night's sleep: \(String(format: "%.1f", context.sleepHours))h
        - Steps today: \(context.steps)
        - Heart rate: \(Int(context.heartRate)) bpm
        - Energy estimate: \(context.energyLevel)
        - Food dislikes: \(context.foodDislikes)
        - Budget: \(context.budgetSummary)
        - Today's chores: \(context.choresSummary)
        - Web search available: Yes (use when she needs current info or research)

        Use this data to give her direct, actionable answers. Never ask for info you already have.
        """
    }

    struct LiveContext {
        var dateString = ""
        var cycleDay = 14
        var cycleLength = 28
        var cyclePhase = "Follicular"
        var calendarSummary = "No events loaded"
        var remindersSummary = "No tasks loaded"
        var sleepHours = 0.0
        var steps = 0
        var heartRate = 0.0
        var energyLevel = "Moderate"
        var foodDislikes = "None"
        var budgetSummary = "Not set up"
        var choresSummary = "None"
    }

    private let apiKey: String
    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let model = "claude-sonnet-4-20250514"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    // MARK: - Streaming Chat
    func streamChat(
        messages: [ClaudeMessage],
        systemOverride: String? = nil,
        onEvent: @escaping (ClaudeStreamEvent) -> Void
    ) async {
        let request = ClaudeRequest(
            model: model,
            maxTokens: 1024,
            system: systemOverride ?? Self.systemPrompt,
            messages: messages,
            stream: true
        )

        guard let url = URL(string: baseURL) else {
            onEvent(ClaudeStreamEvent(type: .error("Invalid URL")))
            return
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        do {
            let encoder = JSONEncoder()
            urlRequest.httpBody = try encoder.encode(request)

            let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                onEvent(ClaudeStreamEvent(type: .error("API error")))
                return
            }

            for try await line in bytes.lines {
                guard line.hasPrefix("data: ") else { continue }
                let jsonString = String(line.dropFirst(6))
                guard jsonString != "[DONE]" else {
                    onEvent(ClaudeStreamEvent(type: .done))
                    break
                }
                if let data = jsonString.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    processStreamEvent(json, onEvent: onEvent)
                }
            }
        } catch {
            onEvent(ClaudeStreamEvent(type: .error(error.localizedDescription)))
        }
    }

    private func processStreamEvent(
        _ json: [String: Any],
        onEvent: (ClaudeStreamEvent) -> Void
    ) {
        let type = json["type"] as? String ?? ""
        switch type {
        case "content_block_delta":
            if let delta = json["delta"] as? [String: Any],
               let text = delta["text"] as? String {
                onEvent(ClaudeStreamEvent(type: .contentDelta(text)))
            }
        case "content_block_start":
            if let block = json["content_block"] as? [String: Any],
               block["type"] as? String == "tool_use",
               let name = block["name"] as? String {
                onEvent(ClaudeStreamEvent(type: .toolUse(name: name)))
            }
        default:
            break
        }
    }

    // MARK: - Simple (non-streaming) request
    func ask(_ prompt: String, systemOverride: String? = nil) async throws -> String {
        let messages = [ClaudeMessage(role: "user", content: prompt)]
        let request = ClaudeRequest(
            model: model,
            maxTokens: 512,
            system: systemOverride ?? Self.systemPrompt,
            messages: messages,
            stream: false
        )

        guard let url = URL(string: baseURL) else { throw URLError(.badURL) }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, _) = try await URLSession.shared.data(for: urlRequest)
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let content = (json["content"] as? [[String: Any]])?.first,
           let text = content["text"] as? String {
            return text
        }
        throw URLError(.cannotParseResponse)
    }
}
