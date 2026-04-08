import SwiftUI

// MARK: - Essay Writer View (Phase 2)
// 3-panel layout: Outline sidebar · Editor · Citations + AI Tools
// Matches docs/design/04-essay-writer.html

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
                ScrollView {
                    VStack(spacing: 10) {
                        // Outline panel
                        OutlinePanel(viewModel: viewModel)

                        // Editor panel
                        EditorPanel(viewModel: viewModel)

                        // AI Writing Tools
                        AIWritingToolsPanel(viewModel: viewModel)

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

// MARK: - Outline Panel (per design: numbered items with descriptions)
struct OutlinePanel: View {
    let viewModel: EssayViewModel
    @State private var newPoint = ""
    @State private var selectedIndex: Int? = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section label
            HStack {
                Text("ESSAY OUTLINE")
                    .font(.custom("CormorantGaramond-SemiBold", size: 10))
                    .tracking(2.5)
                    .foregroundColor(Theme.Colors.rosePrimary)
                Spacer()
                Rectangle()
                    .fill(Theme.Colors.rosePrimary.opacity(0.14))
                    .frame(height: 1)
                    .frame(maxWidth: 80)
            }
            .padding(.bottom, 12)

            // Essay info
            if let essay = viewModel.currentEssay {
                Text("\(essay.title)\n\(essay.course.isEmpty ? "" : "\(essay.course) · ")Due date TBD")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.Colors.textSoft)
                    .lineSpacing(2)
                    .padding(.bottom, 12)
            }

            // Outline items with numbered circles
            ForEach(Array((viewModel.currentEssay?.outline ?? []).enumerated()), id: \.element.id) { index, item in
                OutlineItemRow(
                    index: index + 1,
                    item: item,
                    isSelected: selectedIndex == index,
                    onTap: { selectedIndex = index }
                )
            }

            // Add outline point
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
            .padding(.top, 8)

            // Action buttons (per design)
            VStack(spacing: 7) {
                Button(action: { Task { await viewModel.generateDraft() } }) {
                    HStack(spacing: 4) {
                        Text("✦")
                        Text(viewModel.isGeneratingDraft ? "Generating…" : "Generate Full Draft")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(RoseButtonStyle())
                .disabled(viewModel.isGeneratingDraft)

                OutlineActionButton(icon: "📚", label: "Add All Citations")
                OutlineActionButton(icon: "🔄", label: "Rewrite in My Voice")
                OutlineActionButton(icon: "📥", label: "Export as Word Doc")
            }
            .padding(.top, 14)

            // Progress bar
            if let essay = viewModel.currentEssay, !essay.outline.isEmpty {
                VStack(spacing: 6) {
                    HStack {
                        Text("Overall Progress")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.textSoft)
                        Spacer()
                        Text("\(essayProgress(essay))%")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Theme.Colors.rosePrimary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Theme.Colors.rosePrimary.opacity(0.1))
                                .frame(height: 5)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(colors: [Theme.Colors.rosePrimary, Theme.Colors.roseMid],
                                                   startPoint: .leading, endPoint: .trailing)
                                )
                                .frame(width: geo.size.width * Double(essayProgress(essay)) / 100.0, height: 5)
                        }
                    }
                    .frame(height: 5)
                }
                .padding(.top, 16)
            }
        }
        .padding(16)
        .glassCard(padding: 0)
    }

    private func essayProgress(_ essay: Essay) -> Int {
        let words = essay.content.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        let target = 2500 // default target
        return min(100, Int(Double(words) / Double(target) * 100))
    }
}

// MARK: - Outline Item Row (per design: numbered circle + title + subtitle)
struct OutlineItemRow: View {
    let index: Int
    let item: OutlineItem
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 9) {
                // Numbered circle
                Text("\(index)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 21, height: 21)
                    .background(
                        LinearGradient(
                            colors: [Theme.Colors.rosePrimary, Theme.Colors.roseDeep],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.text)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(Theme.Colors.textPrimary)
                }
            }
            .padding(9)
            .background(isSelected ? Theme.Colors.rosePrimary.opacity(0.08) : Color.clear)
            .cornerRadius(11)
            .overlay(
                RoundedRectangle(cornerRadius: 11)
                    .stroke(isSelected ? Theme.Colors.rosePrimary.opacity(0.15) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.bottom, 3)
    }
}

struct OutlineActionButton: View {
    let icon: String
    let label: String

    var body: some View {
        Button(action: {}) {
            HStack(spacing: 4) {
                Text(icon).font(.system(size: 10))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.Colors.textMedium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.75))
            .cornerRadius(11)
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.Colors.roseLight, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Editor Panel (per design: toolbar, title, stats bar)
struct EditorPanel: View {
    let viewModel: EssayViewModel
    @State private var activeMode = "AI Draft"

    private let modes = ["✦ AI Draft", "📝 Edit", "📚 Citations", "🎨 Tone", "✅ Check", "📥 Export"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Editor head: title + badge
            HStack {
                Text(viewModel.currentEssay?.title ?? "Untitled")
                    .font(.custom("PlayfairDisplay-Italic", size: 16))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(1)
                Spacer()
                Text("AI Draft Mode")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(hex: "#C65200"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.12))
                    .cornerRadius(8)
            }
            .padding(.bottom, 14)

            // Toolbar (per design: 6 mode buttons)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(modes, id: \.self) { mode in
                        Button(action: { activeMode = mode }) {
                            Text(mode)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(activeMode == mode ? .white : Theme.Colors.textMedium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(activeMode == mode ? Theme.Colors.rosePrimary : Color.white.opacity(0.8))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(activeMode == mode ? Theme.Colors.rosePrimary : Theme.Colors.roseLight, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.bottom, 14)

            Divider()
                .background(Theme.Colors.rosePrimary.opacity(0.08))
                .padding(.bottom, 14)

            // Loading indicator
            if viewModel.isGeneratingDraft || viewModel.isGeneratingOutline {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.6)
                    Text(viewModel.isGeneratingDraft ? "Writing draft…" : "Generating outline…")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.textSoft)
                }
                .padding(.bottom, 8)
            }

            // Editor area
            TextEditor(text: Binding(
                get: { viewModel.currentEssay?.content ?? "" },
                set: { viewModel.updateContent($0) }
            ))
            .font(.system(size: 13, weight: .light))
            .foregroundColor(Theme.Colors.textPrimary)
            .scrollContentBackground(.hidden)
            .lineSpacing(5)
            .frame(minHeight: 200)
            .padding(8)
            .background(Color.white.opacity(0.72))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.Colors.roseLight.opacity(0.5), lineWidth: 1))

            // Stats bar (per design)
            EssayStatsBar(viewModel: viewModel)
                .padding(.top, 12)
        }
        .padding(22)
        .background(Color.white.opacity(0.72))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.Colors.glassBorder, lineWidth: 1))
        .shadow(color: Theme.Colors.shadow, radius: 10, x: 0, y: 4)
    }
}

// MARK: - Essay Stats Bar (per design: words, section, reading level, tone, citations, plagiarism)
struct EssayStatsBar: View {
    let viewModel: EssayViewModel

    var body: some View {
        HStack(spacing: 0) {
            ForEach(stats, id: \.label) { stat in
                HStack(spacing: 0) {
                    Text("\(stat.label): ")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.textSoft)
                    Text(stat.value)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Theme.Colors.rosePrimary)
                }
                if stat.label != stats.last?.label {
                    Spacer()
                }
            }
        }
        .padding(.top, 12)
        .overlay(
            Rectangle()
                .fill(Theme.Colors.rosePrimary.opacity(0.07))
                .frame(height: 1),
            alignment: .top
        )
    }

    private var stats: [(label: String, value: String)] {
        let content = viewModel.currentEssay?.content ?? ""
        let words = content.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        let citations = viewModel.currentEssay?.citations.count ?? 0
        return [
            ("Words", "\(words)"),
            ("Tone", "Academic"),
            ("Citations", "\(citations)"),
        ]
    }
}

// MARK: - AI Writing Tools Panel (per design: 6 tool items)
struct AIWritingToolsPanel: View {
    let viewModel: EssayViewModel

    private let tools: [(icon: String, name: String, desc: String)] = [
        ("✦", "Continue Writing", "AI writes the next paragraph in your academic voice"),
        ("🎨", "Adjust Tone", "Academic · Formal · Persuasive · Analytical"),
        ("🔄", "Rephrase Selection", "Rewrite selected text while keeping meaning"),
        ("📖", "Expand Section", "Add depth, examples and evidence to any paragraph"),
        ("✂️", "Make Concise", "Reduce word count without losing substance"),
        ("🔬", "Add Evidence", "Insert supporting research and academic sources"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("AI WRITING TOOLS")
                    .font(.custom("CormorantGaramond-SemiBold", size: 10))
                    .tracking(2.5)
                    .foregroundColor(Theme.Colors.rosePrimary)
                Spacer()
                Rectangle()
                    .fill(Theme.Colors.rosePrimary.opacity(0.14))
                    .frame(height: 1)
                    .frame(maxWidth: 80)
            }
            .padding(.bottom, 10)

            ForEach(tools, id: \.name) { tool in
                AIToolItem(icon: tool.icon, name: tool.name, desc: tool.desc)
            }
        }
        .padding(16)
        .glassCard(padding: 0)
    }
}

struct AIToolItem: View {
    let icon: String
    let name: String
    let desc: String
    @State private var isHovered = false

    var body: some View {
        Button(action: {}) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 7) {
                    Text(icon).font(.system(size: 11))
                    Text(name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.Colors.textPrimary)
                }
                Text(desc)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.Colors.textSoft)
                    .lineSpacing(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .background(isHovered ? Color.white : Color.white.opacity(0.7))
            .cornerRadius(13)
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(Theme.Colors.glassBorder, lineWidth: 1))
            .shadow(color: isHovered ? Theme.Colors.shadow : .clear, radius: isHovered ? 7 : 0, x: 0, y: 2)
            .offset(x: isHovered ? 2 : 0)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .padding(.bottom, 6)
    }
}

// MARK: - Citations Panel (per design: colored dots, tags, AI search)
struct CitationsPanel: View {
    let viewModel: EssayViewModel
    @State private var author = ""
    @State private var title = ""
    @State private var year = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("CITATIONS ADDED")
                    .font(.custom("CormorantGaramond-SemiBold", size: 10))
                    .tracking(2.5)
                    .foregroundColor(Theme.Colors.rosePrimary)
                Spacer()
                Rectangle()
                    .fill(Theme.Colors.rosePrimary.opacity(0.14))
                    .frame(height: 1)
                    .frame(maxWidth: 80)
            }
            .padding(.bottom, 10)

            ForEach(viewModel.currentEssay?.citations ?? []) { citation in
                CitationItemRow(citation: citation)
            }

            // Placeholder for next citation
            HStack(alignment: .top, spacing: 8) {
                Circle()
                    .fill(Theme.Colors.textXSoft)
                    .frame(width: 8, height: 8)
                    .padding(.top, 3)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Add next citation…")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(Theme.Colors.textSoft)
                    Text("\(max(0, 8 - (viewModel.currentEssay?.citations.count ?? 0))) more needed")
                        .font(.system(size: 9))
                        .foregroundColor(Theme.Colors.textSoft)
                }
            }
            .padding(9)
            .background(Color.white.opacity(0.7))
            .cornerRadius(11)
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.Colors.glassBorder, lineWidth: 1))
            .opacity(0.5)
            .padding(.bottom, 6)

            // Add citation fields
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
            .padding(.bottom, 8)

            // Action buttons (per design)
            Button(action: {}) {
                HStack(spacing: 4) {
                    Text("📚")
                    Text("Find Sources with AI")
                }
                .font(.system(size: 11, weight: .semibold))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(RoseButtonStyle())

            Button(action: {}) {
                HStack(spacing: 4) {
                    Text("📋")
                    Text("Generate Reference List")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.Colors.textMedium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.75))
                .cornerRadius(11)
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.Colors.roseLight, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
        .padding(16)
        .glassCard(padding: 0)
    }
}

struct CitationItemRow: View {
    let citation: Citation

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color.blue)
                .frame(width: 8, height: 8)
                .padding(.top, 3)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(citation.author) (\(citation.year))")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(Theme.Colors.textPrimary)
                Text(citation.title)
                    .font(.system(size: 9))
                    .foregroundColor(Theme.Colors.textSoft)
                    .lineLimit(2)
                Text("APA")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 1)
                    .background(Color.blue.opacity(0.09))
                    .cornerRadius(6)
                    .padding(.top, 2)
            }
        }
        .padding(9)
        .background(Color.white.opacity(0.7))
        .cornerRadius(11)
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.Colors.glassBorder, lineWidth: 1))
        .padding(.bottom, 6)
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
        .frame(width: 350)
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
            // Error handled silently
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
