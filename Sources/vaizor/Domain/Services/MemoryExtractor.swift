import Foundation

/// Service for automatically extracting memorable facts from conversations
actor MemoryExtractor {
    static let shared = MemoryExtractor()

    // Patterns that indicate memorable facts
    private let factPatterns: [(pattern: String, key: String)] = [
        // Personal preferences
        ("(?:i|my)\\s+prefer(?:red|s)?\\s+(.+)", "preference"),
        ("(?:i|my)\\s+(?:like|love)s?\\s+(.+)", "preference"),
        ("(?:i|my)\\s+(?:don't|do not|hate)\\s+like\\s+(.+)", "dislike"),

        // Technical preferences
        ("(?:i|we)\\s+use\\s+([A-Za-z0-9\\s]+)\\s+(?:for|as|in)", "technology"),
        ("(?:our|my)\\s+(?:stack|framework|language)\\s+(?:is|are)\\s+(.+)", "tech_stack"),
        ("(?:i|we)\\s+(?:work|code|develop)\\s+(?:in|with)\\s+([A-Za-z0-9\\s]+)", "technology"),

        // Project context
        ("(?:the|this|our)\\s+project\\s+(?:is|uses|has)\\s+(.+)", "project_info"),
        ("(?:we're|we are)\\s+(?:building|creating|developing)\\s+(.+)", "project_goal"),

        // Naming conventions
        ("(?:we|i)\\s+(?:name|call)\\s+(?:it|them|our)\\s+(.+)", "naming"),
        ("(?:our|the)\\s+naming\\s+convention\\s+(?:is|for)\\s+(.+)", "naming_convention"),

        // Coding style
        ("(?:i|we)\\s+(?:always|usually|prefer to)\\s+(.+?)\\s+(?:when|for|in)", "coding_style"),
        ("(?:our|my)\\s+(?:code|coding)\\s+style\\s+(?:is|uses)\\s+(.+)", "coding_style"),

        // Architecture
        ("(?:we|i)\\s+follow\\s+(.+?)\\s+(?:pattern|architecture|approach)", "architecture"),
        ("(?:our|the)\\s+architecture\\s+(?:is|uses|follows)\\s+(.+)", "architecture"),

        // Team info
        ("(?:our|the)\\s+team\\s+(?:is|has|uses)\\s+(.+)", "team_info"),
        ("(?:i|we)\\s+(?:work|am)\\s+(?:as|at|on)\\s+(.+)", "role_or_company"),

        // Important dates/deadlines
        ("(?:deadline|launch|release)\\s+(?:is|on)\\s+(.+)", "deadline"),
        ("(?:by|before|until)\\s+(.+?)\\s+(?:we|i)\\s+(?:need|must|should)", "deadline"),

        // Requirements
        ("(?:we|i)\\s+(?:need|require|must have)\\s+(.+)", "requirement"),
        ("(?:it|this)\\s+(?:must|should|needs to)\\s+(.+)", "requirement"),
    ]

    // Keywords that indicate important information
    private let importantKeywords = [
        "important", "remember", "note", "key", "crucial", "critical",
        "always", "never", "must", "required", "essential",
        "prefer", "style", "convention", "standard", "rule"
    ]

    /// Extract potential memory entries from a conversation exchange
    func extractMemories(
        userMessage: String,
        assistantResponse: String,
        conversationId: UUID
    ) async -> [MemoryEntry] {
        var memories: [MemoryEntry] = []

        // Extract from user message
        memories.append(contentsOf: extractFromText(
            userMessage,
            conversationId: conversationId,
            source: .conversation
        ))

        // Look for explicit user statements about preferences/facts
        memories.append(contentsOf: extractExplicitFacts(
            userMessage,
            conversationId: conversationId
        ))

        // Deduplicate by key
        var seenKeys = Set<String>()
        memories = memories.filter { entry in
            let normalizedKey = entry.key.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if seenKeys.contains(normalizedKey) {
                return false
            }
            seenKeys.insert(normalizedKey)
            return true
        }

        return memories
    }

    private func extractFromText(
        _ text: String,
        conversationId: UUID,
        source: MemorySource
    ) -> [MemoryEntry] {
        var memories: [MemoryEntry] = []
        let lowercased = text.lowercased()

        for (pattern, key) in factPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(text.startIndex..., in: text)
                let matches = regex.matches(in: text, options: [], range: range)

                for match in matches {
                    if match.numberOfRanges > 1 {
                        let valueRange = match.range(at: 1)
                        if let swiftRange = Range(valueRange, in: text) {
                            let value = String(text[swiftRange])
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                                .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))

                            // Skip very short or very long values
                            guard value.count > 3 && value.count < 200 else { continue }

                            // Calculate confidence based on context
                            let confidence = calculateConfidence(text: lowercased, value: value, key: key)

                            if confidence > 0.5 {
                                let entry = MemoryEntry(
                                    key: formatKey(key, value: value),
                                    value: value,
                                    source: source,
                                    conversationId: conversationId,
                                    confidence: confidence
                                )
                                memories.append(entry)
                            }
                        }
                    }
                }
            }
        }

        return memories
    }

    private func extractExplicitFacts(
        _ text: String,
        conversationId: UUID
    ) -> [MemoryEntry] {
        var memories: [MemoryEntry] = []
        let lowercased = text.lowercased()

        // Check for explicit "remember" commands
        let rememberPatterns = [
            "remember\\s+that\\s+(.+)",
            "please\\s+remember\\s+(.+)",
            "keep\\s+in\\s+mind\\s+(?:that\\s+)?(.+)",
            "note\\s+that\\s+(.+)",
            "important:\\s*(.+)",
        ]

        for pattern in rememberPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(text.startIndex..., in: text)
                let matches = regex.matches(in: text, options: [], range: range)

                for match in matches {
                    if match.numberOfRanges > 1 {
                        let valueRange = match.range(at: 1)
                        if let swiftRange = Range(valueRange, in: text) {
                            let value = String(text[swiftRange])
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                                .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))

                            guard value.count > 5 && value.count < 300 else { continue }

                            let entry = MemoryEntry(
                                key: "User Note",
                                value: value,
                                source: .user,
                                conversationId: conversationId,
                                confidence: 0.9  // High confidence for explicit notes
                            )
                            memories.append(entry)
                        }
                    }
                }
            }
        }

        return memories
    }

    private func calculateConfidence(text: String, value: String, key: String) -> Double {
        var confidence: Double = 0.6  // Base confidence

        // Boost for important keywords
        for keyword in importantKeywords {
            if text.contains(keyword) {
                confidence += 0.1
            }
        }

        // Boost for first-person statements (more likely to be facts)
        if text.contains("i ") || text.contains("we ") || text.contains("my ") || text.contains("our ") {
            confidence += 0.1
        }

        // Reduce confidence for questions
        if text.contains("?") {
            confidence -= 0.2
        }

        // Reduce for hypotheticals
        if text.contains("would") || text.contains("could") || text.contains("might") {
            confidence -= 0.1
        }

        // Boost for specific technical terms
        let techTerms = ["api", "framework", "library", "database", "server", "client", "frontend", "backend"]
        for term in techTerms {
            if value.lowercased().contains(term) {
                confidence += 0.05
            }
        }

        return min(1.0, max(0.0, confidence))
    }

    private func formatKey(_ key: String, value: String) -> String {
        // Create a human-readable key based on the pattern type
        switch key {
        case "preference":
            return "User Preference"
        case "dislike":
            return "User Dislikes"
        case "technology", "tech_stack":
            return "Technology Used"
        case "project_info", "project_goal":
            return "Project Info"
        case "naming", "naming_convention":
            return "Naming Convention"
        case "coding_style":
            return "Coding Style"
        case "architecture":
            return "Architecture Pattern"
        case "team_info":
            return "Team Info"
        case "role_or_company":
            return "Role/Company"
        case "deadline":
            return "Important Date"
        case "requirement":
            return "Requirement"
        default:
            return key.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    /// Filter memories by confidence threshold
    func filterByConfidence(_ memories: [MemoryEntry], threshold: Double = 0.7) -> [MemoryEntry] {
        return memories.filter { ($0.confidence ?? 0) >= threshold }
    }

    /// Merge similar memories, keeping the one with higher confidence
    func deduplicateMemories(_ memories: [MemoryEntry]) -> [MemoryEntry] {
        var result: [MemoryEntry] = []
        var seenValues = Set<String>()

        for memory in memories.sorted(by: { ($0.confidence ?? 0) > ($1.confidence ?? 0) }) {
            let normalizedValue = memory.value.lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Check for similar values (simple Jaccard similarity)
            var isDuplicate = false
            for seen in seenValues {
                if jaccardSimilarity(normalizedValue, seen) > 0.7 {
                    isDuplicate = true
                    break
                }
            }

            if !isDuplicate {
                result.append(memory)
                seenValues.insert(normalizedValue)
            }
        }

        return result
    }

    private func jaccardSimilarity(_ a: String, _ b: String) -> Double {
        let setA = Set(a.components(separatedBy: .whitespaces))
        let setB = Set(b.components(separatedBy: .whitespaces))

        let intersection = setA.intersection(setB).count
        let union = setA.union(setB).count

        return union > 0 ? Double(intersection) / Double(union) : 0
    }
}
