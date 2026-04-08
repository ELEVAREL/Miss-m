import SwiftUI
import AppKit

// MARK: - Safari Companion View (Phase 5)
// Reads current browser page via AppleScript → summarise + cite + save to essay

struct SafariCompanionView: View {
    let claudeService: ClaudeService
    @State private var pageTitle: String = ""
    @State private var pageURL: String = ""
    @State private var pageContent: String = ""
    @State private var aiSummary: String = ""
    @State private var isLoading = false
    @State private var isSummarising = false
    @State private var errorMessage: String? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                HStack(spacing: 8) {
                    Text("SAFARI COMPANION")
                        .font(.custom("CormorantGaramond-SemiBold", size: 10))
                        .tracking(2.5)
                        .foregroundColor(Theme.Colors.rosePrimary)
                    Rectangle()
                        .fill(Theme.Colors.rosePrimary.opacity(0.14))
                        .frame(height: 1)
                }
                .padding(.horizontal, 16)

                // Read Current Page button
                if pageContent.isEmpty && !isLoading {
                    VStack(spacing: 14) {
                        Text("🌐")
                            .font(.system(size: 48))

                        Text("Read Current Page")
                            .font(.custom("PlayfairDisplay-Italic", size: 18))
                            .foregroundColor(Theme.Colors.textPrimary)

                        Text("Reads the page open in Safari — summarise, cite, or save to your essay")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.Colors.textSoft)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)

                        Button(action: { Task { await readSafariPage() } }) {
                            HStack(spacing: 6) {
                                Image(systemName: "safari")
                                Text("Read from Safari")
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Theme.Gradients.rosePrimary)
                            .cornerRadius(12)
                            .shadow(color: Theme.Colors.rosePrimary.opacity(0.32), radius: 14, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .padding(.horizontal, 20)
                    .glassCard(padding: 0)
                    .padding(.horizontal, 16)
                }

                // Loading
                if isLoading {
                    VStack(spacing: 8) {
                        ProgressView().scaleEffect(0.8)
                        Text("Reading Safari page…")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.textSoft)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .glassCard(padding: 0)
                    .padding(.horizontal, 16)
                }

                // Error
                if let error = errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 12))
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.textMedium)
                    }
                    .padding(10)
                    .glassCard(padding: 0)
                    .padding(.horizontal, 16)
                }

                // Page info + content
                if !pageContent.isEmpty {
                    // Page info card
                    VStack(alignment: .leading, spacing: 6) {
                        Text(pageTitle)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.Colors.textPrimary)
                            .lineLimit(2)
                        Text(pageURL)
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.rosePrimary)
                            .lineLimit(1)
                        Text("\(pageContent.count) characters extracted")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.textSoft)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .glassCard(padding: 0)
                    .padding(.horizontal, 16)

                    // Action buttons grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        SafariActionButton(icon: "📝", label: "Summarise") {
                            Task { await summarisePage() }
                        }
                        SafariActionButton(icon: "📚", label: "Add Citation") {}
                        SafariActionButton(icon: "✍️", label: "Use in Essay") {}
                        SafariActionButton(icon: "🃏", label: "Make Flashcard") {}
                    }
                    .padding(.horizontal, 16)

                    // Summarising
                    if isSummarising {
                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.5)
                            Text("Summarising with Claude…")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.Colors.textSoft)
                        }
                        .padding(10)
                        .glassCard(padding: 0)
                        .padding(.horizontal, 16)
                    }

                    // AI Summary
                    if !aiSummary.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("✦ AI SUMMARY")
                                .font(.system(size: 9, weight: .semibold))
                                .tracking(2)
                                .foregroundColor(Theme.Colors.rosePrimary)

                            Text(aiSummary)
                                .font(.system(size: 12))
                                .foregroundColor(Theme.Colors.textMedium)
                                .lineSpacing(4)
                                .textSelection(.enabled)

                            HStack(spacing: 8) {
                                Button(action: {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(aiSummary, forType: .string)
                                }) {
                                    Text("Copy")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(Theme.Colors.rosePrimary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.Colors.rosePrimary.opacity(0.15), lineWidth: 1))
                        .padding(.horizontal, 16)
                    }

                    // Page text preview
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("PAGE TEXT")
                                .font(.custom("CormorantGaramond-SemiBold", size: 10))
                                .tracking(2)
                                .foregroundColor(Theme.Colors.textSoft)
                            Spacer()
                            Button(action: {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(pageContent, forType: .string)
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "doc.on.doc")
                                    Text("Copy")
                                }
                                .font(.system(size: 9))
                                .foregroundColor(Theme.Colors.rosePrimary)
                            }
                            .buttonStyle(.plain)
                        }

                        Text(String(pageContent.prefix(1500)))
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.textMedium)
                            .textSelection(.enabled)
                            .lineLimit(nil)
                    }
                    .padding(12)
                    .glassCard(padding: 0)
                    .padding(.horizontal, 16)

                    // New page button
                    Button(action: { resetState() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Read Another Page")
                        }
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.rosePrimary)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - AppleScript: Read Safari

    private func readSafariPage() async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        // Get page title
        let titleScript = NSAppleScript(source: """
            tell application "Safari"
                set pageTitle to name of current tab of front window
                return pageTitle
            end tell
        """)

        // Get page URL
        let urlScript = NSAppleScript(source: """
            tell application "Safari"
                set pageURL to URL of current tab of front window
                return pageURL
            end tell
        """)

        // Get page text content via JavaScript
        let contentScript = NSAppleScript(source: """
            tell application "Safari"
                set pageText to do JavaScript "document.body.innerText" in current tab of front window
                return pageText
            end tell
        """)

        var scriptError: NSDictionary?

        guard let titleResult = titleScript?.executeAndReturnError(&scriptError) else {
            errorMessage = "Could not read Safari — is it open with a page loaded?"
            return
        }
        pageTitle = titleResult.stringValue ?? "Untitled"

        if let urlResult = urlScript?.executeAndReturnError(&scriptError) {
            pageURL = urlResult.stringValue ?? ""
        }

        guard let contentResult = contentScript?.executeAndReturnError(&scriptError) else {
            errorMessage = "Could not extract text — Safari may need Accessibility permission."
            return
        }

        let text = contentResult.stringValue ?? ""
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "No text found on this page."
            return
        }

        pageContent = text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func summarisePage() async {
        isSummarising = true
        defer { isSummarising = false }

        let textToSummarise = String(pageContent.prefix(4000))
        let prompt = """
        Summarise this web page for a university student. Be concise — bullet points preferred. \
        Page title: \(pageTitle)
        URL: \(pageURL)

        Content:
        \(textToSummarise)
        """

        do {
            aiSummary = try await claudeService.ask(prompt)
        } catch {
            aiSummary = "Sorry, couldn't summarise this page right now."
        }
    }

    private func resetState() {
        pageTitle = ""
        pageURL = ""
        pageContent = ""
        aiSummary = ""
        errorMessage = nil
    }
}

// MARK: - Safari Action Button
struct SafariActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(icon)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.Colors.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isHovered ? Color.white : Color.white.opacity(0.7))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Colors.glassBorder, lineWidth: 1))
            .shadow(color: isHovered ? Theme.Colors.shadow : .clear, radius: 12, x: 0, y: 4)
            .offset(y: isHovered ? -2 : 0)
            .animation(.easeOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
