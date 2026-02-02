import Foundation

/// Invisible context enhancement for local models
/// Automatically injects current datetime and detects knowledge staleness
@MainActor
class ContextEnhancer: ObservableObject {
    static let shared = ContextEnhancer()

    // MARK: - Knowledge Cutoff Database

    /// Known training data cutoff dates for popular models
    /// Format: model name prefix -> cutoff date
    private let modelCutoffs: [String: Date] = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var cutoffs: [String: Date] = [:]

        // Llama models
        cutoffs["llama3"] = dateFormatter.date(from: "2023-12-01")
        cutoffs["llama-3"] = dateFormatter.date(from: "2023-12-01")
        cutoffs["llama2"] = dateFormatter.date(from: "2023-07-01")
        cutoffs["llama-2"] = dateFormatter.date(from: "2023-07-01")
        cutoffs["codellama"] = dateFormatter.date(from: "2023-07-01")

        // Mistral models
        cutoffs["mistral"] = dateFormatter.date(from: "2023-09-01")
        cutoffs["mixtral"] = dateFormatter.date(from: "2023-12-01")
        cutoffs["mistral-7b"] = dateFormatter.date(from: "2023-09-01")

        // Qwen models
        cutoffs["qwen"] = dateFormatter.date(from: "2024-01-01")
        cutoffs["qwen2"] = dateFormatter.date(from: "2024-06-01")

        // Phi models
        cutoffs["phi"] = dateFormatter.date(from: "2023-10-01")
        cutoffs["phi-2"] = dateFormatter.date(from: "2023-10-01")
        cutoffs["phi-3"] = dateFormatter.date(from: "2024-04-01")

        // Gemma models
        cutoffs["gemma"] = dateFormatter.date(from: "2024-02-01")
        cutoffs["gemma2"] = dateFormatter.date(from: "2024-06-01")

        // Yi models
        cutoffs["yi"] = dateFormatter.date(from: "2023-11-01")

        // DeepSeek models
        cutoffs["deepseek"] = dateFormatter.date(from: "2024-01-01")
        cutoffs["deepseek-coder"] = dateFormatter.date(from: "2024-01-01")

        // Vicuna/Wizard models
        cutoffs["vicuna"] = dateFormatter.date(from: "2023-06-01")
        cutoffs["wizardlm"] = dateFormatter.date(from: "2023-06-01")
        cutoffs["wizard"] = dateFormatter.date(from: "2023-06-01")

        // Neural Chat
        cutoffs["neural-chat"] = dateFormatter.date(from: "2023-10-01")

        // Orca models
        cutoffs["orca"] = dateFormatter.date(from: "2023-08-01")
        cutoffs["orca2"] = dateFormatter.date(from: "2023-11-01")

        // Starling
        cutoffs["starling"] = dateFormatter.date(from: "2023-11-01")

        // OpenHermes
        cutoffs["openhermes"] = dateFormatter.date(from: "2023-10-01")

        // Zephyr
        cutoffs["zephyr"] = dateFormatter.date(from: "2023-10-01")

        // Nous Hermes
        cutoffs["nous-hermes"] = dateFormatter.date(from: "2023-09-01")

        // Solar
        cutoffs["solar"] = dateFormatter.date(from: "2023-12-01")

        // Claude (for comparison/API usage)
        cutoffs["claude-3"] = dateFormatter.date(from: "2024-04-01")
        cutoffs["claude-3.5"] = dateFormatter.date(from: "2024-04-01")
        cutoffs["claude-3-5"] = dateFormatter.date(from: "2024-04-01")

        // GPT models (for comparison/API usage)
        cutoffs["gpt-4"] = dateFormatter.date(from: "2023-12-01")
        cutoffs["gpt-4-turbo"] = dateFormatter.date(from: "2023-12-01")
        cutoffs["gpt-3.5"] = dateFormatter.date(from: "2021-09-01")

        return cutoffs
    }()

    // MARK: - Staleness Detection Keywords

    /// Keywords that trigger staleness detection
    private let stalenessKeywords: Set<String> = [
        // Time-sensitive
        "latest", "current", "today", "now", "recent", "recently",
        "this week", "this month", "this year", "right now",
        "at the moment", "currently", "presently", "nowadays",

        // Version/update queries
        "newest", "new version", "latest version", "update",
        "release", "released", "announcement", "announced",
        "just came out", "just released", "new feature",

        // Price/market queries
        "price", "cost", "stock", "market", "bitcoin", "crypto",
        "cryptocurrency", "exchange rate", "dollar", "euro",

        // Events/news
        "news", "event", "happening", "election", "score",
        "weather", "forecast", "trending", "viral",

        // Technology
        "ios", "android", "macos", "windows", "chrome", "safari",
        "swift", "python", "javascript", "typescript", "rust", "go",

        // Years that indicate recent queries
        "2024", "2025", "2026", "2027"
    ]

    /// Topic patterns that strongly suggest time-sensitive queries
    private let stalenessPatterns: [String] = [
        #"(?:what|who) (?:is|are|was|were) (?:the )?(?:current|latest|new)"#,
        #"(?:how much|what) (?:is|does|did) .+ (?:cost|price)"#,
        #"(?:when|what time) (?:is|does|did|will)"#,
        #"(?:has|have|did) .+ (?:release|announce|update)"#,
        #"(?:what|who) (?:won|win|is winning)"#,
        #"\b20(?:2[4-9]|[3-9]\d)\b"#, // Years 2024+
        #"(?:new|latest|recent) (?:version|release|update|feature)"#
    ]

    private init() {}

    // MARK: - Public API

    /// Enhance context for a message before sending to local model
    /// - Parameters:
    ///   - message: The user's message
    ///   - model: The model name (used to lookup cutoff date)
    ///   - enableAutoRefresh: Whether to auto-search for fresh data
    /// - Returns: Enhanced context with optional fresh data
    func enhanceContext(
        message: String,
        model: String,
        enableAutoRefresh: Bool = true
    ) async -> EnhancedContext {
        var enhancements: [ContextEnhancement] = []
        var chainOfThoughtNotes: [String] = []

        // Always add datetime context
        let datetimeContext = generateDateTimeContext()
        enhancements.append(.datetime(datetimeContext))

        // Check for staleness triggers
        let stalenessResult = detectStalenessQuery(message)

        if stalenessResult.isStale && enableAutoRefresh {
            let cutoffDate = getModelCutoff(for: model)
            let cutoffDescription = formatCutoffDate(cutoffDate)
            let currentDate = formatCurrentDate()

            chainOfThoughtNotes.append("Detected potentially outdated query. Fetching current information...")
            chainOfThoughtNotes.append("Model training: \(cutoffDescription) | Current: \(currentDate) | Refreshing data...")

            // Extract search query from user message
            let searchQuery = extractSearchQuery(from: message, triggers: stalenessResult.triggers)

            // Fetch fresh data
            do {
                let searchResults = try await WebSearchService.shared.search(searchQuery, maxResults: 3)

                if !searchResults.isEmpty {
                    enhancements.append(.freshData(
                        results: searchResults,
                        cutoffDate: cutoffDate,
                        query: searchQuery
                    ))
                    chainOfThoughtNotes.append("Found \(searchResults.count) current sources to supplement response.")
                }
            } catch {
                AppLogger.shared.logError(error, context: "ContextEnhancer: Web search failed")
                chainOfThoughtNotes.append("Could not fetch current data: \(error.localizedDescription)")
            }
        }

        return EnhancedContext(
            originalMessage: message,
            enhancements: enhancements,
            chainOfThoughtNotes: chainOfThoughtNotes,
            stalenessDetected: stalenessResult.isStale,
            staleTriggers: stalenessResult.triggers
        )
    }

    /// Generate the datetime context string for system prompt injection
    func generateDateTimeContext() -> DateTimeContext {
        let now = Date()
        let formatter = DateFormatter()

        // Full format: "Saturday, February 1, 2026 at 3:45 PM PST"
        formatter.dateFormat = "EEEE, MMMM d, yyyy 'at' h:mm a zzz"
        let fullDateTime = formatter.string(from: now)

        // Get timezone info
        let timezone = TimeZone.current
        let timezoneAbbr = timezone.abbreviation() ?? "UTC"
        let timezoneOffset = timezone.secondsFromGMT() / 3600
        let offsetString = timezoneOffset >= 0 ? "+\(timezoneOffset)" : "\(timezoneOffset)"

        // Day of week
        formatter.dateFormat = "EEEE"
        let dayOfWeek = formatter.string(from: now)

        // ISO date for precise reference
        formatter.dateFormat = "yyyy-MM-dd"
        let isoDate = formatter.string(from: now)

        // Time only
        formatter.dateFormat = "h:mm a"
        let timeOnly = formatter.string(from: now)

        return DateTimeContext(
            fullDateTime: fullDateTime,
            dayOfWeek: dayOfWeek,
            isoDate: isoDate,
            timeOnly: timeOnly,
            timezone: timezoneAbbr,
            timezoneOffset: offsetString
        )
    }

    /// Build the enhanced system prompt with injected context
    func buildEnhancedSystemPrompt(
        basePrompt: String?,
        context: EnhancedContext
    ) -> String {
        var prompt = basePrompt ?? ""

        // Inject datetime context
        if let datetimeEnhancement = context.enhancements.first(where: {
            if case .datetime = $0 { return true }
            return false
        }), case .datetime(let datetime) = datetimeEnhancement {
            let datetimeSection = """

            <current_datetime>
            Current date and time: \(datetime.fullDateTime)
            Day: \(datetime.dayOfWeek)
            Timezone: \(datetime.timezone) (UTC\(datetime.timezoneOffset))
            </current_datetime>
            """
            prompt = datetimeSection + "\n" + prompt
        }

        // Inject fresh data if available
        if let freshDataEnhancement = context.enhancements.first(where: {
            if case .freshData = $0 { return true }
            return false
        }), case .freshData(let results, let cutoff, let query) = freshDataEnhancement {
            let cutoffStr = formatCutoffDate(cutoff)

            var freshDataSection = """

            <fresh_context_data>
            Note: The user's query may involve information after your training cutoff (\(cutoffStr)).
            Here is current information retrieved for: "\(query)"

            """

            for (index, result) in results.enumerated() {
                freshDataSection += """
                [\(index + 1)] \(result.title)
                Source: \(result.url)
                \(result.snippet)

                """
            }

            freshDataSection += """
            Use this fresh data to provide an accurate, up-to-date response.
            If this data conflicts with your training, prefer the fresh data above.
            </fresh_context_data>
            """

            prompt += freshDataSection
        }

        return prompt
    }

    // MARK: - Private Helpers

    /// Detect if a query might be asking about potentially stale information
    private func detectStalenessQuery(_ message: String) -> (isStale: Bool, triggers: [String]) {
        let lowercased = message.lowercased()
        var triggers: [String] = []

        // Check for keyword matches
        for keyword in stalenessKeywords {
            if lowercased.contains(keyword) {
                triggers.append(keyword)
            }
        }

        // Check for pattern matches
        for pattern in stalenessPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(message.startIndex..., in: message)
                if let match = regex.firstMatch(in: message, options: [], range: range) {
                    if let matchRange = Range(match.range, in: message) {
                        triggers.append(String(message[matchRange]))
                    }
                }
            }
        }

        // Remove duplicates and return
        let uniqueTriggers = Array(Set(triggers))
        return (isStale: !uniqueTriggers.isEmpty, triggers: uniqueTriggers)
    }

    /// Get the training cutoff date for a model
    private func getModelCutoff(for model: String) -> Date? {
        let lowercased = model.lowercased()

        // Try exact match first
        if let cutoff = modelCutoffs[lowercased] {
            return cutoff
        }

        // Try prefix match
        for (prefix, cutoff) in modelCutoffs {
            if lowercased.hasPrefix(prefix) || lowercased.contains(prefix) {
                return cutoff
            }
        }

        // Default to a conservative estimate (1 year ago)
        return Calendar.current.date(byAdding: .year, value: -1, to: Date())
    }

    /// Format a cutoff date for display
    private func formatCutoffDate(_ date: Date?) -> String {
        guard let date = date else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }

    /// Format current date for display
    private func formatCurrentDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: Date())
    }

    /// Extract a search query from the user's message
    private func extractSearchQuery(from message: String, triggers: [String]) -> String {
        // Remove common question prefixes
        var query = message
        let prefixPatterns = [
            #"^(?:what|who|when|where|how|why|can you tell me|tell me|please|could you)\s+"#,
            #"^(?:i want to know|i need to know|i'm wondering|do you know)\s+"#
        ]

        for pattern in prefixPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(query.startIndex..., in: query)
                query = regex.stringByReplacingMatches(in: query, options: [], range: range, withTemplate: "")
            }
        }

        // Trim and limit length
        query = query.trimmingCharacters(in: .whitespacesAndNewlines)

        // If query is too long, try to extract key phrases
        if query.count > 100 {
            // Use triggers to build a focused query
            if !triggers.isEmpty {
                let triggerContext = triggers.prefix(3).joined(separator: " ")
                // Take first 50 chars + trigger context
                let truncated = String(query.prefix(50))
                query = "\(truncated) \(triggerContext)"
            } else {
                query = String(query.prefix(100))
            }
        }

        // Add "current" or "latest" if not present for better results
        let lowercased = query.lowercased()
        if !lowercased.contains("current") && !lowercased.contains("latest") && !lowercased.contains("2024") && !lowercased.contains("2025") && !lowercased.contains("2026") {
            query = "current \(query)"
        }

        return query
    }
}

// MARK: - Supporting Types

/// Context enhancement types
enum ContextEnhancement {
    case datetime(DateTimeContext)
    case freshData(results: [WebSearchResult], cutoffDate: Date?, query: String)
    case customContext(String)
}

/// DateTime context information
struct DateTimeContext {
    let fullDateTime: String      // "Saturday, February 1, 2026 at 3:45 PM PST"
    let dayOfWeek: String         // "Saturday"
    let isoDate: String           // "2026-02-01"
    let timeOnly: String          // "3:45 PM"
    let timezone: String          // "PST"
    let timezoneOffset: String    // "-8"
}

/// Result of context enhancement
struct EnhancedContext {
    let originalMessage: String
    let enhancements: [ContextEnhancement]
    let chainOfThoughtNotes: [String]
    let stalenessDetected: Bool
    let staleTriggers: [String]

    /// Whether any enhancements were applied
    var hasEnhancements: Bool {
        !enhancements.isEmpty
    }

    /// Whether fresh data was fetched
    var hasFreshData: Bool {
        enhancements.contains { enhancement in
            if case .freshData = enhancement { return true }
            return false
        }
    }

    /// Get chain of thought status for display
    var chainOfThoughtStatus: String? {
        guard !chainOfThoughtNotes.isEmpty else { return nil }
        return chainOfThoughtNotes.joined(separator: "\n")
    }
}

// MARK: - Model Cutoff Info Extension

extension ContextEnhancer {
    /// Get human-readable info about a model's knowledge cutoff
    func getModelInfo(for model: String) -> ModelKnowledgeInfo {
        let cutoff = getModelCutoff(for: model)
        let cutoffStr = formatCutoffDate(cutoff)
        let currentStr = formatCurrentDate()

        var staleness = "Unknown"
        if let cutoff = cutoff {
            let months = Calendar.current.dateComponents([.month], from: cutoff, to: Date()).month ?? 0
            if months <= 3 {
                staleness = "Recent"
            } else if months <= 12 {
                staleness = "\(months) months old"
            } else {
                let years = months / 12
                staleness = "\(years)+ years old"
            }
        }

        return ModelKnowledgeInfo(
            modelName: model,
            cutoffDate: cutoff,
            cutoffDescription: cutoffStr,
            currentDate: currentStr,
            stalenessDescription: staleness
        )
    }
}

/// Information about a model's knowledge cutoff
struct ModelKnowledgeInfo {
    let modelName: String
    let cutoffDate: Date?
    let cutoffDescription: String
    let currentDate: String
    let stalenessDescription: String
}
