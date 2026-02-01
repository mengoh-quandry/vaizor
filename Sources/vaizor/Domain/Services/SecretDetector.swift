import Foundation

/// Service for detecting and redacting secrets in code output
final class SecretDetector: Sendable {
    static let shared = SecretDetector()
    
    private let patterns: [(pattern: String, name: String)] = [
        // Specific API Keys (must come before generic patterns)
        (#"AKIA[0-9A-Z]{16}"#, "AWS Access Key"),
        (#"sk-[a-zA-Z0-9]{32,}"#, "OpenAI API Key"),
        (#"sk_live_[a-zA-Z0-9]{24,}"#, "Stripe API Key"),
        (#"sk_test_[a-zA-Z0-9]{24,}"#, "Stripe Test Key"),

        // OAuth (must come before generic token pattern)
        (#"oauth_token[=:]\s*([a-zA-Z0-9\-_]{20,})"#, "OAuth Token"),
        (#"oauth_secret[=:]\s*([a-zA-Z0-9\-_]{20,})"#, "OAuth Secret"),

        // Tokens
        (#"token[=:]\s*([a-zA-Z0-9\-_]{20,})"#, "Token"),
        (#"[Bb]earer\s+([a-zA-Z0-9\-_\.]{20,})"#, "Bearer Token"),

        // Private Keys
        (#"-----BEGIN (RSA|EC|OPENSSH|DSA) PRIVATE KEY-----"#, "Private Key"),
        (#"-----BEGIN PGP PRIVATE KEY BLOCK-----"#, "PGP Private Key"),

        // Passwords
        (#"password[=:]\s*([^\s]{8,})"#, "Password"),
        (#"passwd[=:]\s*([^\s]{8,})"#, "Password"),

        // Database URLs
        (#"postgresql://[^\s]+"#, "PostgreSQL URL"),
        (#"mysql://[^\s]+"#, "MySQL URL"),
        (#"mongodb://[^\s]+"#, "MongoDB URL"),

        // Generic API Key (last - catches remaining patterns)
        (#"\b[a-zA-Z0-9]{32,}\b"#, "Generic API Key"),
    ]
    
    private init() {}
    
    /// Detect and redact secrets in text
    func redact(_ text: String) -> (sanitized: String, detected: Bool) {
        var sanitized = text
        var detected = false
        
        for (pattern, name) in patterns {
            let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .anchorsMatchLines])
            let matches = regex?.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text)) ?? []
            
            if !matches.isEmpty {
                detected = true
                
                // Replace matches with [REDACTED: Type]
                for match in matches.reversed() {
                    if let range = Range(match.range, in: sanitized) {
                        sanitized.replaceSubrange(range, with: "[REDACTED: \(name)]")
                    }
                }
            }
        }
        
        return (sanitized, detected)
    }
    
    /// Check if text contains secrets (without redacting)
    func containsSecrets(_ text: String) -> Bool {
        for (pattern, _) in patterns {
            if text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                return true
            }
        }
        return false
    }
}
