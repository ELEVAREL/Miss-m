import SwiftUI

// MARK: - Essay Model

struct Essay: Identifiable, Codable {
    let id: UUID
    var title: String
    var body: String
    var outline: [OutlineStep]
    var citations: [Citation]
    var tone: Tone
    var createdAt: Date

    init(id: UUID = UUID(), title: String = "Untitled Essay", body: String = "", outline: [OutlineStep] = OutlineStep.defaults, citations: [Citation] = [], tone: Tone = .academic, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.body = body
        self.outline = outline
        self.citations = citations
        self.tone = tone
        self.createdAt = createdAt
    }

    struct OutlineStep: Identifiable, Codable {
        let id: UUID
        var title: String
        var isComplete: Bool

        init(id: UUID = UUID(), title: String, isComplete: Bool = false) {
            self.id = id; self.title = title; self.isComplete = isComplete
        }

        static var defaults: [OutlineStep] {
            ["Introduction", "Literature Review", "Analysis", "Discussion", "Conclusion"]
                .map { OutlineStep(title: $0) }
        }
    }

    struct Citation: Identifiable, Codable {
        let id: UUID
        var author: String
        var title: String
        var year: String
        var source: String

        init(id: UUID = UUID(), author: String, title: String, year: String = "", source: String = "") {
            self.id = id; self.author = author; self.title = title; self.year = year; self.source = source
        }

        var apaFormat: String {
            "\(author) (\(year)). \(title). \(source)"
        }
    }

    enum Tone: String, Codable, CaseIterable {
        case academic, casual, persuasive, formal
        var label: String { rawValue.capitalized }
    }

    var wordCount: Int {
        body.split(separator: " ").count
    }

    var completedSteps: Int {
        outline.filter(\.isComplete).count
    }
}

// MARK: - Essay ViewModel

@Observable
class EssayViewModel {
    var essay: Essay
    var isGenerating = false
    var aiSuggestion = ""
    private let claudeService: ClaudeService

    init(claudeService: ClaudeService, essay: Essay = Essay()) {
        self.claudeService = claudeService
        self.essay = essay
    }

    func generateDraft(for section: String) async {
        isGenerating = true
        let prompt = """
        Write the "\(section)" section for an essay titled "\(essay.title)".
        Tone: \(essay.tone.label). Keep it under 200 words. Be academic and well-structured.
        Current outline: \(essay.outline.map(\.title).joined(separator: ", "))
        """
        do {
            aiSuggestion = try await claudeService.ask(prompt)
        } catch {
            aiSuggestion = "Could not generate draft. Please try again."
        }
        isGenerating = false
    }

    func insertSuggestion() {
        if !essay.body.isEmpty { essay.body += "\n\n" }
        essay.body += aiSuggestion
        aiSuggestion = ""
        save()
    }

    func save() {
        Task { try? await DataStore.shared.save(essay, to: "essay-\(essay.id.uuidString).json") }
    }
}

// MARK: - Essay Writer View (3-panel)

struct EssayWriterView: View {
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
                Text("Essay Writer")
                    .font(Theme.Fonts.display(18))
                    .foregroundColor(Theme.Colors.rosePrimary)
                Spacer()
                HStack(spacing: 4) {
                    Text("AI Draft")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.Gradients.rosePrimary)
                        .cornerRadius(8)
                    Text("\(viewModel.essay.tone.label)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Theme.Colors.textSoft)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Theme.Colors.rosePale)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            // Tabs: Outline | Editor | Citations
            ScrollView {
                VStack(spacing: 10) {
                    // Title
                    TextField("Essay Title", text: $viewModel.essay.title)
                        .font(.system(size: 14, weight: .semibold))
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.roseLight, lineWidth: 1))
                        .padding(.horizontal, 14)

                    // Outline Steps
                    VStack(alignment: .leading, spacing: 6) {
                        Text("OUTLINE")
                            .font(.custom("CormorantGaramond-SemiBold", size: 11))
                            .tracking(2)
                            .foregroundColor(Theme.Colors.textSoft)

                        ForEach(Array(viewModel.essay.outline.enumerated()), id: \.element.id) { index, step in
                            HStack(spacing: 8) {
                                Button(action: {
                                    viewModel.essay.outline[index].isComplete.toggle()
                                    viewModel.save()
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(step.isComplete ? Theme.Colors.rosePrimary : Color.clear)
                                            .frame(width: 20, height: 20)
                                            .overlay(Circle().stroke(Theme.Colors.roseLight, lineWidth: 1.5))
                                        if step.isComplete {
                                            Text("\u{2713}")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.white)
                                        } else {
                                            Text("\(index + 1)")
                                                .font(.system(size: 9, weight: .medium))
                                                .foregroundColor(Theme.Colors.textSoft)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)

                                Text(step.title)
                                    .font(.system(size: 12))
                                    .foregroundColor(step.isComplete ? Theme.Colors.textXSoft : Theme.Colors.textPrimary)
                                    .strikethrough(step.isComplete)
                                Spacer()

                                // AI generate for this section
                                Button(action: { Task { await viewModel.generateDraft(for: step.title) } }) {
                                    Text("\u{2728} AI")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(Theme.Colors.rosePrimary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Theme.Colors.rosePale)
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // Progress
                        ProgressView(value: Double(viewModel.essay.completedSteps), total: Double(viewModel.essay.outline.count))
                            .tint(Theme.Colors.rosePrimary)
                    }
                    .glassCard(padding: 10)
                    .padding(.horizontal, 14)

                    // AI Suggestion
                    if !viewModel.aiSuggestion.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("\u{2728} AI Suggestion")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Theme.Colors.rosePrimary)
                                Spacer()
                                Button("Insert") { viewModel.insertSuggestion() }
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Theme.Gradients.rosePrimary)
                                    .cornerRadius(8)
                                    .buttonStyle(.plain)
                            }
                            Text(viewModel.aiSuggestion)
                                .font(.system(size: 11))
                                .foregroundColor(Theme.Colors.textMedium)
                        }
                        .glassCard(padding: 10)
                        .padding(.horizontal, 14)
                    }

                    if viewModel.isGenerating {
                        HStack {
                            ProgressView().scaleEffect(0.7)
                            Text("Generating draft...")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.Colors.textSoft)
                        }
                        .padding(8)
                    }

                    // Editor
                    VStack(alignment: .leading, spacing: 6) {
                        Text("EDITOR")
                            .font(.custom("CormorantGaramond-SemiBold", size: 11))
                            .tracking(2)
                            .foregroundColor(Theme.Colors.textSoft)

                        TextEditor(text: $viewModel.essay.body)
                            .font(.system(size: 12))
                            .frame(minHeight: 180)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.roseLight, lineWidth: 1))
                            .onChange(of: viewModel.essay.body) { viewModel.save() }
                    }
                    .glassCard(padding: 10)
                    .padding(.horizontal, 14)

                    // Stats bar
                    HStack(spacing: 12) {
                        StatChip(label: "Words", value: "\(viewModel.essay.wordCount)")
                        StatChip(label: "Sections", value: "\(viewModel.essay.completedSteps)/\(viewModel.essay.outline.count)")
                        StatChip(label: "Citations", value: "\(viewModel.essay.citations.count)")

                        Spacer()
                        Picker("Tone", selection: $viewModel.essay.tone) {
                            ForEach(Essay.Tone.allCases, id: \.self) { t in
                                Text(t.label).tag(t)
                            }
                        }
                        .pickerStyle(.menu)
                        .font(.system(size: 10))
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                }
            }
        }
    }
}

// MARK: - Stat Chip

struct StatChip: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Theme.Colors.rosePrimary)
            Text(label)
                .font(.system(size: 8))
                .foregroundColor(Theme.Colors.textXSoft)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Theme.Colors.rosePale.opacity(0.5))
        .cornerRadius(8)
    }
}
