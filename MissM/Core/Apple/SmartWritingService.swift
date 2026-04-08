import AppKit
import NaturalLanguage

// MARK: - Smart Writing Service (Phase 2/7)
// NSSpellChecker + NaturalLanguage + Claude: real-time essay check

@Observable
class SmartWritingService {
    static let shared = SmartWritingService()

    // MARK: - Spell Check

    /// Returns spelling/grammar corrections for the given text
    func checkSpelling(_ text: String) -> [WritingIssue] {
        let checker = NSSpellChecker.shared
        var issues: [WritingIssue] = []
        var offset = 0
        let nsText = text as NSString

        while offset < nsText.length {
            let range = checker.checkSpelling(of: text, startingAt: offset)
            if range.location == NSNotFound { break }

            let word = nsText.substring(with: range)
            let guesses = checker.guesses(forWordRange: range, in: text, language: nil, inSpellDocumentWithTag: 0)

            issues.append(WritingIssue(
                type: .spelling,
                range: range,
                text: word,
                suggestion: guesses?.first,
                message: "Possible misspelling: \"\(word)\""
            ))

            offset = range.location + range.length
        }

        return issues
    }

    // MARK: - Grammar Check

    func checkGrammar(_ text: String) -> [WritingIssue] {
        let checker = NSSpellChecker.shared
        var issues: [WritingIssue] = []
        var details: NSArray?

        let range = checker.checkGrammar(of: text, startingAt: 0, language: nil, wrap: false, inSpellDocumentWithTag: 0, details: &details)

        if range.location != NSNotFound, let grammarDetails = details as? [[String: Any]] {
            for detail in grammarDetails {
                let desc = detail[NSSpellChecker.grammaticalAnalysisKey] as? String ?? "Grammar issue"
                issues.append(WritingIssue(
                    type: .grammar,
                    range: range,
                    text: (text as NSString).substring(with: range),
                    suggestion: nil,
                    message: desc
                ))
            }
        }

        return issues
    }

    // MARK: - Sentiment Analysis

    func analyzeSentiment(_ text: String) -> Double {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text
        let (tag, _) = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
        return Double(tag?.rawValue ?? "0") ?? 0
    }

    // MARK: - Readability Analysis

    func analyzeReadability(_ text: String) -> ReadabilityResult {
        let words = text.split(separator: " ")
        let wordCount = words.count
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?")).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let sentenceCount = max(sentences.count, 1)

        // Syllable approximation
        var totalSyllables = 0
        for word in words {
            totalSyllables += estimateSyllables(String(word))
        }

        // Flesch Reading Ease
        let avgWordsPerSentence = Double(wordCount) / Double(sentenceCount)
        let avgSyllablesPerWord = Double(totalSyllables) / max(Double(wordCount), 1)
        let fleschScore = 206.835 - (1.015 * avgWordsPerSentence) - (84.6 * avgSyllablesPerWord)
        let clampedFlesch = max(0, min(100, fleschScore))

        let level: String
        if clampedFlesch >= 80 { level = "Easy" }
        else if clampedFlesch >= 60 { level = "Standard" }
        else if clampedFlesch >= 40 { level = "Academic" }
        else { level = "Complex" }

        return ReadabilityResult(
            score: clampedFlesch,
            level: level,
            wordCount: wordCount,
            sentenceCount: sentenceCount,
            avgWordsPerSentence: avgWordsPerSentence
        )
    }

    // MARK: - Tone Detection

    func detectTone(_ text: String) -> String {
        let sentiment = analyzeSentiment(text)
        if sentiment > 0.3 { return "Positive" }
        if sentiment < -0.3 { return "Critical" }

        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        var adjCount = 0
        var nounCount = 0

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass) { tag, _ in
            if tag == .adjective { adjCount += 1 }
            if tag == .noun { nounCount += 1 }
            return true
        }

        let ratio = nounCount > 0 ? Double(adjCount) / Double(nounCount) : 0
        if ratio > 0.5 { return "Descriptive" }
        return "Neutral"
    }

    // MARK: - Full Analysis

    func fullAnalysis(_ text: String) -> WritingAnalysis {
        let spelling = checkSpelling(text)
        let grammar = checkGrammar(text)
        let readability = analyzeReadability(text)
        let tone = detectTone(text)
        let sentiment = analyzeSentiment(text)

        return WritingAnalysis(
            spellingIssues: spelling,
            grammarIssues: grammar,
            readability: readability,
            tone: tone,
            sentiment: sentiment
        )
    }

    // MARK: - Helpers

    private func estimateSyllables(_ word: String) -> Int {
        let vowels: Set<Character> = ["a", "e", "i", "o", "u", "y"]
        let lower = word.lowercased()
        var count = 0
        var lastWasVowel = false

        for char in lower {
            let isVowel = vowels.contains(char)
            if isVowel && !lastWasVowel { count += 1 }
            lastWasVowel = isVowel
        }

        if lower.hasSuffix("e") && count > 1 { count -= 1 }
        return max(count, 1)
    }
}

// MARK: - Models

struct WritingIssue: Identifiable {
    let id = UUID()
    let type: IssueType
    let range: NSRange
    let text: String
    let suggestion: String?
    let message: String

    enum IssueType {
        case spelling
        case grammar
    }
}

struct ReadabilityResult {
    let score: Double
    let level: String
    let wordCount: Int
    let sentenceCount: Int
    let avgWordsPerSentence: Double
}

struct WritingAnalysis {
    let spellingIssues: [WritingIssue]
    let grammarIssues: [WritingIssue]
    let readability: ReadabilityResult
    let tone: String
    let sentiment: Double

    var totalIssues: Int { spellingIssues.count + grammarIssues.count }
}
