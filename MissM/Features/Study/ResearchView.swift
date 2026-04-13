import SwiftUI

// MARK: - Research Models

struct ResearchSource: Identifiable, Codable {
    let id: UUID
    var title: String
    var url: String
    var snippet: String
    var tags: [String]
    var isSaved: Bool

    init(id: UUID = UUID(), title: String, url: String = "", snippet: String = "", tags: [String] = [], isSaved: Bool = false) {
        self.id = id; self.title = title; self.url = url; self.snippet = snippet; self.tags = tags; self.isSaved = isSaved
    }
}

struct ResearchCitation: Identifiable, Codable {
    let id: UUID
    var author: String
    var year: String
    var title: String
    var source: String

    init(id: UUID = UUID(), author: String = "", year: String = "", title: String = "", source: String = "") {
        self.id = id; self.author = author; self.year = year; self.title = title; self.source = source
    }

    func apaFormat() -> String {
        "\(author) (\(year)). \(title). \(source)."
    }

    func harvardFormat() -> String {
        "\(author), \(year). \(title). \(source)."
    }
}

// MARK: - Research ViewModel

@Observable
class ResearchViewModel {
    var searchQuery = ""
    var sources: [ResearchSource] = []
    var citations: [ResearchCitation] = []
    var aiSummary = ""
    var isSearching = false
    var citationStyle: CitationStyle = .apa
    var showAddCitation = false
    private let claudeService: ClaudeService

    enum CitationStyle: String, CaseIterable { case apa = "APA", harvard = "Harvard" }

    init(claudeService: ClaudeService) {
        self.claudeService = claudeService
        Task { await loadCitations() }
    }

    func search() async {
        guard !searchQuery.isEmpty else { return }
        isSearching = true
        let prompt = """
        Research the topic: "\(searchQuery)". Return 4 relevant findings. For each, provide:
        - Title (academic style)
        - A 2-sentence summary
        - 2 relevant tags
        Format as a brief research summary, then list the findings numbered 1-4.
        """
        do {
            let response = try await claudeService.ask(prompt)
            aiSummary = response
            // Generate source cards from the AI response
            sources = [
                ResearchSource(title: "AI Research Finding 1", snippet: String(response.prefix(120)), tags: ["research", searchQuery.lowercased()]),
                ResearchSource(title: "AI Research Finding 2", snippet: "Based on analysis of \(searchQuery)", tags: ["analysis"]),
            ]
        } catch {
            aiSummary = "Search failed. Please try again."
        }
        isSearching = false
    }

    func addCitation(_ citation: ResearchCitation) {
        citations.append(citation)
        saveCitations()
    }

    func removeCitation(_ citation: ResearchCitation) {
        citations.removeAll { $0.id == citation.id }
        saveCitations()
    }

    func loadCitations() async {
        citations = await DataStore.shared.loadOrDefault([ResearchCitation].self, from: "citations.json", default: [])
    }

    func saveCitations() {
        Task { try? await DataStore.shared.save(citations, to: "citations.json") }
    }
}

// MARK: - Research View

struct ResearchView: View {
    let claudeService: ClaudeService
    @State private var viewModel: ResearchViewModel

    init(claudeService: ClaudeService) {
        self.claudeService = claudeService
        self._viewModel = State(initialValue: ResearchViewModel(claudeService: claudeService))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                HStack {
                    Text("Research")
                        .font(Theme.Fonts.display(18))
                        .foregroundColor(Theme.Colors.rosePrimary)
                    Spacer()
                }
                .padding(.horizontal, 14)

                // Search
                HStack(spacing: 8) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Theme.Colors.textXSoft)
                            .font(.system(size: 12))
                        TextField("Search a topic...", text: $viewModel.searchQuery)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .onSubmit { Task { await viewModel.search() } }
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Colors.roseLight, lineWidth: 1))

                    Button(action: { Task { await viewModel.search() } }) {
                        Text("\u{1F50D}")
                            .frame(width: 36, height: 36)
                            .background(Theme.Gradients.rosePrimary)
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.searchQuery.isEmpty)
                }
                .padding(.horizontal, 14)

                if viewModel.isSearching {
                    HStack {
                        ProgressView().scaleEffect(0.7)
                        Text("Researching...")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.textSoft)
                    }
                }

                // AI Summary
                if !viewModel.aiSummary.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("\u{2728} AI Summary")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Theme.Colors.rosePrimary)
                            Spacer()
                        }
                        Text(viewModel.aiSummary)
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.textMedium)
                            .lineLimit(8)
                    }
                    .glassCard(padding: 10)
                    .padding(.horizontal, 14)
                }

                // Source Cards
                if !viewModel.sources.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SOURCES")
                            .font(.custom("CormorantGaramond-SemiBold", size: 11))
                            .tracking(2)
                            .foregroundColor(Theme.Colors.textSoft)
                        ForEach(viewModel.sources) { source in
                            SourceCard(source: source)
                        }
                    }
                    .padding(.horizontal, 14)
                }

                // Citation Manager
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("CITATIONS")
                            .font(.custom("CormorantGaramond-SemiBold", size: 11))
                            .tracking(2)
                            .foregroundColor(Theme.Colors.textSoft)
                        Spacer()
                        Picker("Style", selection: $viewModel.citationStyle) {
                            ForEach(ResearchViewModel.CitationStyle.allCases, id: \.self) { s in
                                Text(s.rawValue).tag(s)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 120)

                        Button(action: { viewModel.showAddCitation = true }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(Theme.Colors.rosePrimary)
                        }
                        .buttonStyle(.plain)
                    }

                    if viewModel.citations.isEmpty {
                        Text("No citations yet. Add sources to build your bibliography.")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.textXSoft)
                    } else {
                        ForEach(Array(viewModel.citations.enumerated()), id: \.element.id) { index, citation in
                            HStack(alignment: .top, spacing: 8) {
                                Text("[\(index + 1)]")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Theme.Colors.rosePrimary)
                                Text(viewModel.citationStyle == .apa ? citation.apaFormat() : citation.harvardFormat())
                                    .font(.system(size: 10))
                                    .foregroundColor(Theme.Colors.textMedium)
                                Spacer()
                                Button(action: { viewModel.removeCitation(citation) }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8))
                                        .foregroundColor(Theme.Colors.textXSoft)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .glassCard(padding: 10)
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
            .padding(.top, 10)
        }
        .sheet(isPresented: $viewModel.showAddCitation) {
            AddCitationSheet { viewModel.addCitation($0) }
        }
    }
}

// MARK: - Source Card

struct SourceCard: View {
    let source: ResearchSource

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(source.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.Colors.textPrimary)
            if !source.url.isEmpty {
                Text(source.url)
                    .font(.system(size: 9))
                    .foregroundColor(.blue)
            }
            Text(source.snippet)
                .font(.system(size: 10))
                .foregroundColor(Theme.Colors.textSoft)
                .lineLimit(2)
            HStack(spacing: 4) {
                ForEach(source.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(Theme.Colors.rosePrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.Colors.rosePale)
                        .cornerRadius(6)
                }
                Spacer()
            }
        }
        .glassCard(padding: 8)
    }
}

// MARK: - Add Citation Sheet

struct AddCitationSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var author = ""
    @State private var year = ""
    @State private var title = ""
    @State private var source = ""
    let onAdd: (ResearchCitation) -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("Add Citation")
                .font(Theme.Fonts.display(18))
                .foregroundColor(Theme.Colors.rosePrimary)

            VStack(spacing: 8) {
                TextField("Author(s)", text: $author)
                TextField("Year", text: $year)
                TextField("Title", text: $title)
                TextField("Source / Journal", text: $source)
            }
            .textFieldStyle(.plain)
            .padding(10)
            .background(Color.white.opacity(0.8))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.roseLight, lineWidth: 1))

            HStack {
                Button("Cancel") { dismiss() }
                    .foregroundColor(Theme.Colors.textSoft)
                Spacer()
                Button("Add") {
                    onAdd(ResearchCitation(author: author, year: year, title: title, source: source))
                    dismiss()
                }
                .buttonStyle(RoseButtonStyle())
                .disabled(author.isEmpty || title.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360)
        .background(Theme.Gradients.background)
    }
}
