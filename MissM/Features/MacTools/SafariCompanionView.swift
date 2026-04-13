import SwiftUI

// MARK: - Safari Companion Models

struct SavedSource: Identifiable, Codable {
    let id: UUID
    var title: String
    var url: String
    var snippet: String
    var tags: [String]
    var date: Date

    init(id: UUID = UUID(), title: String, url: String, snippet: String = "", tags: [String] = [], date: Date = Date()) {
        self.id = id; self.title = title; self.url = url; self.snippet = snippet; self.tags = tags; self.date = date
    }
}

// MARK: - Safari Companion ViewModel

@Observable
class SafariCompanionViewModel {
    var currentURL = ""
    var currentTitle = ""
    var pageContent = ""
    var aiInsight = ""
    var savedSources: [SavedSource] = []
    var isReading = false
    var isAnalysing = false
    private let claudeService: ClaudeService

    init(claudeService: ClaudeService) {
        self.claudeService = claudeService
        Task { await loadSources() }
    }

    func readCurrentPage() {
        isReading = true
        let script = """
        tell application "Safari"
            if (count of windows) > 0 then
                set currentTab to current tab of front window
                return (name of currentTab) & "|||" & (URL of currentTab)
            end if
        end tell
        """
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            let result = appleScript.executeAndReturnError(&error)
            if let text = result.stringValue {
                let parts = text.components(separatedBy: "|||")
                if parts.count >= 2 {
                    currentTitle = parts[0]
                    currentURL = parts[1]
                    Task { await fetchPageContent(from: parts[1]) }
                    return
                }
            }
        }
        isReading = false
    }

    private func fetchPageContent(from urlString: String) async {
        defer { DispatchQueue.main.async { self.isReading = false } }
        guard let url = URL(string: urlString) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let html = String(data: data, encoding: .utf8) {
                let plainText = stripHTMLTags(from: html)
                let truncated = String(plainText.prefix(3000))
                await MainActor.run { self.pageContent = truncated }
            }
        } catch {
            await MainActor.run { self.pageContent = "" }
        }
    }

    private func stripHTMLTags(from html: String) -> String {
        // Remove script and style blocks entirely
        var result = html
        let patterns = ["<script[^>]*>[\\s\\S]*?</script>", "<style[^>]*>[\\s\\S]*?</style>"]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "")
            }
        }
        // Remove all remaining HTML tags
        if let tagRegex = try? NSRegularExpression(pattern: "<[^>]+>", options: []) {
            result = tagRegex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: " ")
        }
        // Decode common HTML entities
        result = result.replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
        // Collapse whitespace
        if let wsRegex = try? NSRegularExpression(pattern: "\\s+", options: []) {
            result = wsRegex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: " ")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func summarisePage() async {
        guard !pageContent.isEmpty else { return }
        isAnalysing = true
        do {
            aiInsight = try await claudeService.ask("Summarise this web page in 5 concise bullet points for a university student:\n\nTitle: \(currentTitle)\nURL: \(currentURL)\n\n\(pageContent.prefix(2500))")
        } catch {
            aiInsight = "Could not analyse page."
        }
        isAnalysing = false
    }

    func citePage() async {
        guard !currentURL.isEmpty else { return }
        isAnalysing = true
        do {
            aiInsight = try await claudeService.ask("Generate a Harvard-style citation for this web page:\nTitle: \(currentTitle)\nURL: \(currentURL)\nAccessed: \(DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .none))")
        } catch {
            aiInsight = "Could not generate citation."
        }
        isAnalysing = false
    }

    func saveSource() {
        let source = SavedSource(title: currentTitle, url: currentURL, snippet: String(pageContent.prefix(200)), tags: ["Web"])
        savedSources.insert(source, at: 0)
        Task { try? await DataStore.shared.save(savedSources, to: "safari_sources.json") }
    }

    func loadSources() async {
        savedSources = await DataStore.shared.loadOrDefault([SavedSource].self, from: "safari_sources.json", default: [])
    }
}

// MARK: - Safari Companion View

struct SafariCompanionView: View {
    let claudeService: ClaudeService
    @State private var viewModel: SafariCompanionViewModel

    init(claudeService: ClaudeService) {
        self.claudeService = claudeService
        self._viewModel = State(initialValue: SafariCompanionViewModel(claudeService: claudeService))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack {
                    Text("Safari Companion")
                        .font(Theme.Fonts.display(18))
                        .foregroundColor(Theme.Colors.rosePrimary)
                    Spacer()
                    Button(action: viewModel.readCurrentPage) {
                        HStack(spacing: 4) {
                            if viewModel.isReading { ProgressView().scaleEffect(0.5) }
                            Text(viewModel.isReading ? "..." : "\u{1F310} Read Page")
                                .font(.system(size: 10, weight: .medium))
                        }
                    }
                    .buttonStyle(RoseButtonStyle())
                }
                .padding(.horizontal, 14)

                if !viewModel.currentTitle.isEmpty {
                    // Current Page
                    VStack(alignment: .leading, spacing: 6) {
                        Text("CURRENT PAGE")
                            .font(.custom("CormorantGaramond-SemiBold", size: 11))
                            .tracking(2)
                            .foregroundColor(Theme.Colors.textSoft)
                        Text(viewModel.currentTitle)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Theme.Colors.textPrimary)
                        Text(viewModel.currentURL)
                            .font(.system(size: 9))
                            .foregroundColor(Theme.Colors.rosePrimary)
                            .lineLimit(1)
                        Text(String(viewModel.pageContent.prefix(200)) + "...")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.textSoft)
                            .lineLimit(3)
                    }
                    .glassCard(padding: 10)
                    .padding(.horizontal, 14)

                    // Actions
                    HStack(spacing: 6) {
                        Button(action: { Task { await viewModel.summarisePage() } }) {
                            Text("\u{1F4DD} Summarise")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .buttonStyle(RoseButtonStyle())

                        Button(action: { Task { await viewModel.citePage() } }) {
                            HStack(spacing: 4) {
                                Text("\u{1F4DA} Cite")
                            }
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Theme.Colors.textMedium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.7))
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.roseLight, lineWidth: 1))
                        }
                        .buttonStyle(.plain)

                        Button(action: viewModel.saveSource) {
                            HStack(spacing: 4) {
                                Image(systemName: "bookmark")
                                Text("Save")
                            }
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Theme.Colors.textMedium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.7))
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.roseLight, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)

                    // AI Insight
                    if viewModel.isAnalysing {
                        HStack(spacing: 8) {
                            ProgressView().scaleEffect(0.6)
                            Text("Analysing page...")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.Colors.textSoft)
                        }
                        .glassCard(padding: 10)
                        .padding(.horizontal, 14)
                    } else if !viewModel.aiInsight.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("\u{2728} AI INSIGHT")
                                    .font(.custom("CormorantGaramond-SemiBold", size: 11))
                                    .tracking(2)
                                    .foregroundColor(Theme.Colors.textSoft)
                                Spacer()
                                Button(action: {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(viewModel.aiInsight, forType: .string)
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 10))
                                        .foregroundColor(Theme.Colors.rosePrimary)
                                }
                                .buttonStyle(.plain)
                            }
                            Text(viewModel.aiInsight)
                                .font(.system(size: 11))
                                .foregroundColor(Theme.Colors.textPrimary)
                                .lineSpacing(3)
                                .textSelection(.enabled)
                        }
                        .glassCard(padding: 10)
                        .padding(.horizontal, 14)
                    }
                }

                // Saved Sources
                if !viewModel.savedSources.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SAVED SOURCES")
                            .font(.custom("CormorantGaramond-SemiBold", size: 11))
                            .tracking(2)
                            .foregroundColor(Theme.Colors.textSoft)
                        ForEach(viewModel.savedSources.prefix(5)) { source in
                            HStack(spacing: 8) {
                                Text("\u{1F310}").font(.system(size: 12))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(source.title)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(Theme.Colors.textPrimary)
                                        .lineLimit(1)
                                    Text(source.url)
                                        .font(.system(size: 9))
                                        .foregroundColor(Theme.Colors.rosePrimary)
                                        .lineLimit(1)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 3)
                        }
                    }
                    .glassCard(padding: 10)
                    .padding(.horizontal, 14)
                }

                Spacer().frame(height: 14)
            }
            .padding(.top, 10)
        }
    }
}
