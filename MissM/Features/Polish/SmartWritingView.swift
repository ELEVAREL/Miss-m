import SwiftUI
import NaturalLanguage

// MARK: - Smart Writing ViewModel

@Observable
class SmartWritingViewModel {
    var text = ""
    var grammarScore = 0
    var clarityScore = 0
    var toneScore = 0
    var readabilityScore = 0
    var overallScore = 0
    var suggestions: [WritingSuggestion] = []
    var isAnalysing = false
    private let claudeService: ClaudeService
    private let checker = NSSpellChecker.shared

    struct WritingSuggestion: Identifiable {
        let id = UUID()
        var type: String // grammar, clarity, tone, vocabulary
        var message: String
        var icon: String
    }

    init(claudeService: ClaudeService) {
        self.claudeService = claudeService
    }

    func analyse() async {
        guard !text.isEmpty else { return }
        isAnalysing = true

        // Spell check
        let spellRange = checker.checkSpelling(of: text, startingAt: 0)
        let hasSpellingErrors = spellRange.location != NSNotFound
        grammarScore = hasSpellingErrors ? 65 : 90

        // NaturalLanguage analysis
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text
        let sentiment = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore).0
        let sentimentVal = Double(sentiment?.rawValue ?? "0") ?? 0
        toneScore = Int(50 + sentimentVal * 50)

        // Readability (sentence length)
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var sentenceCount = 0
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { _, _ in
            sentenceCount += 1
            return true
        }
        let wordCount = text.split(separator: " ").count
        let avgSentenceLength = sentenceCount > 0 ? wordCount / sentenceCount : wordCount
        readabilityScore = avgSentenceLength < 25 ? 85 : 60

        // Clarity (word variety)
        let uniqueWords = Set(text.lowercased().split(separator: " "))
        let variety = wordCount > 0 ? Double(uniqueWords.count) / Double(wordCount) : 0
        clarityScore = Int(variety * 100)

        overallScore = (grammarScore + clarityScore + toneScore + readabilityScore) / 4

        // AI suggestions
        do {
            let response = try await claudeService.ask("""
            Analyse this essay text for a Marketing university student. Give exactly 3 brief suggestions to improve it. Format each on a new line starting with [Grammar], [Clarity], or [Tone]:

            \(text.prefix(1500))
            """)
            suggestions = response.components(separatedBy: "\n").compactMap { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return nil }
                if trimmed.contains("[Grammar]") {
                    return WritingSuggestion(type: "Grammar", message: trimmed.replacingOccurrences(of: "[Grammar]", with: "").trimmingCharacters(in: .whitespaces), icon: "\u{1F4DD}")
                } else if trimmed.contains("[Clarity]") {
                    return WritingSuggestion(type: "Clarity", message: trimmed.replacingOccurrences(of: "[Clarity]", with: "").trimmingCharacters(in: .whitespaces), icon: "\u{1F4A1}")
                } else if trimmed.contains("[Tone]") {
                    return WritingSuggestion(type: "Tone", message: trimmed.replacingOccurrences(of: "[Tone]", with: "").trimmingCharacters(in: .whitespaces), icon: "\u{1F3AF}")
                }
                return nil
            }
        } catch {
            suggestions = [WritingSuggestion(type: "Error", message: "Could not get AI suggestions", icon: "\u{26A0}\u{FE0F}")]
        }
        isAnalysing = false
    }
}

// MARK: - Smart Writing View

struct SmartWritingView: View {
    let claudeService: ClaudeService
    @State private var vm: SmartWritingViewModel

    init(claudeService: ClaudeService) {
        self.claudeService = claudeService
        self._vm = State(initialValue: SmartWritingViewModel(claudeService: claudeService))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack {
                    Text("Smart Writing")
                        .font(Theme.Fonts.display(18))
                        .foregroundColor(Theme.Colors.rosePrimary)
                    Spacer()
                    Button(action: { Task { await vm.analyse() } }) {
                        HStack(spacing: 4) {
                            if vm.isAnalysing { ProgressView().scaleEffect(0.5) }
                            Text(vm.isAnalysing ? "..." : "\u{2728} Analyse")
                                .font(.system(size: 10, weight: .medium))
                        }
                    }
                    .buttonStyle(RoseButtonStyle())
                    .disabled(vm.text.isEmpty)
                }
                .padding(.horizontal, 14)

                // Editor
                TextEditor(text: $vm.text)
                    .font(.system(size: 12))
                    .frame(minHeight: 140)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Colors.roseLight, lineWidth: 1))
                    .padding(.horizontal, 14)

                if vm.overallScore > 0 {
                    // Score
                    VStack(spacing: 8) {
                        HStack {
                            Text("\u{1F4CA} WRITING SCORE")
                                .font(.custom("CormorantGaramond-SemiBold", size: 11))
                                .tracking(2)
                                .foregroundColor(Theme.Colors.textSoft)
                            Spacer()
                            Text("\(vm.overallScore)/100")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(vm.overallScore >= 75 ? .green : vm.overallScore >= 50 ? .orange : .red)
                        }

                        HStack(spacing: 8) {
                            ScorePill(label: "Grammar", score: vm.grammarScore, color: "#26A69A")
                            ScorePill(label: "Clarity", score: vm.clarityScore, color: "#7C4DFF")
                            ScorePill(label: "Tone", score: vm.toneScore, color: "#FF9800")
                            ScorePill(label: "Read.", score: vm.readabilityScore, color: "#E91E8C")
                        }
                    }
                    .glassCard(padding: 10)
                    .padding(.horizontal, 14)

                    // Suggestions
                    if !vm.suggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\u{1F4A1} SUGGESTIONS")
                                .font(.custom("CormorantGaramond-SemiBold", size: 11))
                                .tracking(2)
                                .foregroundColor(Theme.Colors.textSoft)
                            ForEach(vm.suggestions) { s in
                                HStack(alignment: .top, spacing: 6) {
                                    Text(s.icon).font(.system(size: 12))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(s.type)
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(Theme.Colors.rosePrimary)
                                        Text(s.message)
                                            .font(.system(size: 11))
                                            .foregroundColor(Theme.Colors.textPrimary)
                                            .lineSpacing(2)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .glassCard(padding: 10)
                        .padding(.horizontal, 14)
                    }
                }

                Spacer().frame(height: 14)
            }
            .padding(.top, 10)
        }
    }
}

// MARK: - Score Pill

struct ScorePill: View {
    let label: String
    let score: Int
    let color: String

    var body: some View {
        VStack(spacing: 3) {
            Text("\(score)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: color))
            Text(label)
                .font(.system(size: 8))
                .foregroundColor(Theme.Colors.textXSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color(hex: color).opacity(0.1))
        .cornerRadius(8)
    }
}
