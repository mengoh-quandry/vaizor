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
            
            // If no results from DuckDuckGo, try a web search fallback
            if results.isEmpty {
                // Fallback: Return a search URL suggestion
                let searchURL = "https://duckduckgo.com/?q=\(encodedQuery)"
                results.append(WebSearchResult(
                    title: "Search: \(sanitizedQuery)",
                    url: searchURL,
                    snippet: "No instant answer available. Click to search DuckDuckGo.",
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
