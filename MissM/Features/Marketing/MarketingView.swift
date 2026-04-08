import SwiftUI

// MARK: - Marketing Tools View (Phase 2)
// Tabbed: SWOT · STP · Persona · Campaign · PESTLE

struct MarketingView: View {
    let claudeService: ClaudeService
    @State private var selectedTool: MarketingTool = .swot
    @State private var topic = ""
    @State private var result = ""
    @State private var isGenerating = false
    @State private var analyses: [MarketingAnalysis] = []

    enum MarketingTool: String, CaseIterable {
        case swot = "SWOT"
        case stp = "STP"
        case persona = "Persona"
        case campaign = "Campaign"
        case pestle = "PESTLE"

        var icon: String {
            switch self {
            case .swot: return "📊"
            case .stp: return "🎯"
            case .persona: return "👤"
            case .campaign: return "📢"
            case .pestle: return "🌍"
            }
        }

        var description: String {
            switch self {
            case .swot: return "Strengths, Weaknesses, Opportunities, Threats"
            case .stp: return "Segmentation, Targeting, Positioning"
            case .persona: return "Build a customer persona profile"
            case .campaign: return "Plan a marketing campaign"
            case .pestle: return "Political, Economic, Social, Technological, Legal, Environmental"
            }
        }

        var prompt: String {
            switch self {
            case .swot: return """
                Perform a SWOT analysis for: %@
                Format as 4 sections with bullet points:
                **Strengths:**
                **Weaknesses:**
                **Opportunities:**
                **Threats:**
                Keep each point concise (1 sentence). Include 3-4 points per section.
                """
            case .stp: return """
                Perform an STP analysis for: %@
                Format as 3 sections:
                **Segmentation:** (identify 3-4 market segments)
                **Targeting:** (recommend target segment with justification)
                **Positioning:** (positioning statement + perceptual map description)
                Be specific and practical for a university marketing student.
                """
            case .persona: return """
                Create a detailed customer persona for: %@
                Include:
                **Name & Demographics:** (age, gender, location, income, education)
                **Psychographics:** (values, interests, lifestyle)
                **Goals:** (what they want to achieve)
                **Pain Points:** (frustrations and challenges)
                **Media Habits:** (where they spend time online/offline)
                **Buying Behavior:** (how they make purchase decisions)
                Make it realistic and useful for a marketing assignment.
                """
            case .campaign: return """
                Plan a marketing campaign for: %@
                Include:
                **Campaign Objective:** (SMART goal)
                **Target Audience:** (who)
                **Key Message:** (core value proposition)
                **Channels:** (3-4 specific channels with rationale)
                **Timeline:** (4-week rollout plan)
                **Budget Allocation:** (percentage split across channels)
                **KPIs:** (how to measure success)
                Be practical and specific.
                """
            case .pestle: return """
                Perform a PESTLE analysis for: %@
                Format as 6 sections:
                **Political:** (government policies, regulations)
                **Economic:** (economic factors, market conditions)
                **Social:** (demographic trends, cultural factors)
                **Technological:** (tech trends, innovation)
                **Legal:** (laws, compliance requirements)
                **Environmental:** (sustainability, environmental factors)
                Include 2-3 specific points per section.
                """
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("MARKETING TOOLS")
                        .font(.custom("CormorantGaramond-SemiBold", size: 11))
                        .tracking(2.5)
                        .foregroundColor(Theme.Colors.textSoft)
                    Text("Analysis Hub")
                        .font(.custom("PlayfairDisplay-Italic", size: 18))
                        .foregroundColor(Theme.Colors.rosePrimary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // Tool tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(MarketingTool.allCases, id: \.self) { tool in
                        Button(action: {
                            selectedTool = tool
                            result = ""
                        }) {
                            HStack(spacing: 4) {
                                Text(tool.icon).font(.system(size: 10))
                                Text(tool.rawValue).font(.system(size: 10, weight: .medium))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                selectedTool == tool
                                ? AnyView(Theme.Gradients.rosePrimary)
                                : AnyView(Color.white.opacity(0.7))
                            )
                            .foregroundColor(selectedTool == tool ? .white : Theme.Colors.textMedium)
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 12) {
                    // Tool description
                    HStack(spacing: 8) {
                        Text(selectedTool.icon).font(.system(size: 20))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedTool.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Theme.Colors.textPrimary)
                            Text(selectedTool.description)
                                .font(.system(size: 10))
                                .foregroundColor(Theme.Colors.textSoft)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .glassCard(padding: 0)

                    // Input
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Topic / Brand / Product")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Theme.Colors.textSoft)

                        HStack(spacing: 8) {
                            TextField("e.g. Nike's digital marketing strategy", text: $topic)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12))
                                .padding(10)
                                .background(Color.white.opacity(0.8))
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.roseLight, lineWidth: 1))

                            Button(action: { Task { await generate() } }) {
                                HStack(spacing: 4) {
                                    if isGenerating {
                                        ProgressView().scaleEffect(0.6)
                                    } else {
                                        Image(systemName: "sparkles")
                                    }
                                    Text("Analyse")
                                }
                                .font(.system(size: 11, weight: .medium))
                            }
                            .buttonStyle(RoseButtonStyle())
                            .disabled(topic.isEmpty || isGenerating)
                        }
                    }

                    // Result
                    if !result.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("\(selectedTool.rawValue) ANALYSIS")
                                    .font(.custom("CormorantGaramond-SemiBold", size: 10))
                                    .tracking(2)
                                    .foregroundColor(Theme.Colors.textSoft)
                                Spacer()
                                Button(action: {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(result, forType: .string)
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

                            Text(result)
                                .font(.system(size: 11))
                                .foregroundColor(Theme.Colors.textPrimary)
                                .textSelection(.enabled)
                        }
                        .padding(12)
                        .glassCard(padding: 0)
                    }

                    // Recent analyses
                    if !analyses.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("RECENT ANALYSES")
                                .font(.custom("CormorantGaramond-SemiBold", size: 10))
                                .tracking(2)
                                .foregroundColor(Theme.Colors.textSoft)

                            ForEach(analyses.prefix(5)) { analysis in
                                Button(action: {
                                    selectedTool = MarketingTool(rawValue: analysis.type.rawValue) ?? .swot
                                    topic = analysis.title
                                    result = analysis.content
                                }) {
                                    HStack(spacing: 8) {
                                        Text(MarketingTool(rawValue: analysis.type.rawValue)?.icon ?? "📊")
                                            .font(.system(size: 12))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(analysis.title)
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(Theme.Colors.textPrimary)
                                            Text("\(analysis.type.rawValue) · \(timeAgo(analysis.createdAt))")
                                                .font(.system(size: 9))
                                                .foregroundColor(Theme.Colors.textXSoft)
                                        }
                                        Spacer()
                                    }
                                    .padding(8)
                                    .background(Theme.Colors.rosePale.opacity(0.3))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .task { await loadData() }
    }

    private func generate() async {
        isGenerating = true
        defer { isGenerating = false }

        let prompt = String(format: selectedTool.prompt, topic)
        do {
            result = try await claudeService.ask(prompt)
            // Save analysis
            let analysis = MarketingAnalysis(
                title: topic,
                type: MarketingAnalysis.AnalysisType(rawValue: selectedTool.rawValue) ?? .swot,
                content: result
            )
            analyses.insert(analysis, at: 0)
            try? await DataStore.shared.saveMarketingAnalyses(analyses)
        } catch {
            result = "Sorry Miss M, couldn't generate the analysis. Please try again."
        }
    }

    private func loadData() async {
        let loaded = try? await DataStore.shared.loadMarketingAnalyses()
        if let loaded { analyses = loaded }
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }
}
