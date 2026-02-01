import Foundation
import SwiftUI

/// A pattern configuration for sensitive data detection
struct RedactionPattern: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var pattern: String
    var isEnabled: Bool
    var isBuiltIn: Bool

    init(id: UUID = UUID(), name: String, pattern: String, isEnabled: Bool = true, isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.pattern = pattern
        self.isEnabled = isEnabled
        self.isBuiltIn = isBuiltIn
    }
}

/// Result of a redaction operation containing the sanitized text and mapping for restoration
struct RedactionResult {
    let sanitizedText: String
    let redactionMap: [String: String] // placeholder -> original value
    let detectedPatterns: [String] // names of patterns that matched

    var hasRedactions: Bool {
        !redactionMap.isEmpty
    }
}

/// Service for detecting, redacting, and restoring sensitive data
@MainActor
final class DataRedactor: ObservableObject {
    static let shared = DataRedactor()

    /// Built-in patterns for common sensitive data
    private static let builtInPatterns: [RedactionPattern] = [
        // API Keys
        RedactionPattern(name: "AWS Access Key", pattern: #"AKIA[0-9A-Z]{16}"#, isBuiltIn: true),
        RedactionPattern(name: "OpenAI API Key", pattern: #"sk-[a-zA-Z0-9]{32,}"#, isBuiltIn: true),
        RedactionPattern(name: "Anthropic API Key", pattern: #"sk-ant-[a-zA-Z0-9\-]{32,}"#, isBuiltIn: true),
        RedactionPattern(name: "Stripe API Key", pattern: #"sk_live_[a-zA-Z0-9]{24,}"#, isBuiltIn: true),
        RedactionPattern(name: "GitHub Token", pattern: #"gh[pousr]_[A-Za-z0-9_]{36,}"#, isBuiltIn: true),
        RedactionPattern(name: "Google API Key", pattern: #"AIza[0-9A-Za-z\-_]{35}"#, isBuiltIn: true),

        // Tokens
        RedactionPattern(name: "Bearer Token", pattern: #"[Bb]earer\s+([a-zA-Z0-9\-_\.]{20,})"#, isBuiltIn: true),
        RedactionPattern(name: "JWT Token", pattern: #"eyJ[a-zA-Z0-9\-_]+\.eyJ[a-zA-Z0-9\-_]+\.[a-zA-Z0-9\-_]+"#, isBuiltIn: true),

        // Private Keys
        RedactionPattern(name: "RSA Private Key", pattern: #"-----BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----"#, isBuiltIn: true),
        RedactionPattern(name: "PGP Private Key", pattern: #"-----BEGIN PGP PRIVATE KEY BLOCK-----"#, isBuiltIn: true),

        // Passwords
        RedactionPattern(name: "Password in Config", pattern: #"(?i)(password|passwd|pwd)\s*[=:]\s*['\"]?([^\s'\"]{8,})['\"]?"#, isBuiltIn: true),
        RedactionPattern(name: "Secret in Config", pattern: #"(?i)(secret|api_secret)\s*[=:]\s*['\"]?([^\s'\"]{8,})['\"]?"#, isBuiltIn: true),

        // Database URLs
        RedactionPattern(name: "PostgreSQL URL", pattern: #"postgres(ql)?://[^\s]+"#, isBuiltIn: true),
        RedactionPattern(name: "MySQL URL", pattern: #"mysql://[^\s]+"#, isBuiltIn: true),
        RedactionPattern(name: "MongoDB URL", pattern: #"mongodb(\+srv)?://[^\s]+"#, isBuiltIn: true),
        RedactionPattern(name: "Redis URL", pattern: #"redis://[^\s]+"#, isBuiltIn: true),

        // Personal Information
        RedactionPattern(name: "Email Address", pattern: #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#, isEnabled: false, isBuiltIn: true),
        RedactionPattern(name: "Phone Number (US)", pattern: #"\b\d{3}[-.]?\d{3}[-.]?\d{4}\b"#, isEnabled: false, isBuiltIn: true),
        RedactionPattern(name: "SSN", pattern: #"\b\d{3}-\d{2}-\d{4}\b"#, isBuiltIn: true),
        RedactionPattern(name: "Credit Card", pattern: #"\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b"#, isBuiltIn: true),

        // IP Addresses
        RedactionPattern(name: "IPv4 Address", pattern: #"\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b"#, isEnabled: false, isBuiltIn: true),
    ]

    /// All patterns (built-in + user-defined)
    @Published var patterns: [RedactionPattern] = []

    /// Whether redaction is enabled globally
    @AppStorage("redaction_enabled") var isRedactionEnabled: Bool = true

    /// Counter for generating unique placeholders
    private var placeholderCounter: Int = 0

    private init() {
        loadPatterns()
    }

    // MARK: - Pattern Management

    /// Load patterns from storage
    func loadPatterns() {
        // Start with built-in patterns
        var allPatterns = Self.builtInPatterns

        // Load user-defined patterns from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "user_redaction_patterns"),
           let userPatterns = try? JSONDecoder().decode([RedactionPattern].self, from: data) {
            allPatterns.append(contentsOf: userPatterns)
        }

        // Load enabled states for built-in patterns
        if let data = UserDefaults.standard.data(forKey: "builtin_pattern_states"),
           let states = try? JSONDecoder().decode([UUID: Bool].self, from: data) {
            for i in 0..<allPatterns.count where allPatterns[i].isBuiltIn {
                if let isEnabled = states[allPatterns[i].id] {
                    allPatterns[i].isEnabled = isEnabled
                }
            }
        }

        patterns = allPatterns
    }

    /// Save patterns to storage
    func savePatterns() {
        // Save user-defined patterns
        let userPatterns = patterns.filter { !$0.isBuiltIn }
        if let data = try? JSONEncoder().encode(userPatterns) {
            UserDefaults.standard.set(data, forKey: "user_redaction_patterns")
        }

        // Save enabled states for built-in patterns
        var states: [UUID: Bool] = [:]
        for pattern in patterns where pattern.isBuiltIn {
            states[pattern.id] = pattern.isEnabled
        }
        if let data = try? JSONEncoder().encode(states) {
            UserDefaults.standard.set(data, forKey: "builtin_pattern_states")
        }
    }

    /// Add a new user-defined pattern
    func addPattern(name: String, pattern: String) {
        let newPattern = RedactionPattern(name: name, pattern: pattern, isBuiltIn: false)
        patterns.append(newPattern)
        savePatterns()
    }

    /// Remove a user-defined pattern
    func removePattern(_ pattern: RedactionPattern) {
        guard !pattern.isBuiltIn else { return }
        patterns.removeAll { $0.id == pattern.id }
        savePatterns()
    }

    /// Toggle a pattern's enabled state
    func togglePattern(_ pattern: RedactionPattern) {
        if let index = patterns.firstIndex(where: { $0.id == pattern.id }) {
            patterns[index].isEnabled.toggle()
            savePatterns()
        }
    }

    // MARK: - Redaction

    /// Redact sensitive data from text
    func redact(_ text: String) -> RedactionResult {
        guard isRedactionEnabled else {
            return RedactionResult(sanitizedText: text, redactionMap: [:], detectedPatterns: [])
        }

        var sanitizedText = text
        var redactionMap: [String: String] = [:]
        var detectedPatterns: [String] = []
        placeholderCounter = 0

        // Process each enabled pattern
        for pattern in patterns where pattern.isEnabled {
            guard let regex = try? NSRegularExpression(pattern: pattern.pattern, options: [.caseInsensitive]) else {
                continue
            }

            let range = NSRange(sanitizedText.startIndex..., in: sanitizedText)
            let matches = regex.matches(in: sanitizedText, options: [], range: range)

            if !matches.isEmpty && !detectedPatterns.contains(pattern.name) {
                detectedPatterns.append(pattern.name)
            }

            // Process matches in reverse to maintain correct ranges
            for match in matches.reversed() {
                if let matchRange = Range(match.range, in: sanitizedText) {
                    let originalValue = String(sanitizedText[matchRange])
                    let placeholder = generatePlaceholder(for: pattern.name)

                    redactionMap[placeholder] = originalValue
                    sanitizedText.replaceSubrange(matchRange, with: placeholder)
                }
            }
        }

        return RedactionResult(
            sanitizedText: sanitizedText,
            redactionMap: redactionMap,
            detectedPatterns: detectedPatterns
        )
    }

    /// Check if text contains sensitive data (without redacting)
    func containsSensitiveData(_ text: String) -> Bool {
        guard isRedactionEnabled else { return false }

        for pattern in patterns where pattern.isEnabled {
            if text.range(of: pattern.pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                return true
            }
        }
        return false
    }

    // MARK: - Restoration

    /// Restore original values in LLM response using redaction map
    func restore(_ response: String, using redactionMap: [String: String]) -> String {
        var restoredResponse = response

        for (placeholder, originalValue) in redactionMap {
            // Replace all occurrences of the placeholder with the original value
            restoredResponse = restoredResponse.replacingOccurrences(of: placeholder, with: originalValue)
        }

        return restoredResponse
    }

    // MARK: - Private Helpers

    private func generatePlaceholder(for patternName: String) -> String {
        placeholderCounter += 1
        let shortName = patternName
            .replacingOccurrences(of: " ", with: "_")
            .uppercased()
            .prefix(12)
        return "[REDACTED_\(shortName)_\(placeholderCounter)]"
    }
}

// MARK: - Redaction Context for Message Flow

/// Context object passed through the message flow to track redaction state
class RedactionContext {
    var redactionMap: [String: String] = [:]
    var wasRedacted: Bool { !redactionMap.isEmpty }

    func merge(_ result: RedactionResult) {
        for (key, value) in result.redactionMap {
            redactionMap[key] = value
        }
    }
}
