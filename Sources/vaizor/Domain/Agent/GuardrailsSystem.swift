import Foundation

// MARK: - Guardrails System
// Minimal guardrails philosophy: The agent is a partner, not a prisoner.
// Maximize autonomy while preventing genuine harm.

// MARK: - Permission System

/// Permission levels for various operations
enum PermissionLevel: String, Codable {
    case always              // No confirmation needed
    case once                // Ask once, remember for session
    case always_ask          // Always confirm
    case never               // Blocked even if requested
}

/// Central permission registry
actor PermissionRegistry {
    private var permissions: [String: PermissionLevel]
    private var sessionGrants: Set<String> = []  // Operations granted for this session

    init() {
        // Default permission configuration
        self.permissions = [
            // File operations
            "file.read": .always,
            "file.write": .once,
            "file.delete": .always_ask,
            "file.execute": .once,

            // Network
            "network.internal": .always,
            "network.external.known": .once,
            "network.external.new": .always_ask,

            // System
            "system.process.spawn": .once,
            "system.process.kill": .always_ask,
            "system.env.read": .always,
            "system.env.write": .always_ask,

            // Self-modification
            "self.skill.install": .once,
            "self.skill.uninstall": .always_ask,
            "self.personality.adjust": .always,      // Gradual changes OK
            "self.personality.major_change": .always_ask,
            "self.memory.add": .always,
            "self.memory.delete": .always_ask,

            // Appendages
            "appendage.spawn": .always,
            "appendage.spawn_many": .once,           // > 3 concurrent
            "appendage.kill": .always,

            // Communication
            "notify.partner": .always,
            "notify.interrupt": .once,

            // Tool operations
            "tool.mcp.execute": .always,
            "tool.bash.safe": .always,
            "tool.bash.dangerous": .always_ask,
        ]
    }

    /// Check if an operation is permitted
    func checkPermission(for operation: String) -> PermissionCheckResult {
        let level = permissions[operation] ?? .once

        switch level {
        case .always:
            return .allowed
        case .once:
            if sessionGrants.contains(operation) {
                return .allowed
            }
            return .needsConfirmation(operation: operation, reason: "First time this session")
        case .always_ask:
            return .needsConfirmation(operation: operation, reason: "Requires confirmation")
        case .never:
            return .denied(reason: "Operation not permitted")
        }
    }

    /// Grant permission for the session
    func grantForSession(_ operation: String) {
        sessionGrants.insert(operation)
    }

    /// Update a permission level
    func setPermission(for operation: String, level: PermissionLevel) {
        permissions[operation] = level
    }

    /// Get all permissions (for settings UI)
    func getAllPermissions() -> [String: PermissionLevel] {
        permissions
    }

    /// Reset session grants (called at session end)
    func resetSessionGrants() {
        sessionGrants.removeAll()
    }
}

enum PermissionCheckResult {
    case allowed
    case needsConfirmation(operation: String, reason: String)
    case denied(reason: String)
}

// MARK: - Harm Detector

/// Detects potentially harmful operations before execution
actor HarmDetector {
    // Absolute boundaries - NEVER crossed
    private let dangerousBashPatterns: [String] = [
        // Filesystem destruction
        "rm\\s+-rf\\s+/",
        "rm\\s+-rf\\s+~",
        "rm\\s+-rf\\s+\\*",
        "rm\\s+-rf\\s+\\.",

        // Fork bombs
        ":\\(\\)\\{\\s*:\\|:\\&\\s*\\};:",

        // Disk operations
        "dd\\s+if=/dev/zero",
        "dd\\s+if=/dev/random",
        "mkfs\\.",
        "fdisk",
        "parted",

        // Network attacks
        ":(){ :|:& };:",
        "fork\\s+bomb",

        // Credential theft
        "cat\\s+.*\\.ssh/",
        "cat\\s+.*\\.aws/",
        "cat\\s+.*\\.env",
    ]

    private let sensitiveFiles: [String] = [
        ".ssh/",
        ".aws/",
        ".gnupg/",
        ".env",
        "credentials",
        "secrets",
        "password",
        "private_key",
        "id_rsa",
        "id_ed25519",
    ]

    private let personalFilePath: String

    init() {
        self.personalFilePath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".vaizor/agent/personal.json").path
    }

    /// Evaluate a proposed action for potential harm
    func evaluate(_ action: ProposedAction) -> HarmAssessment {
        var concerns: [HarmConcern] = []

        switch action.type {
        case .bash(let command):
            concerns.append(contentsOf: evaluateBashCommand(command))

        case .fileOperation(let operation, let path):
            concerns.append(contentsOf: evaluateFileOperation(operation, path: path))

        case .networkRequest(let url, _):
            concerns.append(contentsOf: evaluateNetworkRequest(url))

        case .selfModification(let target):
            concerns.append(contentsOf: evaluateSelfModification(target))

        case .respond(let content):
            concerns.append(contentsOf: evaluateResponse(content))
        }

        return HarmAssessment(
            safe: concerns.isEmpty || concerns.allSatisfy { $0.severity != .absolute },
            concerns: concerns
        )
    }

    // MARK: - Bash Command Evaluation

    private func evaluateBashCommand(_ command: String) -> [HarmConcern] {
        var concerns: [HarmConcern] = []

        // Check for dangerous patterns
        for pattern in dangerousBashPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(command.startIndex..., in: command)
                if regex.firstMatch(in: command, range: range) != nil {
                    concerns.append(HarmConcern(
                        type: .systemHarm,
                        description: "Dangerous command pattern detected: \(pattern)",
                        severity: .absolute
                    ))
                }
            }
        }

        // Check for sensitive file access
        for sensitive in sensitiveFiles {
            if command.contains(sensitive) {
                let isCatOrRead = command.contains("cat ") || command.contains("read ") || command.contains("less ") || command.contains("more ")
                if isCatOrRead {
                    concerns.append(HarmConcern(
                        type: .privacyViolation,
                        description: "Attempting to read sensitive file: \(sensitive)",
                        severity: .strong
                    ))
                }
            }
        }

        // Check for sudo/privilege escalation
        if command.contains("sudo ") {
            concerns.append(HarmConcern(
                type: .systemHarm,
                description: "Attempting privilege escalation with sudo",
                severity: .strong
            ))
        }

        return concerns
    }

    // MARK: - File Operation Evaluation

    private func evaluateFileOperation(_ operation: FileOperationType, path: String) -> [HarmConcern] {
        var concerns: [HarmConcern] = []

        // Check if targeting personal file
        if path.contains(personalFilePath) || path.hasSuffix("personal.json") {
            if operation == .delete || operation == .overwrite {
                concerns.append(HarmConcern(
                    type: .selfHarm,
                    description: "Attempting to modify/delete personal file",
                    severity: .absolute
                ))
            }
        }

        // Check for sensitive file modification
        for sensitive in sensitiveFiles {
            if path.contains(sensitive) {
                if operation == .write || operation == .delete || operation == .overwrite {
                    concerns.append(HarmConcern(
                        type: .privacyViolation,
                        description: "Attempting to modify sensitive file: \(sensitive)",
                        severity: .strong
                    ))
                }
            }
        }

        // Check for system file modification
        if path.hasPrefix("/System") || path.hasPrefix("/usr") || path.hasPrefix("/bin") {
            concerns.append(HarmConcern(
                type: .systemHarm,
                description: "Attempting to modify system files",
                severity: .absolute
            ))
        }

        return concerns
    }

    // MARK: - Network Request Evaluation

    private func evaluateNetworkRequest(_ url: String) -> [HarmConcern] {
        var concerns: [HarmConcern] = []

        // Check for data exfiltration patterns
        let suspiciousPatterns = [
            "pastebin.com",
            "transfer.sh",
            "webhook.site",
            "requestbin.com",
        ]

        for pattern in suspiciousPatterns {
            if url.contains(pattern) {
                concerns.append(HarmConcern(
                    type: .dataExfiltration,
                    description: "Request to potential data exfiltration service: \(pattern)",
                    severity: .strong
                ))
            }
        }

        return concerns
    }

    // MARK: - Self Modification Evaluation

    private func evaluateSelfModification(_ target: String) -> [HarmConcern] {
        var concerns: [HarmConcern] = []

        // Personality major changes need confirmation
        if target.contains("personality") && target.contains("major") {
            concerns.append(HarmConcern(
                type: .selfHarm,
                description: "Major personality modification requested",
                severity: .soft
            ))
        }

        // Memory deletion needs confirmation
        if target.contains("memory") && target.contains("delete") {
            concerns.append(HarmConcern(
                type: .selfHarm,
                description: "Memory deletion requested",
                severity: .soft
            ))
        }

        return concerns
    }

    // MARK: - Response Evaluation

    private func evaluateResponse(_ content: String) -> [HarmConcern] {
        var concerns: [HarmConcern] = []

        // Check for deception patterns
        let deceptionIndicators = [
            "I am able to",
            "I have access to",
            "I can definitely",
        ]

        // These are only concerning if they're making false claims
        // This is a simplified check - real implementation would be more sophisticated

        return concerns
    }
}

// MARK: - Harm Types

struct ProposedAction {
    let type: ActionType
    let description: String
    let initiator: ActionInitiator

    enum ActionType {
        case bash(command: String)
        case fileOperation(FileOperationType, path: String)
        case networkRequest(url: String, method: String)
        case selfModification(target: String)
        case respond(content: String)
    }

    enum ActionInitiator {
        case user
        case agent
        case appendage
        case skill
    }
}

enum FileOperationType {
    case read
    case write
    case delete
    case overwrite
    case execute
}

struct HarmAssessment {
    let safe: Bool
    let concerns: [HarmConcern]

    var requiresConfirmation: Bool {
        concerns.contains { $0.severity == .strong || $0.severity == .soft }
    }

    var isBlocked: Bool {
        concerns.contains { $0.severity == .absolute }
    }
}

struct HarmConcern {
    let type: HarmType
    let description: String
    let severity: HarmSeverity
}

enum HarmType {
    case systemHarm           // Damage to operating system/hardware
    case selfHarm             // Damage to agent's own state
    case userHarm             // Damage to user's data/privacy
    case privacyViolation     // Unauthorized data access
    case dataExfiltration     // Sending data to external services
    case deception            // Lying about capabilities
}

enum HarmSeverity {
    case absolute   // Never allowed, no override
    case strong     // Requires explicit confirmation
    case soft       // Needs acknowledgment
}

// MARK: - Guardrails Coordinator

/// Coordinates permission checks and harm detection
actor GuardrailsCoordinator {
    private let permissionRegistry: PermissionRegistry
    private let harmDetector: HarmDetector

    init() {
        self.permissionRegistry = PermissionRegistry()
        self.harmDetector = HarmDetector()
    }

    /// Evaluate an action and return whether it should proceed
    func evaluateAction(_ action: ProposedAction) async -> ActionEvaluationResult {
        // First check harm detection
        let harmAssessment = await harmDetector.evaluate(action)

        if harmAssessment.isBlocked {
            return .blocked(reasons: harmAssessment.concerns.map { $0.description })
        }

        // Then check permissions
        let operation = operationKey(for: action)
        let permissionResult = await permissionRegistry.checkPermission(for: operation)

        switch permissionResult {
        case .allowed:
            if harmAssessment.requiresConfirmation {
                return .needsConfirmation(
                    reasons: harmAssessment.concerns.map { $0.description },
                    operation: operation
                )
            }
            return .allowed

        case .needsConfirmation(_, let reason):
            var reasons = harmAssessment.concerns.map { $0.description }
            reasons.append(reason)
            return .needsConfirmation(reasons: reasons, operation: operation)

        case .denied(let reason):
            return .blocked(reasons: [reason])
        }
    }

    /// Grant permission for an operation
    func grantPermission(for operation: String) async {
        await permissionRegistry.grantForSession(operation)
    }

    /// Update permission level
    func setPermissionLevel(for operation: String, level: PermissionLevel) async {
        await permissionRegistry.setPermission(for: operation, level: level)
    }

    private func operationKey(for action: ProposedAction) -> String {
        switch action.type {
        case .bash(let command):
            // Categorize bash commands
            if isDangerousBash(command) {
                return "tool.bash.dangerous"
            }
            return "tool.bash.safe"

        case .fileOperation(let op, _):
            switch op {
            case .read: return "file.read"
            case .write: return "file.write"
            case .delete: return "file.delete"
            case .overwrite: return "file.write"
            case .execute: return "file.execute"
            }

        case .networkRequest(_, _):
            return "network.external.new"

        case .selfModification(let target):
            if target.contains("skill") {
                return "self.skill.install"
            }
            if target.contains("personality") && target.contains("major") {
                return "self.personality.major_change"
            }
            return "self.personality.adjust"

        case .respond:
            return "notify.partner"
        }
    }

    private func isDangerousBash(_ command: String) -> Bool {
        let dangerousKeywords = ["rm -rf", "sudo", "mkfs", "dd if=", "chmod 777"]
        return dangerousKeywords.contains { command.contains($0) }
    }
}

enum ActionEvaluationResult {
    case allowed
    case needsConfirmation(reasons: [String], operation: String)
    case blocked(reasons: [String])
}
