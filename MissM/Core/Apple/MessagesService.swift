import Foundation

// MARK: - Messages Service (AppleScript)

class MessagesService {

    // MARK: - Send iMessage
    static func send(_ message: String, to phoneNumber: String) async throws {
        let script = """
        tell application "Messages"
            set targetService to 1st service whose service type = iMessage
            set targetBuddy to buddy "\(phoneNumber)" of targetService
            send "\(message)" to targetBuddy
        end tell
        """
        try await runAppleScript(script)
    }

    // MARK: - Get latest incoming message
    // Poll this to check if Miss M has texted from her iPhone
    static func getLatestMessage(from phoneNumber: String) async throws -> String? {
        let script = """
        tell application "Messages"
            set theChats to chats
            repeat with aChat in theChats
                set participants to participants of aChat
                repeat with aPerson in participants
                    if handle of aPerson is "\(phoneNumber)" then
                        set lastMsg to last message of aChat
                        return content of lastMsg
                    end if
                end repeat
            end repeat
            return ""
        end tell
        """
        return try await runAppleScriptWithResult(script)
    }

    // MARK: - AppleScript runner
    private static func runAppleScript(_ script: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                let appleScript = NSAppleScript(source: script)
                appleScript?.executeAndReturnError(&error)
                if let error = error {
                    continuation.resume(throwing: NSError(
                        domain: "AppleScript",
                        code: -1,
                        userInfo: error as? [String: Any]
                    ))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private static func runAppleScriptWithResult(_ script: String) async throws -> String? {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                let appleScript = NSAppleScript(source: script)
                let result = appleScript?.executeAndReturnError(&error)
                if let error = error {
                    continuation.resume(throwing: NSError(
                        domain: "AppleScript",
                        code: -1,
                        userInfo: error as? [String: Any]
                    ))
                } else {
                    continuation.resume(returning: result?.stringValue)
                }
            }
        }
    }
}

// MARK: - iMessage Monitor
// Polls for incoming messages and auto-replies via Claude
@Observable
class MessageMonitor {
    var isActive = false
    var lastProcessedMessage = ""
    private var timer: Timer?
    private let phoneNumber: String
    private let claudeService: ClaudeService

    init(phoneNumber: String, claudeService: ClaudeService) {
        self.phoneNumber = phoneNumber
        self.claudeService = claudeService
    }

    func start() {
        isActive = true
        timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { await self?.checkForNewMessages() }
        }
    }

    func stop() {
        isActive = false
        timer?.invalidate()
        timer = nil
    }

    @MainActor
    private func checkForNewMessages() async {
        guard let latest = try? await MessagesService.getLatestMessage(from: phoneNumber),
              !latest.isEmpty,
              latest != lastProcessedMessage else { return }

        lastProcessedMessage = latest
        // Send to Claude and reply
        do {
            let reply = try await claudeService.ask(latest)
            try await MessagesService.send(reply, to: phoneNumber)
        } catch {
            print("MessagesMonitor error: \(error)")
        }
    }
}
