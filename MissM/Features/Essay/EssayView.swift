import SwiftUI

// MARK: - Essay Writer View (Phase 2)
// 3-panel layout: Outline sidebar · Editor · Citations

struct EssayView: View {
    let claudeService: ClaudeService
    @State private var viewModel: EssayViewModel

    init(claudeService: ClaudeService) {
        self.claudeService = claudeService
        self._viewModel = State(initialValue: EssayViewModel(claudeService: claudeService))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ESSAY WRITER")
                        .font(.custom("CormorantGaramond-SemiBold", size: 11))
                        .tracking(2.5)
                        .foregroundColor(Theme.Colors.textSoft)
                    if let essay = viewModel.currentEssay {
                        Text(essay.title)
                            .font(.custom("PlayfairDisplay-Italic", size: 16))
                            .foregroundColor(Theme.Colors.rosePrimary)
                            .lineLimit(1)
                    } else {
                        Text("Essay Writer")
                            .font(.custom("PlayfairDisplay-Italic", size: 16))
                            .foregroundColor(Theme.Colors.rosePrimary)
                    }
                }
                Spacer()
                HStack(spacing: 6) {
                    Button(action: { viewModel.showNewEssay = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(RoseButtonStyle())

                    // Panel toggle
                    Button(action: { viewModel.showCitations.toggle() }) {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 11))
                            .foregroundColor(viewModel.showCitations ? Theme.Colors.rosePrimary : Theme.Colors.textSoft)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            if viewModel.currentEssay == nil {
                EssayEmptyState(onNew: { viewModel.showNewEssay = true })
            } else {
                // 3-panel layout (stacked vertically in 420pt popover)
                ScrollView {
                    VStack(spacing: 10) {
                        // Outline panel
                        OutlinePanel(viewModel: viewModel)

                        // Editor panel
                        EditorPanel(viewModel: viewModel)

                        // Citations panel (collapsible)
                        if viewModel.showCitations {
                            CitationsPanel(viewModel: viewModel)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                }
            }
        }
        .sheet(isPresented: $viewModel.showNewEssay) {
            NewEssaySheet(viewModel: viewModel)
        }
        .task { await viewModel.loadData() }
    }
}

// MARK: - Empty State
struct EssayEmptyState: View {
    let onNew: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("✍️").font(.system(size: 40))
            Text("Start Your Essay")
                .font(.custom("PlayfairDisplay-Italic", size: 20))
                .foregroundColor(Theme.Colors.rosePrimary)
            Text("Create a new essay and let AI help you\noutline, draft, and cite sources.")
                .font(.system(size: 12))
                .foregroundColor(Theme.Colors.textSoft)
                .multilineTextAlignment(.center)
            Button("New Essay") { onNew() }
                .buttonStyle(RoseButtonStyle())
            Spacer()
        }
        .padding(24)
    }
}

// MARK: - Outline Panel
struct OutlinePanel: View {
    let viewModel: EssayViewModel
    @State private var newPoint = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("OUTLINE")
                    .font(.custom("CormorantGaramond-SemiBold", size: 10))
                    .tracking(2)
                    .foregroundColor(Theme.Colors.textSoft)
                Spacer()
                Button("AI Outline") {
                    Task { await viewModel.generateOutline() }
                }
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Theme.Colors.rosePrimary)
            }

            if viewModel.isGeneratingOutline {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.6)
                    Text("Generating outline...")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.textSoft)
                }
            }

            ForEach(viewModel.currentEssay?.outline ?? []) { item in
                HStack(spacing: 6) {
                    Circle()
                        .fill(Theme.Colors.rosePrimary)
                        .frame(width: 5, height: 5)
                    Text(item.text)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.textPrimary)
                }
                .padding(.leading, CGFloat(item.level * 12))
            }

            HStack(spacing: 6) {
                TextField("Add outline point...", text: $newPoint)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .padding(6)
                    .background(Color.white.opacity(0.7))
                    .cornerRadius(6)
                Button(action: {
                    guard !newPoint.isEmpty else { return }
                    viewModel.addOutlinePoint(newPoint)
                    newPoint = ""
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(Theme.Colors.rosePrimary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .glassCard(padding: 0)
    }
}

// MARK: - Editor Panel
struct EditorPanel: View {
    let viewModel: EssayViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("EDITOR")
                    .font(.custom("CormorantGaramond-SemiBold", size: 10))
                    .tracking(2)
                    .foregroundColor(Theme.Colors.textSoft)
                Spacer()
                Text(wordCount)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Theme.Colors.textXSoft)

                Button("AI Draft") {
                    Task { await viewModel.generateDraft() }
                }
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Theme.Colors.rosePrimary)
            }

            if viewModel.isGeneratingDraft {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.6)
                    Text("Writing draft...")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.textSoft)
                }
            }

            TextEditor(text: Binding(
                get: { viewModel.currentEssay?.content ?? "" },
                set: { viewModel.updateContent($0) }
            ))
            .font(.system(size: 12))
            .foregroundColor(Theme.Colors.textPrimary)
            .scrollContentBackground(.hidden)
            .frame(minHeight: 180)
            .padding(8)
            .background(Color.white.opacity(0.7))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.Colors.roseLight, lineWidth: 1))
        }
        .padding(10)
        .glassCard(padding: 0)
    }

    private var wordCount: String {
        let count = viewModel.currentEssay?.content
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .count ?? 0
        return "\(count) words"
    }
}

// MARK: - Citations Panel
struct CitationsPanel: View {
    let viewModel: EssayViewModel
    @State private var author = ""
    @State private var title = ""
    @State private var year = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("CITATIONS")
                    .font(.custom("CormorantGaramond-SemiBold", size: 10))
                    .tracking(2)
                    .foregroundColor(Theme.Colors.textSoft)
                Spacer()
                Text("\(viewModel.currentEssay?.citations.count ?? 0) sources")
                    .font(.system(size: 9))
                    .foregroundColor(Theme.Colors.textXSoft)
            }

            ForEach(viewModel.currentEssay?.citations ?? []) { citation in
                HStack(alignment: .top, spacing: 6) {
                    Text("📚").font(.system(size: 10))
                    Text(citation.formatted)
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.textMedium)
                }
                .padding(6)
                .background(Theme.Colors.rosePale.opacity(0.5))
                .cornerRadius(6)
            }

            // Add citation
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    TextField("Author", text: $author)
                    TextField("Year", text: $year)
                        .frame(width: 50)
                }
                HStack(spacing: 6) {
                    TextField("Title", text: $title)
                    Button(action: {
                        guard !author.isEmpty, !title.isEmpty else { return }
                        viewModel.addCitation(author: author, title: title, year: year)
                        author = ""
                        title = ""
                        year = ""
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Theme.Colors.rosePrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .textFieldStyle(.plain)
            .font(.system(size: 10))
            .padding(6)
            .background(Color.white.opacity(0.7))
            .cornerRadius(6)
        }
        .padding(10)
        .glassCard(padding: 0)
    }
}

// MARK: - New Essay Sheet
struct NewEssaySheet: View {
    let viewModel: EssayViewModel
    @State private var title = ""
    @State private var course = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("New Essay")
                .font(.custom("PlayfairDisplay-Italic", size: 18))
                .foregroundColor(Theme.Colors.rosePrimary)

            TextField("Essay title", text: $title)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color.white.opacity(0.8))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.roseLight, lineWidth: 1))

            TextField("Course (optional)", text: $course)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color.white.opacity(0.8))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.roseLight, lineWidth: 1))

            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.textSoft)
                Button("Create") {
                    viewModel.createEssay(title: title, course: course)
                    dismiss()
                }
                .buttonStyle(RoseButtonStyle())
                .disabled(title.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 320)
        .background(Theme.Colors.roseUltra)
    }
}

// MARK: - Essay ViewModel
@Observable
class EssayViewModel {
    var essays: [Essay] = []
    var currentEssayIndex: Int?
    var showNewEssay = false
    var showCitations = false
    var isGeneratingOutline = false
    var isGeneratingDraft = false

    private let claudeService: ClaudeService

    init(claudeService: ClaudeService) {
        self.claudeService = claudeService
    }

    var currentEssay: Essay? {
        guard let index = currentEssayIndex, index < essays.count else { return nil }
        return essays[index]
    }

    func loadData() async {
        let loaded = try? await DataStore.shared.loadEssays()
        if let loaded, !loaded.isEmpty {
            essays = loaded
            currentEssayIndex = 0
        }
    }

    func saveData() {
        Task { try? await DataStore.shared.saveEssays(essays) }
    }

    func createEssay(title: String, course: String) {
        let essay = Essay(title: title, course: course)
        essays.insert(essay, at: 0)
        currentEssayIndex = 0
        saveData()
    }

    func addOutlinePoint(_ text: String) {
        guard let index = currentEssayIndex else { return }
        essays[index].outline.append(OutlineItem(text: text))
        essays[index].updatedAt = Date()
        saveData()
    }

    func updateContent(_ content: String) {
        guard let index = currentEssayIndex else { return }
        essays[index].content = content
        essays[index].updatedAt = Date()
        saveData()
    }

    func addCitation(author: String, title: String, year: String) {
        guard let index = currentEssayIndex else { return }
        essays[index].citations.append(Citation(author: author, title: title, year: year))
        essays[index].updatedAt = Date()
        saveData()
    }

    func generateOutline() async {
        guard let essay = currentEssay else { return }
        isGeneratingOutline = true
        defer { isGeneratingOutline = false }

        let prompt = """
        Generate a clear essay outline for: "\(essay.title)"
        Course: \(essay.course.isEmpty ? "General" : essay.course)
        Return ONLY the outline points, one per line, using "- " prefix.
        Include introduction, 3-4 body sections, and conclusion.
        Keep each point concise (under 10 words).
        """

        do {
            let response = try await claudeService.ask(prompt)
            let points = response.split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "- ", with: "") }
                .filter { !$0.isEmpty }
                .map { OutlineItem(text: $0) }

            guard let index = currentEssayIndex else { return }
            essays[index].outline = points
            essays[index].updatedAt = Date()
            saveData()
        } catch {
            // Error handled silently — user sees no loading spinner
        }
    }

    func generateDraft() async {
        guard let essay = currentEssay, !essay.outline.isEmpty else { return }
        isGeneratingDraft = true
        defer { isGeneratingDraft = false }

        let outlineText = essay.outline.map { "- \($0.text)" }.joined(separator: "\n")
        let prompt = """
        Write an essay draft based on this outline:
        Title: \(essay.title)
        Course: \(essay.course.isEmpty ? "General" : essay.course)
        Outline:
        \(outlineText)

        Write in a clear, academic but approachable style suitable for a university Marketing student.
        Keep to approximately 500-800 words.
        """

        do {
            let response = try await claudeService.ask(prompt)
            guard let index = currentEssayIndex else { return }
            essays[index].content = response
            essays[index].updatedAt = Date()
            saveData()
        } catch {
            // Error handled silently
        }
    }
}
