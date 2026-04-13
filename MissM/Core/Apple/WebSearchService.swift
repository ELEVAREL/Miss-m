import Foundation

// MARK: - Web Search Service
// Gives Miss M the ability to search the internet for current info

@Observable
class WebSearchService {
    static let shared = WebSearchService()

    private init() {}

    // MARK: - DuckDuckGo Instant Answer API (no key required)

    func search(_ query: String) async -> String {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://api.duckduckgo.com/?q=\(encoded)&format=json&no_html=1&skip_disambig=1") else {
            return "Could not search"
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                var results: [String] = []

                // Abstract / instant answer
                if let abstract = json["AbstractText"] as? String, !abstract.isEmpty {
                    results.append(abstract)
                }

                // Related topics
                if let topics = json["RelatedTopics"] as? [[String: Any]] {
                    for topic in topics.prefix(3) {
                        if let text = topic["Text"] as? String, !text.isEmpty {
                            results.append(text)
                        }
                    }
                }

                if !results.isEmpty {
                    return results.joined(separator: "\n\n")
                }
            }
        } catch { }

        // Fallback: scrape a simple search
        return await scrapeSearch(query)
    }

    // MARK: - Fallback: HTML scrape search results

    private func scrapeSearch(_ query: String) async -> String {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://html.duckduckgo.com/html/?q=\(encoded)") else {
            return "Search unavailable"
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let html = String(data: data, encoding: .utf8) ?? ""

            // Extract text from result snippets
            var snippets: [String] = []
            let pattern = #"class="result__snippet"[^>]*>(.*?)</a>"#
            if let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators) {
                let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
                for match in matches.prefix(5) {
                    if let range = Range(match.range(at: 1), in: html) {
                        let snippet = String(html[range])
                            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        if !snippet.isEmpty {
                            snippets.append(snippet)
                        }
                    }
                }
            }

            return snippets.isEmpty ? "No results found for: \(query)" : snippets.joined(separator: "\n\n")
        } catch {
            return "Search failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Fetch URL Content (for research)

    func fetchPage(_ urlString: String) async -> String {
        guard let url = URL(string: urlString) else { return "Invalid URL" }

        do {
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
            let (data, _) = try await URLSession.shared.data(for: request)
            let html = String(data: data, encoding: .utf8) ?? ""

            // Strip HTML tags for plain text
            let text = html
                .replacingOccurrences(of: "<script[^>]*>[\\s\\S]*?</script>", with: "", options: .regularExpression)
                .replacingOccurrences(of: "<style[^>]*>[\\s\\S]*?</style>", with: "", options: .regularExpression)
                .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Return first 2000 chars
            return String(text.prefix(2000))
        } catch {
            return "Could not fetch page"
        }
    }
}
