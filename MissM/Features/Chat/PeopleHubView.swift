import SwiftUI

// MARK: - People Hub Models

struct PersonContact: Identifiable {
    let id = UUID()
    var name: String
    var relationship: String
    var lastMessage: String
    var messageCount: Int
    var isPinned: Bool
    var gradientColors: [String]
    var quickReplies: [String]
}

// MARK: - People Hub ViewModel

@Observable
class PeopleHubViewModel {
    var contacts: [PersonContact] = []
    var isLoading = false
    var selectedPerson: PersonContact?
    var composeText = ""
    private let claudeService: ClaudeService

    init(claudeService: ClaudeService) {
        self.claudeService = claudeService
    }

    func loadContacts() {
        isLoading = true
        // Read real Messages via AppleScript
        let script = """
        tell application "Messages"
            set chatList to ""
            repeat with c in (chats)
                try
                    set p to participants of c
                    if (count of p) = 1 then
                        set personName to name of item 1 of p
                        set chatList to chatList & personName & "|||"
                    end if
                end try
            end repeat
            return chatList
        end tell
        """
        var error: NSDictionary?
        var names: [String] = []
        if let appleScript = NSAppleScript(source: script) {
            let result = appleScript.executeAndReturnError(&error)
            if let text = result.stringValue {
                names = text.components(separatedBy: "|||").filter { !$0.isEmpty }
            }
        }

        // Count frequency
        var freq: [String: Int] = [:]
        for name in names { freq[name, default: 0] += 1 }

        // Build contacts sorted by frequency, NyRiian always first
        var sorted = freq.sorted { $0.value > $1.value }.map { name, count in
            PersonContact(
                name: name,
                relationship: inferRelationship(name),
                lastMessage: "",
                messageCount: count,
                isPinned: name == "NyRiian",
                gradientColors: gradientForRelationship(inferRelationship(name)),
                quickReplies: repliesForRelationship(inferRelationship(name))
            )
        }

        // Ensure NyRiian is #1
        if let nyIdx = sorted.firstIndex(where: { $0.name == "NyRiian" }) {
            let ny = sorted.remove(at: nyIdx)
            sorted.insert(ny, at: 0)
        } else {
            // Add NyRiian even if no messages found
            sorted.insert(PersonContact(
                name: "NyRiian",
                relationship: "Husband",
                lastMessage: "",
                messageCount: 0,
                isPinned: true,
                gradientColors: ["#E91E8C", "#C2185B", "#880E4F"],
                quickReplies: ["Hey love!", "On my way home", "What's for dinner?", "Miss you"]
            ), at: 0)
        }

        contacts = Array(sorted.prefix(10))
        isLoading = false
    }

    func sendMessage(to person: PersonContact, text: String) {
        guard !text.isEmpty else { return }
        let escapedText = text.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedName = person.name.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Messages"
            set targetBuddy to buddy "\(escapedName)" of (service 1 whose service type is iMessage)
            send "\(escapedText)" to targetBuddy
        end tell
        """
        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)
        composeText = ""
    }

    private func inferRelationship(_ name: String) -> String {
        if name == "NyRiian" { return "Husband" }
        return "Contact"
    }

    private func gradientForRelationship(_ rel: String) -> [String] {
        switch rel {
        case "Husband": return ["#E91E8C", "#C2185B", "#880E4F"]
        case "Family": return ["#FF6B9D", "#E91E8C"]
        case "Friend": return ["#FF9800", "#F57C00"]
        case "Classmate": return ["#26A69A", "#00796B"]
        default: return ["#78909C", "#546E7A"]
        }
    }

    private func repliesForRelationship(_ rel: String) -> [String] {
        switch rel {
        case "Husband": return ["Hey love!", "On my way home", "What's for dinner?", "Miss you"]
        case "Family": return ["Love you!", "Call me later", "How are you?", "See you soon"]
        case "Friend": return ["Hey!", "Want to study?", "Free later?", "LOL"]
        default: return ["Hi!", "Thanks", "Sure!", "Got it"]
        }
    }
}

// MARK: - People Hub View

struct PeopleHubView: View {
    let claudeService: ClaudeService
    @State private var vm: PeopleHubViewModel

    init(claudeService: ClaudeService) {
        self.claudeService = claudeService
        self._vm = State(initialValue: PeopleHubViewModel(claudeService: claudeService))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack {
                    Text("People Hub")
                        .font(Theme.Fonts.display(18))
                        .foregroundColor(Theme.Colors.rosePrimary)
                    Spacer()
                    Button(action: vm.loadContacts) {
                        HStack(spacing: 4) {
                            if vm.isLoading { ProgressView().scaleEffect(0.5) }
                            Text(vm.isLoading ? "..." : "\u{1F504} Sync")
                                .font(.system(size: 10, weight: .medium))
                        }
                    }
                    .buttonStyle(RoseButtonStyle())
                }
                .padding(.horizontal, 14)

                if vm.contacts.isEmpty {
                    VStack(spacing: 10) {
                        Text("\u{1F465}").font(.system(size: 28))
                        Text("Tap Sync to load contacts from Messages")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.Colors.textSoft)
                    }
                    .frame(maxWidth: .infinity)
                    .glassCard(padding: 20)
                    .padding(.horizontal, 14)
                } else {
                    ForEach(vm.contacts) { person in
                        PersonCard(person: person, vm: vm)
                            .padding(.horizontal, 14)
                    }
                }

                Spacer().frame(height: 14)
            }
            .padding(.top, 10)
        }
    }
}

// MARK: - Person Card

struct PersonCard: View {
    let person: PersonContact
    let vm: PeopleHubViewModel
    @State private var expanded = false

    var body: some View {
        VStack(spacing: 8) {
            Button(action: { withAnimation { expanded.toggle() } }) {
                HStack(spacing: 10) {
                    // Avatar circle
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: person.gradientColors.map { Color(hex: $0) },
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                            .frame(width: 36, height: 36)
                        Text(String(person.name.prefix(1)))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(person.name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Theme.Colors.textPrimary)
                            if person.isPinned {
                                Text("\u{1F4CC}")
                                    .font(.system(size: 8))
                            }
                        }
                        Text(person.relationship)
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.textSoft)
                    }
                    Spacer()
                    Text("\(person.messageCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Theme.Colors.rosePrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.Colors.rosePale)
                        .cornerRadius(8)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9))
                        .foregroundColor(Theme.Colors.textXSoft)
                }
            }
            .buttonStyle(.plain)

            if expanded {
                // Quick replies
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(person.quickReplies, id: \.self) { reply in
                            Button(action: { vm.sendMessage(to: person, text: reply) }) {
                                Text(reply)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(Theme.Colors.rosePrimary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Theme.Colors.rosePale)
                                    .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .glassCard(padding: 10)
    }
}
