import SwiftUI

// MARK: - Marketing Tool Tab

enum MarketingTab: String, CaseIterable {
    case swot = "SWOT"
    case stp = "STP"
    case persona = "Persona"
    case campaign = "Campaign"
    case pestle = "PESTLE"
}

// MARK: - Marketing Data Models

struct SWOTData: Codable {
    var strengths: [String] = []
    var weaknesses: [String] = []
    var opportunities: [String] = []
    var threats: [String] = []
}

struct STPData: Codable {
    var segmentation: [String] = []
    var targeting: String = ""
    var positioning: String = ""
}

struct PersonaData: Codable {
    var name: String = ""
    var age: String = ""
    var occupation: String = ""
    var goals: [String] = []
    var painPoints: [String] = []
    var motivations: [(label: String, value: Double)] {
        [("Price", priceMotivation), ("Quality", qualityMotivation), ("Brand", brandMotivation)]
    }
    var priceMotivation: Double = 0.5
    var qualityMotivation: Double = 0.7
    var brandMotivation: Double = 0.3
}

struct CampaignData: Codable {
    var objective: String = ""
    var targetAudience: String = ""
    var channels: [String] = []
    var ideas: [String] = []
}

struct PESTLEData: Codable {
    var political: [String] = []
    var economic: [String] = []
    var social: [String] = []
    var technological: [String] = []
    var legal: [String] = []
    var environmental: [String] = []
}

// MARK: - Marketing ViewModel

@Observable
class MarketingViewModel {
    var selectedTab: MarketingTab = .swot
    var swot = SWOTData()
    var stp = STPData()
    var persona = PersonaData()
    var campaign = CampaignData()
    var pestle = PESTLEData()
    var isGenerating = false
    var newItem = ""
    private let claudeService: ClaudeService

    init(claudeService: ClaudeService) {
        self.claudeService = claudeService
    }

    func generateSWOT(topic: String) async {
        isGenerating = true
        let prompt = "For the topic '\(topic)', give me 3 items each for Strengths, Weaknesses, Opportunities, Threats. Return as short bullet points, no numbering. Format: S: ...|W: ...|O: ...|T: ..."
        do {
            let response = try await claudeService.ask(prompt)
            parseSWOT(response)
        } catch {}
        isGenerating = false
    }

    private func parseSWOT(_ text: String) {
        let parts = text.components(separatedBy: "|")
        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("S:") {
                swot.strengths = trimmed.dropFirst(2).components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            } else if trimmed.hasPrefix("W:") {
                swot.weaknesses = trimmed.dropFirst(2).components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            } else if trimmed.hasPrefix("O:") {
                swot.opportunities = trimmed.dropFirst(2).components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            } else if trimmed.hasPrefix("T:") {
                swot.threats = trimmed.dropFirst(2).components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            }
        }
    }
}

// MARK: - Marketing Tools View

struct MarketingToolsView: View {
    let claudeService: ClaudeService
    @State private var viewModel: MarketingViewModel

    init(claudeService: ClaudeService) {
        self.claudeService = claudeService
        self._viewModel = State(initialValue: MarketingViewModel(claudeService: claudeService))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Marketing Tools")
                    .font(Theme.Fonts.display(18))
                    .foregroundColor(Theme.Colors.rosePrimary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            // Tab selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(MarketingTab.allCases, id: \.self) { tab in
                        Button(action: { viewModel.selectedTab = tab }) {
                            Text(tab.rawValue)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(viewModel.selectedTab == tab ? .white : Theme.Colors.textMedium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(viewModel.selectedTab == tab ? Theme.Gradients.rosePrimary : LinearGradient(colors: [Color.white.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(viewModel.selectedTab == tab ? Color.clear : Theme.Colors.roseLight, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
            }

            // Content
            ScrollView {
                Group {
                    switch viewModel.selectedTab {
                    case .swot: SWOTView(viewModel: viewModel)
                    case .stp: STPView(viewModel: viewModel)
                    case .persona: PersonaView(viewModel: viewModel)
                    case .campaign: CampaignView(viewModel: viewModel)
                    case .pestle: PESTLEView(viewModel: viewModel)
                    }
                }
                .padding(14)
            }
        }
    }
}

// MARK: - SWOT View (2x2 Grid)

struct SWOTView: View {
    @Bindable var viewModel: MarketingViewModel
    @State private var topic = ""

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                TextField("Topic for SWOT analysis...", text: $topic)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.Colors.roseLight, lineWidth: 1))
                Button(action: { Task { await viewModel.generateSWOT(topic: topic) } }) {
                    Text(viewModel.isGenerating ? "..." : "\u{2728} AI")
                        .font(.system(size: 10, weight: .medium))
                }
                .buttonStyle(RoseButtonStyle())
                .disabled(topic.isEmpty)
            }

            // 2x2 Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                SWOTQuadrant(title: "Strengths", color: .green, items: $viewModel.swot.strengths)
                SWOTQuadrant(title: "Weaknesses", color: .red, items: $viewModel.swot.weaknesses)
                SWOTQuadrant(title: "Opportunities", color: .blue, items: $viewModel.swot.opportunities)
                SWOTQuadrant(title: "Threats", color: .orange, items: $viewModel.swot.threats)
            }
        }
    }
}

struct SWOTQuadrant: View {
    let title: String
    let color: Color
    @Binding var items: [String]
    @State private var newItem = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.5)
                    .foregroundColor(color)
            }
            ForEach(items.indices, id: \.self) { i in
                Text("\u{2022} \(items[i])")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.Colors.textPrimary)
            }
            HStack(spacing: 4) {
                TextField("+", text: $newItem)
                    .textFieldStyle(.plain)
                    .font(.system(size: 10))
                    .padding(4)
                    .background(Color.white.opacity(0.5))
                    .cornerRadius(6)
                    .onSubmit {
                        if !newItem.isEmpty { items.append(newItem); newItem = "" }
                    }
            }
        }
        .glassCard(padding: 8)
    }
}

// MARK: - STP View

struct STPView: View {
    @Bindable var viewModel: MarketingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            STPStep(number: 1, title: "Segmentation", text: "Define your market segments")
            EditableList(items: $viewModel.stp.segmentation, placeholder: "Add segment...")

            STPStep(number: 2, title: "Targeting", text: "Choose your target segment")
            TextField("Target segment...", text: $viewModel.stp.targeting)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color.white.opacity(0.8))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.roseLight, lineWidth: 1))

            STPStep(number: 3, title: "Positioning", text: "Define your market position")
            TextField("Positioning statement...", text: $viewModel.stp.positioning)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color.white.opacity(0.8))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.roseLight, lineWidth: 1))
        }
    }
}

struct STPStep: View {
    let number: Int
    let title: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Theme.Gradients.rosePrimary)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
                Text(text)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.Colors.textSoft)
            }
        }
    }
}

// MARK: - Persona View

struct PersonaView: View {
    @Bindable var viewModel: MarketingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Theme.Gradients.rosePrimary)
                    .frame(width: 48, height: 48)
                    .overlay(Text("\u{1F464}").font(.system(size: 22)))
                VStack(alignment: .leading) {
                    TextField("Persona Name", text: $viewModel.persona.name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, weight: .semibold))
                    HStack {
                        TextField("Age", text: $viewModel.persona.age)
                            .textFieldStyle(.plain).font(.system(size: 11))
                        Text("\u{2022}").foregroundColor(Theme.Colors.textXSoft)
                        TextField("Occupation", text: $viewModel.persona.occupation)
                            .textFieldStyle(.plain).font(.system(size: 11))
                    }
                    .foregroundColor(Theme.Colors.textSoft)
                }
            }
            .glassCard(padding: 10)

            // Motivations
            VStack(alignment: .leading, spacing: 6) {
                Text("MOTIVATIONS")
                    .font(.system(size: 9, weight: .bold)).tracking(1.5).foregroundColor(Theme.Colors.textSoft)
                MotivationBar(label: "Price", value: $viewModel.persona.priceMotivation)
                MotivationBar(label: "Quality", value: $viewModel.persona.qualityMotivation)
                MotivationBar(label: "Brand", value: $viewModel.persona.brandMotivation)
            }
            .glassCard(padding: 10)

            VStack(alignment: .leading, spacing: 6) {
                Text("GOALS")
                    .font(.system(size: 9, weight: .bold)).tracking(1.5).foregroundColor(Theme.Colors.textSoft)
                EditableList(items: $viewModel.persona.goals, placeholder: "Add goal...")
            }
            .glassCard(padding: 10)

            VStack(alignment: .leading, spacing: 6) {
                Text("PAIN POINTS")
                    .font(.system(size: 9, weight: .bold)).tracking(1.5).foregroundColor(Theme.Colors.textSoft)
                EditableList(items: $viewModel.persona.painPoints, placeholder: "Add pain point...")
            }
            .glassCard(padding: 10)
        }
    }
}

struct MotivationBar: View {
    let label: String
    @Binding var value: Double

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Theme.Colors.textMedium)
                .frame(width: 50, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Theme.Colors.rosePale).frame(height: 8)
                    RoundedRectangle(cornerRadius: 3).fill(Theme.Gradients.rosePrimary)
                        .frame(width: geo.size.width * value, height: 8)
                }
            }
            .frame(height: 8)
            Text("\(Int(value * 100))%")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Theme.Colors.textSoft)
                .frame(width: 30)
        }
    }
}

// MARK: - Campaign View

struct CampaignView: View {
    @Bindable var viewModel: MarketingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Campaign Objective", text: $viewModel.campaign.objective)
                .textFieldStyle(.plain).padding(10)
                .background(Color.white.opacity(0.8)).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.roseLight, lineWidth: 1))

            TextField("Target Audience", text: $viewModel.campaign.targetAudience)
                .textFieldStyle(.plain).padding(10)
                .background(Color.white.opacity(0.8)).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.roseLight, lineWidth: 1))

            VStack(alignment: .leading, spacing: 6) {
                Text("CHANNELS")
                    .font(.system(size: 9, weight: .bold)).tracking(1.5).foregroundColor(Theme.Colors.textSoft)
                EditableList(items: $viewModel.campaign.channels, placeholder: "Add channel...")
            }
            .glassCard(padding: 10)

            VStack(alignment: .leading, spacing: 6) {
                Text("IDEAS")
                    .font(.system(size: 9, weight: .bold)).tracking(1.5).foregroundColor(Theme.Colors.textSoft)
                ForEach(Array(viewModel.campaign.ideas.enumerated()), id: \.offset) { i, idea in
                    HStack(spacing: 8) {
                        Text("\(i + 1)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                            .background(Theme.Colors.rosePrimary)
                            .clipShape(Circle())
                        Text(idea)
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                }
                EditableList(items: $viewModel.campaign.ideas, placeholder: "Add idea...")
            }
            .glassCard(padding: 10)
        }
    }
}

// MARK: - PESTLE View

struct PESTLEView: View {
    @Bindable var viewModel: MarketingViewModel

    var body: some View {
        VStack(spacing: 8) {
            PESTLESection(title: "Political", color: .red, items: $viewModel.pestle.political)
            PESTLESection(title: "Economic", color: .orange, items: $viewModel.pestle.economic)
            PESTLESection(title: "Social", color: .purple, items: $viewModel.pestle.social)
            PESTLESection(title: "Technological", color: .blue, items: $viewModel.pestle.technological)
            PESTLESection(title: "Legal", color: .indigo, items: $viewModel.pestle.legal)
            PESTLESection(title: "Environmental", color: .green, items: $viewModel.pestle.environmental)
        }
    }
}

struct PESTLESection: View {
    let title: String
    let color: Color
    @Binding var items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title.prefix(1))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 20, height: 20)
                    .background(color)
                    .clipShape(Circle())
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.5)
                    .foregroundColor(color)
            }
            EditableList(items: $items, placeholder: "Add factor...")
        }
        .glassCard(padding: 8)
    }
}

// MARK: - Editable List (reusable)

struct EditableList: View {
    @Binding var items: [String]
    let placeholder: String
    @State private var newItem = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(items.indices, id: \.self) { i in
                HStack {
                    Text("\u{2022} \(items[i])")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.textPrimary)
                    Spacer()
                    Button(action: { items.remove(at: i) }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 8))
                            .foregroundColor(Theme.Colors.textXSoft)
                    }
                    .buttonStyle(.plain)
                }
            }
            TextField(placeholder, text: $newItem)
                .textFieldStyle(.plain)
                .font(.system(size: 10))
                .padding(6)
                .background(Color.white.opacity(0.5))
                .cornerRadius(6)
                .onSubmit {
                    if !newItem.isEmpty { items.append(newItem); newItem = "" }
                }
        }
    }
}
