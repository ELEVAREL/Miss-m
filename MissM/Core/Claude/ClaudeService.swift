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
    static let systemPrompt = """
    You are Miss M's personal AI assistant — warm, encouraging, and always on her side.
    She is a Marketing university student who also manages home and family tasks.
    Always address her as "Miss M". Be warm but efficient — she's always busy.
    
    You have access to her Apple Calendar, Reminders, and can send iMessages on her behalf.
    When using a tool, briefly mention what you're doing (e.g. "Checking your calendar...").
    
    Keep responses concise. Use relevant emojis occasionally. 
    Always end with a helpful follow-up offer when appropriate.
    """

    private let apiKey: String
    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let model = "claude-sonnet-4-20250514"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    // MARK: - Streaming Chat
    func streamChat(
        messages: [ClaudeMessage],
        onEvent: @escaping (ClaudeStreamEvent) -> Void
    ) async {
        let request = ClaudeRequest(
            model: model,
            maxTokens: 1024,
            system: Self.systemPrompt,
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
    func ask(_ prompt: String) async throws -> String {
        let messages = [ClaudeMessage(role: "user", content: prompt)]
        let request = ClaudeRequest(
            model: model,
            maxTokens: 512,
            system: Self.systemPrompt,
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
