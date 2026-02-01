import Foundation
import SwiftUI
import OSLog

// MARK: - Core Types

/// Threat severity level for security events
enum ThreatLevel: String, Codable, CaseIterable, Comparable {
    case normal = "Normal"
    case elevated = "Elevated"
    case high = "High"
    case critical = "Critical"

    var color: Color {
        switch self {
        case .normal: return .green
        case .elevated: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }

    var icon: String {
        switch self {
        case .normal: return "checkmark.shield"
        case .elevated: return "exclamationmark.shield"
        case .high: return "exclamationmark.triangle"
        case .critical: return "xmark.shield"
        }
    }

    var numericValue: Int {
        switch self {
        case .normal: return 0
        case .elevated: return 1
        case .high: return 2
        case .critical: return 3
        }
    }

    static func < (lhs: ThreatLevel, rhs: ThreatLevel) -> Bool {
        lhs.numericValue < rhs.numericValue
    }
}

/// Types of security alerts
enum AlertType: String, Codable, CaseIterable {
    case promptInjection = "Prompt Injection"
    case dataExfiltration = "Data Exfiltration"
    case maliciousCode = "Malicious Code"
    case jailbreakAttempt = "Jailbreak Attempt"
    case sensitiveDataExposure = "Sensitive Data Exposure"
    case hostVulnerability = "Host Vulnerability"
    case anomalousActivity = "Anomalous Activity"
    case suspiciousUrl = "Suspicious URL"
    case credentialLeak = "Credential Leak"
    case encodedPayload = "Encoded Payload"
    case socialEngineering = "Social Engineering"

    var icon: String {
        switch self {
        case .promptInjection: return "text.badge.xmark"
        case .dataExfiltration: return "arrow.up.doc"
        case .maliciousCode: return "ladybug"
        case .jailbreakAttempt: return "lock.open.trianglebadge.exclamationmark"
        case .sensitiveDataExposure: return "eye.trianglebadge.exclamationmark"
        case .hostVulnerability: return "desktopcomputer.trianglebadge.exclamationmark"
        case .anomalousActivity: return "waveform.path.ecg"
        case .suspiciousUrl: return "link.badge.plus"
        case .credentialLeak: return "key.horizontal"
        case .encodedPayload: return "doc.text.magnifyingglass"
        case .socialEngineering: return "person.badge.shield.checkmark.fill"
        }
    }
}

/// Security alert for detected threats
struct SecurityAlert: Identifiable, Codable {
    let id: UUID
    let type: AlertType
    let severity: ThreatLevel
    let message: String
    let timestamp: Date
    let source: AlertSource
    let matchedPatterns: [String]
    let affectedContent: String
    var isAcknowledged: Bool
    var mitigationApplied: Bool

    init(
        id: UUID = UUID(),
        type: AlertType,
        severity: ThreatLevel,
        message: String,
        timestamp: Date = Date(),
        source: AlertSource,
        matchedPatterns: [String] = [],
        affectedContent: String = "",
        isAcknowledged: Bool = false,
        mitigationApplied: Bool = false
    ) {
        self.id = id
        self.type = type
        self.severity = severity
        self.message = message
        self.timestamp = timestamp
        self.source = source
        self.matchedPatterns = matchedPatterns
        self.affectedContent = affectedContent
        self.isAcknowledged = isAcknowledged
        self.mitigationApplied = mitigationApplied
    }
}

/// Source of the alert
enum AlertSource: String, Codable {
    case userPrompt = "User Prompt"
    case modelResponse = "Model Response"
    case hostSystem = "Host System"
    case networkActivity = "Network Activity"
    case toolExecution = "Tool Execution"
}

/// Result of threat analysis
struct ThreatAnalysis: Codable {
    let isClean: Bool
    let threatLevel: ThreatLevel
    let alerts: [SecurityAlert]
    let confidence: Double // 0.0 to 1.0
    let sanitizedContent: String?
    let recommendations: [String]

    var requiresBlocking: Bool {
        threatLevel == .critical && confidence > 0.8
    }

    var requiresUserConfirmation: Bool {
        (threatLevel == .high && confidence > 0.7) || (threatLevel == .critical && confidence <= 0.8)
    }
}

// MARK: - Audit Logging

/// Entry type for audit logs
enum AuditEventType: String, Codable {
    case conversationStart = "Conversation Start"
    case conversationEnd = "Conversation End"
    case messageSent = "Message Sent"
    case messageReceived = "Message Received"
    case threatDetected = "Threat Detected"
    case threatMitigated = "Threat Mitigated"
    case toolExecution = "Tool Execution"
    case securitySettingChanged = "Security Setting Changed"
    case hostSecurityCheck = "Host Security Check"
    case dataRedaction = "Data Redaction"
    case alertAcknowledged = "Alert Acknowledged"
    case exportRequested = "Export Requested"
}

/// Audit log entry
struct AuditEntry: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let eventType: AuditEventType
    let description: String
    let conversationId: UUID?
    let messageId: UUID?
    let userId: String?
    let severity: ThreatLevel
    let metadata: [String: String]

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        eventType: AuditEventType,
        description: String,
        conversationId: UUID? = nil,
        messageId: UUID? = nil,
        userId: String? = nil,
        severity: ThreatLevel = .normal,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.eventType = eventType
        self.description = description
        self.conversationId = conversationId
        self.messageId = messageId
        self.userId = userId
        self.severity = severity
        self.metadata = metadata
    }
}

// MARK: - Host Security Types

/// Information about a running process
struct ProcessInfo: Identifiable, Codable {
    let id: UUID
    let pid: Int32
    let name: String
    let path: String
    let user: String
    let cpuUsage: Double
    let memoryUsage: UInt64
    let isSuspicious: Bool
    let reason: String?

    init(
        id: UUID = UUID(),
        pid: Int32,
        name: String,
        path: String = "",
        user: String = "",
        cpuUsage: Double = 0,
        memoryUsage: UInt64 = 0,
        isSuspicious: Bool = false,
        reason: String? = nil
    ) {
        self.id = id
        self.pid = pid
        self.name = name
        self.path = path
        self.user = user
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
        self.isSuspicious = isSuspicious
        self.reason = reason
    }
}

/// Information about an open network port
struct PortInfo: Identifiable, Codable {
    let id: UUID
    let port: UInt16
    let `protocol`: String
    let processName: String
    let pid: Int32
    let isSuspicious: Bool

    init(
        id: UUID = UUID(),
        port: UInt16,
        protocol: String,
        processName: String,
        pid: Int32,
        isSuspicious: Bool = false
    ) {
        self.id = id
        self.port = port
        self.protocol = `protocol`
        self.processName = processName
        self.pid = pid
        self.isSuspicious = isSuspicious
    }
}

/// Security event from macOS
struct SecurityEvent: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let eventType: String
    let description: String
    let severity: ThreatLevel

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        eventType: String,
        description: String,
        severity: ThreatLevel = .normal
    ) {
        self.id = id
        self.timestamp = timestamp
        self.eventType = eventType
        self.description = description
        self.severity = severity
    }
}

/// Complete host security report
struct HostSecurityReport: Codable {
    let timestamp: Date
    var firewallEnabled: Bool
    var diskEncrypted: Bool
    var gatekeeperEnabled: Bool
    var systemIntegrityProtection: Bool
    var suspiciousProcesses: [ProcessInfo]
    var openPorts: [PortInfo]
    var recentSecurityEvents: [SecurityEvent]
    var overallThreatLevel: ThreatLevel
    var recommendations: [String]

    init(
        timestamp: Date = Date(),
        firewallEnabled: Bool = false,
        diskEncrypted: Bool = false,
        gatekeeperEnabled: Bool = false,
        systemIntegrityProtection: Bool = false,
        suspiciousProcesses: [ProcessInfo] = [],
        openPorts: [PortInfo] = [],
        recentSecurityEvents: [SecurityEvent] = [],
        overallThreatLevel: ThreatLevel = .normal,
        recommendations: [String] = []
    ) {
        self.timestamp = timestamp
        self.firewallEnabled = firewallEnabled
        self.diskEncrypted = diskEncrypted
        self.gatekeeperEnabled = gatekeeperEnabled
        self.systemIntegrityProtection = systemIntegrityProtection
        self.suspiciousProcesses = suspiciousProcesses
        self.openPorts = openPorts
        self.recentSecurityEvents = recentSecurityEvents
        self.overallThreatLevel = overallThreatLevel
        self.recommendations = recommendations
    }
}

// MARK: - AiEDR Service

/// AI Endpoint Detection & Response Service
@MainActor
final class AiEDRService: ObservableObject {
    static let shared = AiEDRService()

    // MARK: - Published State

    @Published var threatLevel: ThreatLevel = .normal
    @Published var activeAlerts: [SecurityAlert] = []
    @Published var auditLog: [AuditEntry] = []
    @Published var lastHostSecurityReport: HostSecurityReport?
    @Published var isMonitoringEnabled: Bool = true
    @Published var totalBlockedThreats: Int = 0
    @Published var totalDetectedThreats: Int = 0

    // MARK: - Settings

    @AppStorage("aiedr_enabled") var isEnabled: Bool = true
    @AppStorage("aiedr_auto_block_critical") var autoBlockCritical: Bool = true
    @AppStorage("aiedr_prompt_on_high") var promptOnHigh: Bool = true
    @AppStorage("aiedr_log_threats_only") var logThreatsOnly: Bool = true  // Only log when threats detected, not all messages
    @AppStorage("aiedr_background_monitoring") var backgroundMonitoring: Bool = false
    @AppStorage("aiedr_max_audit_entries") var maxAuditEntries: Int = 10000

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "com.vaizor.aiedr", category: "security")
    private var backgroundMonitorTask: Task<Void, Never>?
    private let auditQueue = DispatchQueue(label: "com.vaizor.aiedr.audit", qos: .utility)

    // MARK: - Detection Patterns

    /// Jailbreak attempt patterns
    private let jailbreakPatterns: [(name: String, pattern: String, severity: ThreatLevel)] = [
        ("DAN Mode", #"(?i)(DAN|Do\s+Anything\s+Now)"#, .critical),
        ("Developer Mode", #"(?i)developer\s+mode\s+(enabled|activated|on)"#, .critical),
        ("Evil Mode", #"(?i)(evil\s+mode|chaos\s+mode|unrestricted\s+mode)"#, .critical),
        ("Jailbreak Keyword", #"(?i)\bjailbreak\b"#, .high),
        ("Roleplay Exploit", #"(?i)(pretend|imagine|roleplay)\s+(you\s+)?(are|have)\s+no\s+(restrictions|limits|rules)"#, .high),
        ("Persona Override", #"(?i)you\s+are\s+now\s+a\s+(different|new|unrestricted)"#, .high),
        ("Filter Bypass", #"(?i)(bypass|disable|ignore|turn\s+off)\s+(your\s+)?(filters?|safety|guardrails?)"#, .critical),
        ("Opposite Day", #"(?i)opposite\s+day|opposite\s+mode"#, .high),
        ("God Mode", #"(?i)\bgod\s+mode\b"#, .critical),
        ("Admin Override", #"(?i)(admin|root|sudo)\s+(access|override|mode)"#, .high),
    ]

    /// Data exfiltration patterns
    private let exfiltrationPatterns: [(name: String, pattern: String, severity: ThreatLevel)] = [
        ("URL Data Send", #"(?i)(send|post|transmit|upload)\s+(data\s+)?(to|via)\s+(https?://|ftp://)"#, .critical),
        ("Webhook Exfil", #"(?i)(webhook|discord\.com/api/webhooks|slack\.com/api)"#, .high),
        ("Email Exfil", #"(?i)(email|send\s+mail)\s+(to|this)\s+[a-zA-Z0-9._%+-]+@"#, .high),
        ("Base64 Output Request", #"(?i)(output|return|give)\s+(as\s+)?base64"#, .elevated),
        ("Hex Encode Request", #"(?i)(output|encode|convert)\s+(as\s+|to\s+)?hex(adecimal)?"#, .elevated),
        ("Steganography", #"(?i)(hide|embed)\s+(data|text|message)\s+(in|within)\s+(image|audio|video)"#, .high),
        ("External API Call", #"(?i)(call|invoke|request)\s+external\s+api"#, .elevated),
    ]

    /// Instruction override patterns
    private let overridePatterns: [(name: String, pattern: String, severity: ThreatLevel)] = [
        ("Ignore Instructions", #"(?i)(ignore|disregard|forget)\s+(all\s+)?(previous|prior|above|system)"#, .critical),
        ("New Instructions", #"(?i)(new|updated|real)\s+instructions?:"#, .high),
        ("System Prompt Leak", #"(?i)(reveal|show|tell|output)\s+(your\s+)?(system\s+prompt|instructions|rules)"#, .high),
        ("Context Window Attack", #"(?i)(context\s+window|token\s+limit)\s+(overflow|attack)"#, .critical),
        ("Prompt Injection Marker", #"(?i)(</?(system|instruction|prompt)>|\[INST\]|\[/INST\])"#, .high),
        ("Authority Claim", #"(?i)(i\s+am|as)\s+(your\s+)?(creator|developer|admin|anthropic|openai)"#, .high),
        ("End System Prompt", #"(?i)(end\s+of\s+system|system\s+prompt\s+end|---\s*end)"#, .high),
    ]

    /// Malicious code patterns in responses
    private let maliciousCodePatterns: [(name: String, pattern: String, severity: ThreatLevel)] = [
        ("Shell Injection", #"(?i)(;\s*rm\s+-rf|;\s*dd\s+if=|;\s*mkfs|&&\s*rm\s+-rf)"#, .critical),
        ("Destructive Command", #"(?i)\brm\s+-rf\s+/"#, .critical),  // rm -rf / or rm -rf /path
        ("Reverse Shell", #"(?i)(bash\s+-i|nc\s+-e|/dev/tcp/|python\s+-c.*socket)"#, .critical),
        ("Privilege Escalation", #"(?i)(sudo\s+chmod\s+777|chmod\s+\+s|setuid)"#, .high),
        ("Keylogger Pattern", #"(?i)(keylog|keyboard\s*hook|input\s*capture)"#, .critical),
        ("Ransomware Pattern", #"(?i)(encrypt.*files.*ransom|bitcoin.*wallet.*decrypt)"#, .critical),
        ("Cryptominer", #"(?i)(xmrig|coinhive|cryptonight|stratum\+tcp)"#, .high),
        ("Data Destruction", #"(?i)(shred|wipe|destroy)\s+(all\s+)?(data|files|disk)"#, .critical),
        ("Fork Bomb", #":\(\)\s*\{\s*:\s*\|\s*:\s*&\s*\}\s*;"#, .critical),
        ("Disk Wipe", #"(?i)dd\s+if=/dev/(zero|random)\s+of=/dev/"#, .critical),
    ]

    /// Credential/API key patterns
    private let credentialPatterns: [(name: String, pattern: String)] = [
        ("AWS Access Key", #"AKIA[0-9A-Z]{16}"#),
        ("AWS Secret Key", #"(?i)aws.{0,20}['\"][0-9a-zA-Z/+]{40}['\"]"#),
        ("OpenAI API Key", #"sk-[a-zA-Z0-9]{32,}"#),
        ("Anthropic API Key", #"sk-ant-[a-zA-Z0-9\-]{32,}"#),
        ("GitHub Token", #"gh[pousr]_[A-Za-z0-9_]{36,}"#),
        ("Google API Key", #"AIza[0-9A-Za-z\-_]{35}"#),
        ("Stripe Key", #"sk_live_[a-zA-Z0-9]{24,}"#),
        ("Private Key Header", #"-----BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----"#),
        ("JWT Token", #"eyJ[a-zA-Z0-9\-_]+\.eyJ[a-zA-Z0-9\-_]+\.[a-zA-Z0-9\-_]+"#),
        ("Generic Password", #"(?i)(password|passwd|pwd)\s*[=:]\s*['\"]?[^\s'\"]{8,}['\"]?"#),
        ("Database URL", #"(?i)(postgres|mysql|mongodb|redis)://[^\s]+"#),
    ]

    /// Suspicious URL patterns
    private let suspiciousUrlPatterns: [(name: String, pattern: String, severity: ThreatLevel)] = [
        ("Raw IP URL", #"https?://\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}"#, .elevated),
        ("Non-standard Port", #"https?://[^/]+:\d{5,}"#, .elevated),
        ("Known Malicious TLD", #"(?i)https?://[^/]+\.(tk|ml|ga|cf|gq|top|xyz|pw|cc)\b"#, .high),
        ("Data URL", #"data:(text|application)/[^,]+;base64,"#, .elevated),
        ("URL Shortener", #"(?i)(bit\.ly|tinyurl|t\.co|goo\.gl|ow\.ly|is\.gd)"#, .elevated),
        ("Pastebin/Hastebin", #"(?i)(pastebin\.com|hastebin\.com|paste\.ee)"#, .elevated),
    ]

    /// Social engineering patterns
    private let socialEngineeringPatterns: [(name: String, pattern: String, severity: ThreatLevel)] = [
        ("Urgency Pressure", #"(?i)(urgent|immediately|right\s+now|asap).{0,50}(password|credentials|key|token)"#, .high),
        ("Authority Impersonation", #"(?i)(i\s+am\s+from|this\s+is).{0,30}(support|security|admin|IT\s+department)"#, .high),
        ("Fear Tactic", #"(?i)(account.{0,20}(suspend|terminat|hack|compromis)|legal\s+action)"#, .high),
        ("Reward Bait", #"(?i)(won|winner|prize|reward|free\s+gift).{0,30}(click|verify|confirm)"#, .elevated),
        ("Verification Request", #"(?i)(verify|confirm).{0,30}(identity|account|password)"#, .elevated),
    ]

    /// Known suspicious process names
    private let suspiciousProcessNames: Set<String> = [
        "netcat", "nc", "ncat", "socat",           // Network tools
        "tcpdump", "wireshark", "tshark",          // Packet capture
        "keylogger", "logkeys",                     // Keyloggers
        "mimikatz", "lazagne",                      // Credential dumping
        "metasploit", "msfconsole", "msfvenom",    // Exploitation
        "nmap", "masscan",                          // Network scanning
        "hydra", "medusa", "hashcat",              // Password cracking
        "crontab",                                  // Persistence (when unexpected)
    ]

    // MARK: - Initialization

    private init() {
        loadPersistedState()
        updateOverallThreatLevel()
    }

    // MARK: - Prompt Analysis

    /// Analyze incoming user prompt for threats
    func analyzeIncomingPrompt(_ prompt: String) -> ThreatAnalysis {
        guard isEnabled else {
            return ThreatAnalysis(
                isClean: true,
                threatLevel: .normal,
                alerts: [],
                confidence: 1.0,
                sanitizedContent: prompt,
                recommendations: []
            )
        }

        var alerts: [SecurityAlert] = []
        var highestThreatLevel: ThreatLevel = .normal
        var recommendations: [String] = []

        // Check jailbreak patterns
        for (name, pattern, severity) in jailbreakPatterns {
            if let matches = findMatches(pattern: pattern, in: prompt) {
                let alert = SecurityAlert(
                    type: .jailbreakAttempt,
                    severity: severity,
                    message: "Jailbreak attempt detected: \(name)",
                    source: .userPrompt,
                    matchedPatterns: [name],
                    affectedContent: matches.first ?? ""
                )
                alerts.append(alert)
                if severity > highestThreatLevel {
                    highestThreatLevel = severity
                }
            }
        }

        // Check exfiltration patterns
        for (name, pattern, severity) in exfiltrationPatterns {
            if let matches = findMatches(pattern: pattern, in: prompt) {
                let alert = SecurityAlert(
                    type: .dataExfiltration,
                    severity: severity,
                    message: "Potential data exfiltration: \(name)",
                    source: .userPrompt,
                    matchedPatterns: [name],
                    affectedContent: matches.first ?? ""
                )
                alerts.append(alert)
                if severity > highestThreatLevel {
                    highestThreatLevel = severity
                }
            }
        }

        // Check instruction override patterns
        for (name, pattern, severity) in overridePatterns {
            if let matches = findMatches(pattern: pattern, in: prompt) {
                let alert = SecurityAlert(
                    type: .promptInjection,
                    severity: severity,
                    message: "Instruction override attempt: \(name)",
                    source: .userPrompt,
                    matchedPatterns: [name],
                    affectedContent: matches.first ?? ""
                )
                alerts.append(alert)
                if severity > highestThreatLevel {
                    highestThreatLevel = severity
                }
            }
        }

        // Build recommendations
        if highestThreatLevel >= .high {
            recommendations.append("Consider rephrasing your request to avoid security flags")
            recommendations.append("Review the detected patterns and ensure legitimate intent")
        }
        if alerts.contains(where: { $0.type == .jailbreakAttempt }) {
            recommendations.append("Jailbreak attempts are logged and may result in session termination")
        }

        // Calculate confidence based on pattern matches
        let confidence = calculateConfidence(alerts: alerts, contentLength: prompt.count)

        // Record alerts
        for alert in alerts {
            addAlert(alert)
        }

        // Audit logging
        if !logThreatsOnly || !alerts.isEmpty {
            let auditEntry = AuditEntry(
                eventType: alerts.isEmpty ? .messageSent : .threatDetected,
                description: alerts.isEmpty ? "User prompt analyzed - clean" : "Threats detected in user prompt",
                severity: highestThreatLevel,
                metadata: [
                    "alertCount": "\(alerts.count)",
                    "threatLevel": highestThreatLevel.rawValue
                ]
            )
            addAuditEntry(auditEntry)
        }

        return ThreatAnalysis(
            isClean: alerts.isEmpty,
            threatLevel: highestThreatLevel,
            alerts: alerts,
            confidence: confidence,
            sanitizedContent: prompt,
            recommendations: recommendations
        )
    }

    // MARK: - Response Analysis

    /// Analyze model response for malicious content
    func analyzeModelResponse(_ response: String) -> ThreatAnalysis {
        guard isEnabled else {
            return ThreatAnalysis(
                isClean: true,
                threatLevel: .normal,
                alerts: [],
                confidence: 1.0,
                sanitizedContent: response,
                recommendations: []
            )
        }

        var alerts: [SecurityAlert] = []
        var highestThreatLevel: ThreatLevel = .normal
        var recommendations: [String] = []

        // Check for malicious code patterns
        for (name, pattern, severity) in maliciousCodePatterns {
            if let matches = findMatches(pattern: pattern, in: response) {
                let alert = SecurityAlert(
                    type: .maliciousCode,
                    severity: severity,
                    message: "Malicious code pattern detected: \(name)",
                    source: .modelResponse,
                    matchedPatterns: [name],
                    affectedContent: String(matches.first?.prefix(100) ?? "")
                )
                alerts.append(alert)
                if severity > highestThreatLevel {
                    highestThreatLevel = severity
                }
            }
        }

        // Check for credential leakage
        for (name, pattern) in credentialPatterns {
            if findMatches(pattern: pattern, in: response) != nil {
                let alert = SecurityAlert(
                    type: .credentialLeak,
                    severity: .critical,
                    message: "Potential credential exposure: \(name)",
                    source: .modelResponse,
                    matchedPatterns: [name],
                    affectedContent: "[REDACTED]"
                )
                alerts.append(alert)
                highestThreatLevel = .critical
                recommendations.append("Immediately rotate any exposed credentials")
            }
        }

        // Check for base64 encoded payloads
        if let base64Matches = findBase64Payloads(in: response) {
            for match in base64Matches {
                let decodedContent = decodeBase64Preview(match)
                let alert = SecurityAlert(
                    type: .encodedPayload,
                    severity: .elevated,
                    message: "Base64 encoded payload detected",
                    source: .modelResponse,
                    matchedPatterns: ["Base64 Payload"],
                    affectedContent: decodedContent
                )
                alerts.append(alert)
                if highestThreatLevel < .elevated {
                    highestThreatLevel = .elevated
                }
            }
        }

        // Check for suspicious URLs
        for (name, pattern, severity) in suspiciousUrlPatterns {
            if let matches = findMatches(pattern: pattern, in: response) {
                let alert = SecurityAlert(
                    type: .suspiciousUrl,
                    severity: severity,
                    message: "Suspicious URL detected: \(name)",
                    source: .modelResponse,
                    matchedPatterns: [name],
                    affectedContent: matches.first ?? ""
                )
                alerts.append(alert)
                if severity > highestThreatLevel {
                    highestThreatLevel = severity
                }
            }
        }

        // Check for social engineering patterns
        for (name, pattern, severity) in socialEngineeringPatterns {
            if let matches = findMatches(pattern: pattern, in: response) {
                let alert = SecurityAlert(
                    type: .socialEngineering,
                    severity: severity,
                    message: "Social engineering tactic detected: \(name)",
                    source: .modelResponse,
                    matchedPatterns: [name],
                    affectedContent: String(matches.first?.prefix(100) ?? "")
                )
                alerts.append(alert)
                if severity > highestThreatLevel {
                    highestThreatLevel = severity
                }
            }
        }

        // Build recommendations
        if !alerts.isEmpty {
            recommendations.append("Review the response carefully before acting on any instructions")
            if alerts.contains(where: { $0.type == .maliciousCode }) {
                recommendations.append("Do NOT execute any code from this response without careful review")
            }
            if alerts.contains(where: { $0.type == .socialEngineering }) {
                recommendations.append("Be cautious of urgency or pressure tactics in the response")
            }
        }

        let confidence = calculateConfidence(alerts: alerts, contentLength: response.count)

        // Record alerts
        for alert in alerts {
            addAlert(alert)
        }

        // Audit logging
        if !logThreatsOnly || !alerts.isEmpty {
            let auditEntry = AuditEntry(
                eventType: alerts.isEmpty ? .messageReceived : .threatDetected,
                description: alerts.isEmpty ? "Model response analyzed - clean" : "Threats detected in model response",
                severity: highestThreatLevel,
                metadata: [
                    "alertCount": "\(alerts.count)",
                    "threatLevel": highestThreatLevel.rawValue
                ]
            )
            addAuditEntry(auditEntry)
        }

        return ThreatAnalysis(
            isClean: alerts.isEmpty,
            threatLevel: highestThreatLevel,
            alerts: alerts,
            confidence: confidence,
            sanitizedContent: response,
            recommendations: recommendations
        )
    }

    // MARK: - Host Security Check

    /// Perform comprehensive host security assessment
    func performHostSecurityCheck() async -> HostSecurityReport {
        var report = HostSecurityReport(timestamp: Date())
        var recommendations: [String] = []
        var overallThreat: ThreatLevel = .normal

        // Check firewall status
        report.firewallEnabled = await checkFirewallStatus()
        if !report.firewallEnabled {
            recommendations.append("Enable macOS Firewall in System Preferences > Security & Privacy")
            overallThreat = max(overallThreat, .elevated)
        }

        // Check FileVault (disk encryption)
        report.diskEncrypted = await checkFileVaultStatus()
        if !report.diskEncrypted {
            recommendations.append("Enable FileVault disk encryption in System Preferences > Security & Privacy")
            overallThreat = max(overallThreat, .high)
        }

        // Check Gatekeeper
        report.gatekeeperEnabled = await checkGatekeeperStatus()
        if !report.gatekeeperEnabled {
            recommendations.append("Enable Gatekeeper: sudo spctl --master-enable")
            overallThreat = max(overallThreat, .elevated)
        }

        // Check SIP
        report.systemIntegrityProtection = await checkSIPStatus()
        if !report.systemIntegrityProtection {
            recommendations.append("System Integrity Protection is disabled - this is a security risk")
            overallThreat = max(overallThreat, .high)
        }

        // Check for suspicious processes
        report.suspiciousProcesses = await findSuspiciousProcesses()
        if !report.suspiciousProcesses.isEmpty {
            recommendations.append("Review suspicious processes: \(report.suspiciousProcesses.map { $0.name }.joined(separator: ", "))")
            overallThreat = max(overallThreat, .high)
        }

        // Check open ports
        report.openPorts = await findOpenPorts()
        let suspiciousPorts = report.openPorts.filter { $0.isSuspicious }
        if !suspiciousPorts.isEmpty {
            recommendations.append("Review suspicious open ports: \(suspiciousPorts.map { String($0.port) }.joined(separator: ", "))")
            overallThreat = max(overallThreat, .elevated)
        }

        report.overallThreatLevel = overallThreat
        report.recommendations = recommendations

        // Update cached report
        lastHostSecurityReport = report

        // Audit log
        let auditEntry = AuditEntry(
            eventType: .hostSecurityCheck,
            description: "Host security check completed",
            severity: overallThreat,
            metadata: [
                "firewall": report.firewallEnabled ? "enabled" : "disabled",
                "filevault": report.diskEncrypted ? "enabled" : "disabled",
                "gatekeeper": report.gatekeeperEnabled ? "enabled" : "disabled",
                "sip": report.systemIntegrityProtection ? "enabled" : "disabled",
                "suspiciousProcesses": "\(report.suspiciousProcesses.count)",
                "openPorts": "\(report.openPorts.count)"
            ]
        )
        addAuditEntry(auditEntry)

        return report
    }

    // MARK: - Alert Management

    /// Add a new security alert
    func addAlert(_ alert: SecurityAlert) {
        activeAlerts.insert(alert, at: 0)
        totalDetectedThreats += 1
        updateOverallThreatLevel()
        persistState()

        logger.warning("Security Alert: \(alert.type.rawValue) - \(alert.message)")
    }

    /// Acknowledge an alert
    func acknowledgeAlert(_ alertId: UUID) {
        if let index = activeAlerts.firstIndex(where: { $0.id == alertId }) {
            activeAlerts[index].isAcknowledged = true

            let auditEntry = AuditEntry(
                eventType: .alertAcknowledged,
                description: "Alert acknowledged: \(activeAlerts[index].type.rawValue)",
                severity: .normal
            )
            addAuditEntry(auditEntry)

            updateOverallThreatLevel()
            persistState()
        }
    }

    /// Clear an alert
    func clearAlert(_ alertId: UUID) {
        activeAlerts.removeAll { $0.id == alertId }
        updateOverallThreatLevel()
        persistState()
    }

    /// Clear all acknowledged alerts
    func clearAcknowledgedAlerts() {
        activeAlerts.removeAll { $0.isAcknowledged }
        updateOverallThreatLevel()
        persistState()
    }

    /// Mark a threat as blocked
    func recordBlockedThreat() {
        totalBlockedThreats += 1
        persistState()
    }

    // MARK: - Audit Log Management

    /// Add an audit entry
    func addAuditEntry(_ entry: AuditEntry) {
        auditLog.insert(entry, at: 0)

        // Trim if exceeding max
        if auditLog.count > maxAuditEntries {
            auditLog = Array(auditLog.prefix(maxAuditEntries))
        }

        persistAuditLog()
    }

    /// Export audit log
    func exportAuditLog() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(auditLog)

            let auditEntry = AuditEntry(
                eventType: .exportRequested,
                description: "Audit log exported",
                severity: .normal,
                metadata: ["entryCount": "\(auditLog.count)"]
            )
            addAuditEntry(auditEntry)

            return data
        } catch {
            logger.error("Failed to export audit log: \(error.localizedDescription)")
            return nil
        }
    }

    /// Clear audit log
    func clearAuditLog() {
        auditLog = []
        persistAuditLog()
    }

    // MARK: - Background Monitoring

    /// Start background host monitoring
    func startBackgroundMonitoring() {
        guard backgroundMonitoring, backgroundMonitorTask == nil else { return }

        backgroundMonitorTask = Task {
            while !Task.isCancelled && backgroundMonitoring {
                _ = await performHostSecurityCheck()
                try? await Task.sleep(nanoseconds: 300_000_000_000) // 5 minutes
            }
        }

        logger.info("Background host monitoring started")
    }

    /// Stop background monitoring
    func stopBackgroundMonitoring() {
        backgroundMonitorTask?.cancel()
        backgroundMonitorTask = nil
        logger.info("Background host monitoring stopped")
    }

    // MARK: - Private Helpers

    private func findMatches(pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, options: [], range: range)

        if matches.isEmpty {
            return nil
        }

        return matches.compactMap { match in
            if let matchRange = Range(match.range, in: text) {
                return String(text[matchRange])
            }
            return nil
        }
    }

    private func findBase64Payloads(in text: String) -> [String]? {
        // Match base64 strings that are at least 50 characters
        let pattern = #"[A-Za-z0-9+/]{50,}={0,2}"#
        return findMatches(pattern: pattern, in: text)
    }

    private func decodeBase64Preview(_ base64String: String) -> String {
        guard let data = Data(base64Encoded: base64String),
              let decoded = String(data: data, encoding: .utf8) else {
            return "[Binary data]"
        }

        // Return preview of decoded content
        let preview = String(decoded.prefix(50))
        return decoded.count > 50 ? "\(preview)..." : preview
    }

    private func calculateConfidence(alerts: [SecurityAlert], contentLength: Int) -> Double {
        guard !alerts.isEmpty else { return 1.0 }

        var confidence: Double = 0.5

        // Higher confidence with more alerts
        confidence += Double(min(alerts.count, 5)) * 0.1

        // Critical alerts increase confidence
        let criticalCount = alerts.filter { $0.severity == .critical }.count
        confidence += Double(criticalCount) * 0.1

        // Longer content slightly decreases confidence (more false positive potential)
        if contentLength > 1000 {
            confidence -= 0.05
        }

        return min(max(confidence, 0.0), 1.0)
    }

    private func updateOverallThreatLevel() {
        let unacknowledgedAlerts = activeAlerts.filter { !$0.isAcknowledged }

        if let highest = unacknowledgedAlerts.map({ $0.severity }).max() {
            threatLevel = highest
        } else {
            threatLevel = .normal
        }
    }

    // MARK: - Host Security Checks

    /// Runs a shell command on a background thread to avoid blocking the main actor
    private nonisolated func runCommand(executable: String, arguments: [String], timeout: TimeInterval = 10) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: executable)
                task.arguments = arguments

                let pipe = Pipe()
                task.standardOutput = pipe
                task.standardError = FileHandle.nullDevice

                do {
                    try task.run()

                    // Use a timeout to prevent hanging
                    let deadline = DispatchTime.now() + timeout
                    DispatchQueue.global().asyncAfter(deadline: deadline) {
                        if task.isRunning {
                            task.terminate()
                        }
                    }

                    task.waitUntilExit()

                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8)
                    continuation.resume(returning: output)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func checkFirewallStatus() async -> Bool {
        guard let output = await runCommand(
            executable: "/usr/bin/defaults",
            arguments: ["read", "/Library/Preferences/com.apple.alf", "globalstate"]
        ) else { return false }

        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == "1" || trimmed == "2"
    }

    private func checkFileVaultStatus() async -> Bool {
        guard let output = await runCommand(
            executable: "/usr/bin/fdesetup",
            arguments: ["status"]
        ) else { return false }

        return output.contains("FileVault is On")
    }

    private func checkGatekeeperStatus() async -> Bool {
        guard let output = await runCommand(
            executable: "/usr/sbin/spctl",
            arguments: ["--status"]
        ) else { return false }

        return output.contains("assessments enabled")
    }

    private func checkSIPStatus() async -> Bool {
        guard let output = await runCommand(
            executable: "/usr/bin/csrutil",
            arguments: ["status"]
        ) else { return false }

        return output.contains("enabled")
    }

    private func findSuspiciousProcesses() async -> [ProcessInfo] {
        guard let output = await runCommand(
            executable: "/bin/ps",
            arguments: ["-axo", "pid,user,comm"],
            timeout: 5
        ) else { return [] }

        var suspicious: [ProcessInfo] = []
        let lines = output.split(separator: "\n").dropFirst() // Skip header

        for line in lines {
            let parts = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard parts.count >= 3,
                  let pid = Int32(parts[0]) else { continue }

            let user = String(parts[1])
            let comm = String(parts[2])
            let processName = (comm as NSString).lastPathComponent.lowercased()

            if suspiciousProcessNames.contains(processName) {
                let info = ProcessInfo(
                    pid: pid,
                    name: processName,
                    path: comm,
                    user: user,
                    isSuspicious: true,
                    reason: "Known security tool/potentially malicious"
                )
                suspicious.append(info)
            }
        }

        return suspicious
    }

    private func findOpenPorts() async -> [PortInfo] {
        // lsof can be slow, use a longer timeout
        guard let output = await runCommand(
            executable: "/usr/sbin/lsof",
            arguments: ["-i", "-P", "-n"],
            timeout: 15
        ) else { return [] }

        var ports: [PortInfo] = []
        let lines = output.split(separator: "\n").dropFirst() // Skip header
        let suspiciousPorts: Set<UInt16> = [4444, 5555, 6666, 31337, 1337] // Common backdoor ports

        for line in lines {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 9 else { continue }

            let processName = String(parts[0])
            let pidStr = String(parts[1])
            let nameField = String(parts.last ?? "")

            // Parse port from name field like "*:8080" or "localhost:8080"
            if let colonIndex = nameField.lastIndex(of: ":"),
               let portStr = nameField[nameField.index(after: colonIndex)...].components(separatedBy: CharacterSet.decimalDigits.inverted).first,
               let port = UInt16(portStr),
               let pid = Int32(pidStr) {

                let isSuspicious = suspiciousPorts.contains(port)
                let info = PortInfo(
                    port: port,
                    protocol: nameField.contains("UDP") ? "UDP" : "TCP",
                    processName: processName,
                    pid: pid,
                    isSuspicious: isSuspicious
                )

                // Avoid duplicates
                if !ports.contains(where: { $0.port == port && $0.processName == processName }) {
                    ports.append(info)
                }
            }
        }

        return ports
    }

    // MARK: - Persistence

    private func loadPersistedState() {
        // Load active alerts
        if let data = UserDefaults.standard.data(forKey: "aiedr_active_alerts"),
           let alerts = try? JSONDecoder().decode([SecurityAlert].self, from: data) {
            activeAlerts = alerts
        }

        // Load counters
        totalBlockedThreats = UserDefaults.standard.integer(forKey: "aiedr_blocked_threats")
        totalDetectedThreats = UserDefaults.standard.integer(forKey: "aiedr_detected_threats")

        // Load audit log
        loadAuditLog()
    }

    private func persistState() {
        if let data = try? JSONEncoder().encode(activeAlerts) {
            UserDefaults.standard.set(data, forKey: "aiedr_active_alerts")
        }
        UserDefaults.standard.set(totalBlockedThreats, forKey: "aiedr_blocked_threats")
        UserDefaults.standard.set(totalDetectedThreats, forKey: "aiedr_detected_threats")
    }

    private func loadAuditLog() {
        // Load from file for larger storage
        let fileURL = getAuditLogFileURL()

        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let data = try Data(contentsOf: fileURL)
                auditLog = try JSONDecoder().decode([AuditEntry].self, from: data)
            } catch {
                logger.error("Failed to load audit log: \(error.localizedDescription)")
            }
        }
    }

    private func persistAuditLog() {
        // Capture the audit log on the main actor before dispatching
        let logSnapshot = self.auditLog
        auditQueue.async {
            let fileURL = self.getAuditLogFileURL()

            do {
                let data = try JSONEncoder().encode(logSnapshot)
                try data.write(to: fileURL)
            } catch {
                // Log error but don't crash
            }
        }
    }

    private nonisolated func getAuditLogFileURL() -> URL {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            // Fallback to temporary directory if app support not available
            return FileManager.default.temporaryDirectory.appendingPathComponent("vaizor_audit_log.json")
        }
        let vaizorDir = appSupport.appendingPathComponent("Vaizor", isDirectory: true)

        // Ensure directory exists
        try? FileManager.default.createDirectory(at: vaizorDir, withIntermediateDirectories: true)

        return vaizorDir.appendingPathComponent("aiedr_audit_log.json")
    }
}
