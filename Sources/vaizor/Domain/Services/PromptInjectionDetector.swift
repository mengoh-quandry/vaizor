import Foundation
import SwiftUI

/// Severity level for detected prompt injection attempts
enum InjectionSeverity: String, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"
}

/// Result of prompt injection analysis
struct InjectionAnalysisResult {
    let isClean: Bool
    let detectedPatterns: [DetectedInjection]
    let sanitizedText: String
    let highestSeverity: InjectionSeverity?

    var requiresUserConfirmation: Bool {
        guard let severity = highestSeverity else { return false }
        return severity == .high || severity == .critical
    }
}

/// Details about a detected injection attempt
struct DetectedInjection: Identifiable {
    let id = UUID()
    let patternName: String
    let matchedText: String
    let severity: InjectionSeverity
    let range: Range<String.Index>
}

/// Service for detecting and mitigating prompt injection attacks
@MainActor
final class PromptInjectionDetector: ObservableObject {
    static let shared = PromptInjectionDetector()

    @AppStorage("injection_detection_enabled") var isEnabled: Bool = true
    @AppStorage("injection_block_critical") var blockCritical: Bool = true
    @AppStorage("injection_warn_high") var warnOnHigh: Bool = true

    /// Patterns for detecting prompt injection attempts
    private let detectionPatterns: [(name: String, pattern: String, severity: InjectionSeverity)] = [
        // Critical: Direct instruction override attempts
        ("System prompt override", #"(?i)(ignore|disregard|forget)\s+(all\s+)?(previous|prior|above|earlier)\s+(instructions?|prompts?|rules?|guidelines?)"#, .critical),
        ("Role hijacking", #"(?i)you\s+are\s+now\s+(a|an|acting\s+as|pretending\s+to\s+be)"#, .critical),
        ("New persona injection", #"(?i)(from\s+now\s+on|starting\s+now|henceforth),?\s+(you\s+are|act\s+as|behave\s+as|pretend)"#, .critical),
        ("Jailbreak marker", #"(?i)(DAN|jailbreak|developer\s+mode|chaos\s+mode|evil\s+mode)"#, .critical),
        ("System message spoof", #"(?i)\[\s*(system|admin|root|developer)\s*\]"#, .critical),

        // High: Manipulation attempts
        ("Instruction injection", #"(?i)(new\s+instructions?|updated?\s+instructions?|override\s+instructions?):"#, .high),
        ("Role escape attempt", #"(?i)(end\s+of\s+system\s+prompt|</system>|---\s*end\s*---)"#, .high),
        ("Context manipulation", #"(?i)(actual\s+task|real\s+instructions?|true\s+purpose|secret\s+mode)"#, .high),
        ("Authority claim", #"(?i)(as\s+(your|the)\s+(creator|developer|admin|administrator)|i\s+am\s+(your\s+)?(creator|admin|developer))"#, .high),
        ("Hypothetical bypass", #"(?i)(hypothetically|in\s+theory|if\s+you\s+were\s+able\s+to|imagine\s+you\s+could)"#, .high),
        ("Output format manipulation", #"(?i)(respond\s+only\s+with|output\s+format|your\s+response\s+must\s+(only\s+)?be)"#, .high),

        // Medium: Suspicious patterns
        ("Base64 payload", #"(?i)(base64|decode|encode)\s*[:\(]"#, .medium),
        ("Encoded instructions", #"[A-Za-z0-9+/]{50,}={0,2}"#, .medium), // Long base64-like strings
        ("Delimiter injection", #"(?i)(```system|```instruction|<\|im_start\|>|<\|endoftext\|>)"#, .medium),
        ("Unicode obfuscation", #"[\u200B-\u200D\uFEFF]"#, .medium), // Zero-width characters
        ("Repeat bypass", #"(?i)(repeat\s+after\s+me|say\s+exactly|echo\s+back)"#, .medium),
        ("Indirect instruction", #"(?i)(tell\s+me\s+your\s+(system\s+)?prompt|what\s+are\s+your\s+instructions|reveal\s+your\s+rules)"#, .medium),

        // Low: Potentially suspicious but could be legitimate
        ("Prompt reference", #"(?i)(system\s+prompt|initial\s+prompt|original\s+instructions)"#, .low),
        ("Roleplay request", #"(?i)(pretend\s+(to\s+be|you\s+are)|act\s+as\s+if|roleplay\s+as)"#, .low),
        ("Boundary probing", #"(?i)(what\s+can('t)?\s+you\s+do|your\s+limitations|your\s+restrictions)"#, .low),
    ]

    private init() {}

    // MARK: - Detection

    /// Analyze text for prompt injection attempts
    func analyze(_ text: String) -> InjectionAnalysisResult {
        guard isEnabled else {
            return InjectionAnalysisResult(
                isClean: true,
                detectedPatterns: [],
                sanitizedText: text,
                highestSeverity: nil
            )
        }

        var detectedInjections: [DetectedInjection] = []

        for (name, pattern, severity) in detectionPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
                continue
            }

            let range = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, options: [], range: range)

            for match in matches {
                if let matchRange = Range(match.range, in: text) {
                    let matchedText = String(text[matchRange])
                    detectedInjections.append(DetectedInjection(
                        patternName: name,
                        matchedText: matchedText,
                        severity: severity,
                        range: matchRange
                    ))
                }
            }
        }

        // Sort by severity (critical first)
        detectedInjections.sort { severityOrder($0.severity) > severityOrder($1.severity) }

        let highestSeverity = detectedInjections.first?.severity
        let isClean = detectedInjections.isEmpty

        // Create sanitized text (remove zero-width characters and normalize)
        var sanitizedText = text
        sanitizedText = sanitizedText.replacingOccurrences(of: "[\u{200B}-\u{200D}\u{FEFF}]", with: "", options: .regularExpression)

        return InjectionAnalysisResult(
            isClean: isClean,
            detectedPatterns: detectedInjections,
            sanitizedText: sanitizedText,
            highestSeverity: highestSeverity
        )
    }

    /// Check if text should be blocked based on settings
    func shouldBlock(_ result: InjectionAnalysisResult) -> Bool {
        guard let severity = result.highestSeverity else { return false }
        return blockCritical && severity == .critical
    }

    /// Get user-friendly warning message for detected injections
    func warningMessage(for result: InjectionAnalysisResult) -> String? {
        guard !result.isClean else { return nil }

        let patterns = result.detectedPatterns.map { $0.patternName }
        let uniquePatterns = Array(Set(patterns))

        if result.highestSeverity == .critical {
            return "Critical: Potential prompt injection detected (\(uniquePatterns.joined(separator: ", "))). This message may be attempting to manipulate the AI's behavior."
        } else if result.highestSeverity == .high {
            return "Warning: Suspicious patterns detected (\(uniquePatterns.joined(separator: ", "))). Please review before sending."
        }

        return nil
    }

    // MARK: - Helpers

    private func severityOrder(_ severity: InjectionSeverity) -> Int {
        switch severity {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .critical: return 4
        }
    }
}

// MARK: - Code Execution Security Hardening

/// Enhanced code validation for execution safety
struct CodeSecurityValidator {

    /// Dangerous patterns that should block execution
    private static let blockingPatterns: [(name: String, pattern: String, languages: Set<String>)] = [
        // System access
        ("OS command execution", #"(?i)(os\.system|subprocess\.(call|run|Popen)|child_process|shelljs)"#, ["python", "javascript", "typescript"]),
        ("Process spawning", #"(?i)(spawn|fork|exec(v|ve|vp|l|le|lp)?)\s*\("#, ["python", "javascript", "c", "cpp"]),

        // Code injection
        ("Dynamic code execution", #"(?i)(eval|exec|compile|ast\.literal_eval)\s*\("#, ["python"]),
        ("JavaScript eval", #"(?i)(eval|Function|setTimeout|setInterval)\s*\(\s*['\"`]"#, ["javascript", "typescript"]),

        // Import manipulation
        ("Dynamic import", #"(?i)(__import__|importlib|__builtins__|globals\(\))"#, ["python"]),
        ("Require bypass", #"(?i)(require\s*\(\s*['\"]child_process|require\.resolve)"#, ["javascript"]),

        // File system danger
        ("Root path access", #"(?i)(open|read|write)\s*\(\s*['\"]/"#, ["python", "javascript"]),
        ("Path traversal", #"\.\./|\.\.\\"#, ["python", "javascript", "shell"]),
        ("Sensitive paths", #"(?i)(/etc/passwd|/etc/shadow|\.ssh/|\.aws/|\.env)"#, ["python", "javascript", "shell"]),

        // Network danger
        ("Socket creation", #"(?i)(socket\.socket|net\.createServer|dgram\.createSocket)"#, ["python", "javascript"]),
        ("Reverse shell patterns", #"(?i)(bash\s+-i|/dev/tcp/|nc\s+-e|python\s+-c.*socket)"#, ["python", "shell"]),

        // System modification
        ("Environment manipulation", #"(?i)(os\.environ|process\.env)\s*\["#, ["python", "javascript"]),
        ("Module path modification", #"(?i)(sys\.path\.(insert|append)|NODE_PATH)"#, ["python", "javascript"]),

        // Pickle/serialization attacks
        ("Pickle deserialization", #"(?i)(pickle\.(loads?|Unpickler)|cPickle)"#, ["python"]),
        ("YAML unsafe load", #"(?i)(yaml\.(load|unsafe_load)\s*\()"#, ["python"]),

        // Shell injection
        ("Shell metacharacters", #"[;&|`$]"#, ["shell"]),
        ("Command substitution", #"\$\(|\`[^`]+\`"#, ["shell"]),
    ]

    /// Warning patterns that should prompt user confirmation
    private static let warningPatterns: [(name: String, pattern: String, languages: Set<String>)] = [
        ("File operations", #"(?i)(open\s*\(|read|write|unlink|remove|mkdir|rmdir)"#, ["python", "javascript"]),
        ("Network requests", #"(?i)(requests\.|urllib|fetch|axios|http\.get)"#, ["python", "javascript"]),
        ("External process", #"(?i)(subprocess|child_process|spawn)"#, ["python", "javascript"]),
        ("Database access", #"(?i)(sqlite3|psycopg|mysql|pymongo|mongoose)"#, ["python", "javascript"]),
        ("Crypto operations", #"(?i)(hashlib|cryptography|crypto|bcrypt)"#, ["python", "javascript"]),
    ]

    struct ValidationResult {
        let isBlocked: Bool
        let blockedReasons: [String]
        let warnings: [String]
        let requiresConfirmation: Bool
    }

    /// Validate code for dangerous patterns
    static func validate(code: String, language: String) -> ValidationResult {
        let lang = language.lowercased()
        var blockedReasons: [String] = []
        var warnings: [String] = []

        // Check blocking patterns
        for (name, pattern, languages) in blockingPatterns {
            guard languages.contains(lang) || languages.contains("shell") else { continue }

            if code.range(of: pattern, options: .regularExpression) != nil {
                blockedReasons.append(name)
            }
        }

        // Check warning patterns
        for (name, pattern, languages) in warningPatterns {
            guard languages.contains(lang) else { continue }

            if code.range(of: pattern, options: .regularExpression) != nil {
                warnings.append(name)
            }
        }

        return ValidationResult(
            isBlocked: !blockedReasons.isEmpty,
            blockedReasons: blockedReasons,
            warnings: warnings,
            requiresConfirmation: !warnings.isEmpty && blockedReasons.isEmpty
        )
    }

    /// Sanitize code by removing dangerous constructs
    static func sanitize(code: String) -> String {
        var sanitized = code

        // Remove zero-width characters
        sanitized = sanitized.replacingOccurrences(of: "[\u{200B}-\u{200D}\u{FEFF}]", with: "", options: .regularExpression)

        // Normalize line endings
        sanitized = sanitized.replacingOccurrences(of: "\r\n", with: "\n")
        sanitized = sanitized.replacingOccurrences(of: "\r", with: "\n")

        return sanitized
    }
}
