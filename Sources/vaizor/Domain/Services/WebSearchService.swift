import Foundation

private let webSearchMaxQueryLength = 200

/// Secure, lightweight web search service with Vaizor user agent
@MainActor
class WebSearchService {
    static let shared = WebSearchService()
    
    // Vaizor user agent
    private let userAgent = "Vaizor/1.0 (macOS; AI Chat Client)"
    
    // Rate limiting
    private var requestTimestamps: [Date] = []
    private let maxRequestsPerMinute = 10
    
    // Security: Blocked patterns
    private let blockedPatterns = [
        #"<script"#,
        #"javascript:"#,
        #"onerror="#,
        #"onload="#,
        #"data:text/html"#
    ]
    
    private init() {}
    
    /// Perform a web search with security features
    /// - Parameters:
    ///   - query: Search query (will be sanitized)
    ///   - maxResults: Maximum number of results (default: 5)
    /// - Returns: Array of search results
    func search(_ query: String, maxResults: Int = 5) async throws -> [WebSearchResult] {
        // Security: Input validation
        guard !query.isEmpty else {
            throw WebSearchError.emptyQuery
        }
        
        guard query.count <= webSearchMaxQueryLength else {
            throw WebSearchError.queryTooLong
        }
        
        // Security: Sanitize query
        let sanitizedQuery = sanitizeQuery(query)
        
        // Security: Rate limiting
        try checkRateLimit()
        
        // Security: Validate no blocked patterns
        guard !containsBlockedPatterns(sanitizedQuery) else {
            throw WebSearchError.invalidQuery
        }
        
        AppLogger.shared.log("Performing web search: \(sanitizedQuery)", level: .info)
        
        // Use DuckDuckGo Instant Answer API (privacy-focused, no API key required)
        let encodedQuery = sanitizedQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "https://api.duckduckgo.com/?q=\(encodedQuery)&format=json&no_html=1&skip_disambig=1") else {
            throw WebSearchError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10.0 // 10 second timeout
        request.httpMethod = "GET"
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw WebSearchError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw WebSearchError.httpError(httpResponse.statusCode)
            }
            
            // Parse response
            let decoder = JSONDecoder()
            let duckDuckGoResponse = try decoder.decode(DuckDuckGoResponse.self, from: data)
            
            // Convert to search results
            var results: [WebSearchResult] = []
            
            // Add abstract if available
            if let abstract = duckDuckGoResponse.Abstract, !abstract.isEmpty {
                results.append(WebSearchResult(
                    title: duckDuckGoResponse.Heading ?? "Result",
                    url: duckDuckGoResponse.AbstractURL ?? "",
                    snippet: abstract,
                    source: "DuckDuckGo"
                ))
            }
            
            // Add related topics
            if let relatedTopics = duckDuckGoResponse.RelatedTopics {
                for topic in relatedTopics.prefix(maxResults - results.count) {
                    if let text = topic.Text, let url = topic.FirstURL {
                        results.append(WebSearchResult(
                            title: topic.Text?.components(separatedBy: " - ").first ?? "Related",
                            url: url,
                            snippet: text,
                            source: "DuckDuckGo"
                        ))
                    }
                }
            }
            
            // If no results from Instant Answer API, try HTML search
            if results.isEmpty {
                AppLogger.shared.log("No instant answer, trying HTML search fallback", level: .info)
                let htmlResults = try await performHTMLSearch(query: sanitizedQuery, maxResults: maxResults)
                results.append(contentsOf: htmlResults)
            }

            // If still no results, return search URL
            if results.isEmpty {
                let searchURL = "https://duckduckgo.com/?q=\(encodedQuery)"
                results.append(WebSearchResult(
                    title: "Search: \(sanitizedQuery)",
                    url: searchURL,
                    snippet: "No search results found. Click to search DuckDuckGo directly.",
                    source: "DuckDuckGo"
                ))
            }
            
            // Record request timestamp for rate limiting
            requestTimestamps.append(Date())
            // Clean old timestamps (older than 1 minute)
            requestTimestamps.removeAll { Date().timeIntervalSince($0) > 60 }
            
            AppLogger.shared.log("Web search completed: \(results.count) results", level: .info)
            
            return Array(results.prefix(maxResults))
            
        } catch let error as WebSearchError {
            throw error
        } catch {
            AppLogger.shared.logError(error, context: "Web search failed")
            throw WebSearchError.networkError(error.localizedDescription)
        }
    }
    
    // MARK: - Security Functions
    
    /// Sanitize search query
    private func sanitizeQuery(_ query: String) -> String {
        // Remove HTML tags
        var sanitized = query.replacingOccurrences(
            of: #"<[^>]+>"#,
            with: "",
            options: .regularExpression
        )
        
        // Remove control characters
        sanitized = sanitized.unicodeScalars.filter { scalar in
            !CharacterSet.controlCharacters.contains(scalar)
        }.map { String($0) }.joined()
        
        // Trim whitespace
        sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return sanitized
    }
    
    /// Check if query contains blocked patterns
    private func containsBlockedPatterns(_ query: String) -> Bool {
        return blockedPatterns.contains { pattern in
            query.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }
    
    /// Check rate limiting
    private func checkRateLimit() throws {
        // Remove timestamps older than 1 minute
        requestTimestamps.removeAll { Date().timeIntervalSince($0) > 60 }

        if requestTimestamps.count >= maxRequestsPerMinute {
            throw WebSearchError.rateLimitExceeded
        }
    }

    /// Perform HTML-based search as fallback
    private func performHTMLSearch(query: String, maxResults: Int) async throws -> [WebSearchResult] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "https://html.duckduckgo.com/html/?q=\(encodedQuery)") else {
            return []
        }

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15.0

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let html = String(data: data, encoding: .utf8) else {
                return []
            }

            return parseHTMLSearchResults(html: html, maxResults: maxResults)
        } catch {
            AppLogger.shared.logError(error, context: "HTML search failed")
            return []
        }
    }

    /// Parse HTML search results from DuckDuckGo
    private func parseHTMLSearchResults(html: String, maxResults: Int) -> [WebSearchResult] {
        var results: [WebSearchResult] = []

        // Simpler pattern matching for DuckDuckGo HTML structure
        let titlePattern = #"<a class=\"result__a\"[^>]*href=\"([^\"]+)\"[^>]*>([^<]*)</a>"#
        let snippetPattern = #"<a class=\"result__snippet\"[^>]*>([^<]*)</a>"#

        // Find all title+URL matches
        let titleRegex = try? NSRegularExpression(pattern: titlePattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
        let snippetRegex = try? NSRegularExpression(pattern: snippetPattern, options: [.caseInsensitive, .dotMatchesLineSeparators])

        let titleMatches = titleRegex?.matches(in: html, range: NSRange(html.startIndex..., in: html)) ?? []
        let snippetMatches = snippetRegex?.matches(in: html, range: NSRange(html.startIndex..., in: html)) ?? []

        for (index, match) in titleMatches.enumerated() where index < maxResults {
            guard let urlRange = Range(match.range(at: 1), in: html),
                  let titleRange = Range(match.range(at: 2), in: html) else { continue }

            let rawUrl = String(html[urlRange])
            let title = String(html[titleRange])
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
                .replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&#39;", with: "'")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Decode DuckDuckGo redirect URL
            var finalUrl = rawUrl
            if rawUrl.contains("uddg=") {
                if let urlParam = URLComponents(string: rawUrl)?.queryItems?.first(where: { $0.name == "uddg" })?.value {
                    finalUrl = urlParam
                }
            }

            // Skip ads and internal links
            guard !finalUrl.contains("duckduckgo.com"),
                  finalUrl.hasPrefix("http") else { continue }

            // Get corresponding snippet if available
            var snippet = ""
            if index < snippetMatches.count {
                let snippetMatch = snippetMatches[index]
                if let snippetRange = Range(snippetMatch.range(at: 1), in: html) {
                    snippet = String(html[snippetRange])
                        .replacingOccurrences(of: "&amp;", with: "&")
                        .replacingOccurrences(of: "&lt;", with: "<")
                        .replacingOccurrences(of: "&gt;", with: ">")
                        .replacingOccurrences(of: "<b>", with: "")
                        .replacingOccurrences(of: "</b>", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }

            if !title.isEmpty {
                results.append(WebSearchResult(
                    title: title,
                    url: finalUrl,
                    snippet: snippet.isEmpty ? "No description available" : snippet,
                    source: "DuckDuckGo"
                ))
            }
        }

        return results
    }
}

// MARK: - Models

struct WebSearchResult: Identifiable, Codable {
    let id = UUID()
    let title: String
    let url: String
    let snippet: String
    let source: String

    enum CodingKeys: String, CodingKey {
        case title
        case url
        case snippet
        case source
    }
}

struct DuckDuckGoResponse: Codable {
    let Abstract: String?
    let AbstractURL: String?
    let AbstractText: String?
    let Heading: String?
    let RelatedTopics: [RelatedTopic]?
    
    enum CodingKeys: String, CodingKey {
        case Abstract
        case AbstractURL
        case AbstractText
        case Heading
        case RelatedTopics
    }
}

struct RelatedTopic: Codable {
    let Text: String?
    let FirstURL: String?
    let Icon: Icon?
}

struct Icon: Codable {
    let URL: String?
    let Height: String?
    let Width: String?
}

// MARK: - Errors

enum WebSearchError: LocalizedError {
    case emptyQuery
    case queryTooLong
    case invalidQuery
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case networkError(String)
    case rateLimitExceeded
    
    var errorDescription: String? {
        switch self {
        case .emptyQuery:
            return "Search query cannot be empty"
        case .queryTooLong:
            return "Search query is too long (max \(webSearchMaxQueryLength) characters)"
        case .invalidQuery:
            return "Search query contains invalid characters"
        case .invalidURL:
            return "Invalid search URL"
        case .invalidResponse:
            return "Invalid response from search service"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please wait before searching again."
        }
    }
}
