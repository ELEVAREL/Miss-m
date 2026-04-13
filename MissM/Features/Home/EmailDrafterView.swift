import SwiftUI

// MARK: - Email Template

struct EmailTemplate: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let description: String
    let toPlaceholder: String
    let subjectTemplate: String
    let bodyHint: String
}

// MARK: - Email ViewModel

@Observable
class EmailDrafterViewModel {
    var selectedTemplate: EmailTemplate?
    var to = ""
    var subject = ""
    var body = ""
    var selectedTone: Tone = .formal
    var isGenerating = false
    var showCompose = false
    private let claudeService: ClaudeService

    enum Tone: String, CaseIterable {
        case formal = "Formal"
        case friendly = "Friendly"
        case professional = "Professional"
        case apologetic = "Apologetic"

        var color: Color {
            switch self {
            case .formal: return .blue
            case .friendly: return .orange
            case .professional: return .purple
            case .apologetic: return .red
            }
        }
    }

    static let templates: [EmailTemplate] = [
        EmailTemplate(name: "Professor", icon: "\u{1F393}", description: "Ask about deadlines, extensions, or clarification", toPlaceholder: "professor@university.edu", subjectTemplate: "RE: [Module Name]", bodyHint: "Ask about assignment extension, grade query, etc."),
        EmailTemplate(name: "Group Project", icon: "\u{1F465}", description: "Coordinate with team members", toPlaceholder: "teammate@university.edu", subjectTemplate: "Group Project Update", bodyHint: "Meeting time, task allocation, progress update..."),
        EmailTemplate(name: "Job Application", icon: "\u{1F4BC}", description: "Cover letter or follow-up", toPlaceholder: "hr@company.com", subjectTemplate: "Application for [Position]", bodyHint: "Express interest, highlight skills, request interview..."),
        EmailTemplate(name: "Custom", icon: "\u{270F}\u{FE0F}", description: "Write any email from scratch", toPlaceholder: "recipient@email.com", subjectTemplate: "", bodyHint: "What would you like to say?"),
    ]

    init(claudeService: ClaudeService) {
        self.claudeService = claudeService
    }

    func selectTemplate(_ template: EmailTemplate) {
        selectedTemplate = template
        subject = template.subjectTemplate
        to = ""
        body = ""
        showCompose = true
    }

    func generateDraft() async {
        isGenerating = true
        let templateName = selectedTemplate?.name ?? "Custom"
        let prompt = """
        Draft an email for a Marketing university student (Miss M).
        Type: \(templateName)
        Tone: \(selectedTone.rawValue)
        To: \(to)
        Subject: \(subject)
        Context/notes: \(body.isEmpty ? "General \(templateName.lowercased()) email" : body)

        Write ONLY the email body (no subject line, no greeting header).
        Start with "Dear..." or appropriate greeting. End with "Kind regards,\nMiss M"
        Keep it under 150 words. Be \(selectedTone.rawValue.lowercased()) in tone.
        """
        do {
            let draft = try await claudeService.ask(prompt)
            body = draft
        } catch {
            body = "Could not generate draft. Please try again."
        }
        isGenerating = false
    }

    func openInMail() {
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedTo = to.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "mailto:\(encodedTo)?subject=\(encodedSubject)&body=\(encodedBody)") {
            NSWorkspace.shared.open(url)
        }
    }

    func copyToClipboard() {
        let full = "To: \(to)\nSubject: \(subject)\n\n\(body)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(full, forType: .string)
    }
}

// MARK: - Email Drafter View

struct EmailDrafterView: View {
    let claudeService: ClaudeService
    @State private var viewModel: EmailDrafterViewModel

    init(claudeService: ClaudeService) {
        self.claudeService = claudeService
        self._viewModel = State(initialValue: EmailDrafterViewModel(claudeService: claudeService))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                HStack {
                    Text("Email Drafter")
                        .font(Theme.Fonts.display(18))
                        .foregroundColor(Theme.Colors.rosePrimary)
                    Spacer()
                }
                .padding(.horizontal, 14)

                if viewModel.showCompose {
                    // Compose View
                    emailComposeView
                } else {
                    // Template Selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TEMPLATES")
                            .font(.custom("CormorantGaramond-SemiBold", size: 11))
                            .tracking(2)
                            .foregroundColor(Theme.Colors.textSoft)

                        ForEach(EmailDrafterViewModel.templates) { template in
                            Button(action: { viewModel.selectTemplate(template) }) {
                                HStack(spacing: 10) {
                                    Text(template.icon)
                                        .font(.system(size: 20))
                                        .frame(width: 36, height: 36)
                                        .background(Theme.Colors.rosePale)
                                        .cornerRadius(10)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(template.name)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(Theme.Colors.textPrimary)
                                        Text(template.description)
                                            .font(.system(size: 10))
                                            .foregroundColor(Theme.Colors.textSoft)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10))
                                        .foregroundColor(Theme.Colors.textXSoft)
                                }
                                .padding(10)
                                .background(Color.white.opacity(0.6))
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Colors.glassBorder, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                }

                Spacer().frame(height: 14)
            }
            .padding(.top, 10)
        }
    }

    // MARK: - Compose View

    var emailComposeView: some View {
        VStack(spacing: 10) {
            // Back + template name
            HStack {
                Button(action: { viewModel.showCompose = false }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.system(size: 11))
                    .foregroundColor(Theme.Colors.rosePrimary)
                }
                .buttonStyle(.plain)
                Spacer()
                if let t = viewModel.selectedTemplate {
                    Text("\(t.icon) \(t.name)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.Colors.textSoft)
                }
            }
            .padding(.horizontal, 14)

            // Tone Selector
            HStack(spacing: 6) {
                ForEach(EmailDrafterViewModel.Tone.allCases, id: \.self) { tone in
                    Button(action: { viewModel.selectedTone = tone }) {
                        Text(tone.rawValue)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(viewModel.selectedTone == tone ? .white : tone.color)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(viewModel.selectedTone == tone ? AnyView(tone.color) : AnyView(tone.color.opacity(0.1)))
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)

            // Fields
            VStack(spacing: 8) {
                EmailField(label: "To", text: $viewModel.to, placeholder: viewModel.selectedTemplate?.toPlaceholder ?? "")
                EmailField(label: "Subject", text: $viewModel.subject, placeholder: "Email subject...")

                VStack(alignment: .leading, spacing: 4) {
                    Text("Body")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Theme.Colors.textXSoft)
                    TextEditor(text: $viewModel.body)
                        .font(.system(size: 11))
                        .frame(minHeight: 140)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.roseLight, lineWidth: 1))
                }
            }
            .glassCard(padding: 10)
            .padding(.horizontal, 14)

            // Actions
            HStack(spacing: 8) {
                Button(action: { Task { await viewModel.generateDraft() } }) {
                    HStack(spacing: 4) {
                        if viewModel.isGenerating { ProgressView().scaleEffect(0.5) }
                        Text(viewModel.isGenerating ? "Drafting..." : "\u{2728} AI Draft")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Theme.Gradients.rosePrimary)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)

                Button(action: viewModel.openInMail) {
                    HStack(spacing: 4) {
                        Image(systemName: "envelope")
                        Text("Open in Mail")
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

                Button(action: viewModel.copyToClipboard) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy")
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
        }
    }
}

// MARK: - Email Field

struct EmailField: View {
    let label: String
    @Binding var text: String
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Theme.Colors.textXSoft)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .padding(8)
                .background(Color.white.opacity(0.8))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.Colors.roseLight, lineWidth: 1))
        }
    }
}
