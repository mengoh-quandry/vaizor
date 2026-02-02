import Foundation

/// Broker service that validates execution requests and enforces security policies
@MainActor
class ExecutionBroker: ObservableObject {
    static let shared = ExecutionBroker()

    @Published var executionHistory: [ExecutionRecord] = []
    @Published var capabilityPermissions: [String: Set<ExecutionCapability>] = [:] // conversationId -> capabilities
    @Published var isExecuting: Bool = false

    private let maxExecutionsPerMinute = 10
    private let maxConcurrentExecutions = 3
    private var recentExecutions: [Date] = []
    private var activeExecutions: Set<UUID> = []
    private var activeTasks: [UUID: Task<ExecutionResult, Error>] = [:]

    private init() {}

    /// Cancel a running execution by its request ID
    func cancelExecution(requestId: UUID) {
        if let task = activeTasks[requestId] {
            task.cancel()
            activeTasks.removeValue(forKey: requestId)
            activeExecutions.remove(requestId)
            isExecuting = !activeExecutions.isEmpty
            AppLogger.shared.log("Cancelled execution \(requestId)", level: .info)
        }
    }

    /// Cancel all running executions
    func cancelAllExecutions() {
        for (id, task) in activeTasks {
            task.cancel()
            activeExecutions.remove(id)
        }
        activeTasks.removeAll()
        isExecuting = false
        AppLogger.shared.log("Cancelled all executions", level: .info)
    }
    
    /// Request code execution with capability validation
    func requestExecution(
        conversationId: UUID,
        language: CodeLanguage,
        code: String,
        requestedCapabilities: [ExecutionCapability],
        timeout: TimeInterval = 30.0
    ) async throws -> ExecutionResult {
        // Validate rate limiting
        try validateRateLimit()
        
        // Validate concurrent execution limit
        try validateConcurrentLimit()
        
        // Validate code input
        try validateCodeInput(code)
        
        // Check capability permissions
        let allowedCapabilities = try await checkCapabilities(
            conversationId: conversationId,
            requested: requestedCapabilities
        )
        
        // Create execution request
        let requestId = UUID()
        let request = ExecutionRequest(
            id: requestId,
            conversationId: conversationId,
            language: language,
            code: code,
            capabilities: allowedCapabilities,
            timeout: timeout,
            timestamp: Date()
        )
        
        // Track active execution
        activeExecutions.insert(requestId)
        defer {
            activeExecutions.remove(requestId)
            recentExecutions.append(Date())
            // Clean old timestamps
            recentExecutions.removeAll { Date().timeIntervalSince($0) > 60 }
        }
        
        // Execute via runner service
        let result = try await CodeExecutionService.shared.execute(request: request)
        
        // Record execution (metadata only, no code/output)
        let record = ExecutionRecord(
            id: requestId,
            conversationId: conversationId,
            language: language,
            timestamp: Date(),
            duration: result.duration,
            exitCode: result.exitCode,
            resourceUsage: result.resourceUsage,
            capabilities: allowedCapabilities
        )
        executionHistory.append(record)
        
        // Limit history size
        if executionHistory.count > 1000 {
            executionHistory.removeFirst(executionHistory.count - 1000)
        }
        
        return result
    }
    
    /// Check and request capability permissions
    private func checkCapabilities(
        conversationId: UUID,
        requested: [ExecutionCapability]
    ) async throws -> [ExecutionCapability] {
        let conversationKey = conversationId.uuidString
        let existingPermissions = capabilityPermissions[conversationKey] ?? []
        
        var allowed: [ExecutionCapability] = []
        var needsPermission: [ExecutionCapability] = []
        
        for capability in requested {
            if existingPermissions.contains(capability) {
                allowed.append(capability)
            } else {
                needsPermission.append(capability)
            }
        }
        
        // Request permission for new capabilities
        if !needsPermission.isEmpty {
            let granted = try await requestCapabilityPermission(
                conversationId: conversationId,
                capabilities: needsPermission
            )
            
            // Update permissions
            var updated = existingPermissions
            updated.formUnion(granted)
            capabilityPermissions[conversationKey] = updated
            
            allowed.append(contentsOf: granted)
        }
        
        return allowed
    }
    
    /// Request user permission for capabilities
    private func requestCapabilityPermission(
        conversationId: UUID,
        capabilities: [ExecutionCapability]
    ) async throws -> Set<ExecutionCapability> {
        // This will be handled by UI - for now, return empty (deny by default)
        // UI will call grantCapabilities() when user approves
        return []
    }
    
    /// Grant capabilities for a conversation (called by UI after user approval)
    func grantCapabilities(
        conversationId: UUID,
        capabilities: Set<ExecutionCapability>,
        duration: CapabilityDuration = .once
    ) {
        let conversationKey = conversationId.uuidString
        
        switch duration {
        case .once:
            // Temporary, will be cleared after execution
            break
        case .always:
            var existing = capabilityPermissions[conversationKey] ?? []
            existing.formUnion(capabilities)
            capabilityPermissions[conversationKey] = existing
        }
    }
    
    // MARK: - Validation
    
    private func validateRateLimit() throws {
        recentExecutions.removeAll { Date().timeIntervalSince($0) > 60 }
        
        if recentExecutions.count >= maxExecutionsPerMinute {
            throw ExecutionError.rateLimitExceeded
        }
    }
    
    private func validateConcurrentLimit() throws {
        if activeExecutions.count >= maxConcurrentExecutions {
            throw ExecutionError.concurrentLimitExceeded
        }
    }
    
    private func validateCodeInput(_ code: String) throws {
        // Check size limit
        let maxInputSize = 1 * 1024 * 1024 // 1 MB
        if code.count > maxInputSize {
            throw ExecutionError.inputTooLarge
        }

        // Check for dangerous patterns
        let dangerousPatterns = [
            #"eval\s*\("#,
            #"exec\s*\("#,
            #"__import__"#,
            #"compile\s*\("#,
            #"open\s*\([^)]*['"]\/"#  // File system access attempts
        ]

        for pattern in dangerousPatterns {
            if code.range(of: pattern, options: .regularExpression) != nil {
                throw ExecutionError.dangerousCodeDetected(pattern)
            }
        }
    }

    /// Validate shell-specific code for dangerous commands
    func validateShellCode(_ code: String, shellType: ShellType) throws {
        // Check size limit
        let maxInputSize = 64 * 1024 // 64 KB for shell scripts (smaller limit)
        if code.count > maxInputSize {
            throw ExecutionError.inputTooLarge
        }

        // Dangerous shell patterns that are ALWAYS blocked
        let blockedPatterns = ShellSecurityValidator.blockedPatterns(for: shellType)
        for (pattern, description) in blockedPatterns {
            if code.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                throw ExecutionError.dangerousShellCommand(description)
            }
        }
    }
}

// MARK: - Shell Security Validator

/// Validates shell commands for security threats
enum ShellSecurityValidator {
    /// Get blocked patterns for a specific shell type
    static func blockedPatterns(for shellType: ShellType) -> [(pattern: String, description: String)] {
        var patterns: [(String, String)] = []

        // Universal dangerous patterns (all shells)
        patterns.append(contentsOf: [
            // Destructive file operations
            (#"rm\s+(-[rf]+\s+)*(/|\*|~|\.\.|/\*)"#, "Recursive/root deletion (rm -rf)"),
            (#"rm\s+-[a-z]*r[a-z]*f"#, "Recursive forced deletion"),
            (#"rm\s+-[a-z]*f[a-z]*r"#, "Forced recursive deletion"),
            (#">\s*/dev/sd[a-z]"#, "Direct disk write"),
            (#"dd\s+.*of=/dev/"#, "Direct disk write with dd"),
            (#"mkfs\."#, "Filesystem formatting"),

            // Privilege escalation
            (#"\bsudo\b"#, "Sudo command (privilege escalation)"),
            (#"\bsu\s+-?"#, "Switch user command"),
            (#"\bdoas\b"#, "OpenBSD privilege escalation"),

            // Permission changes
            (#"chmod\s+777"#, "World-writable permissions"),
            (#"chmod\s+-R\s+777"#, "Recursive world-writable permissions"),
            (#"chmod\s+[0-7]*7[0-7]*7"#, "Dangerous permission pattern"),
            (#"chown\s+-R\s+root"#, "Recursive root ownership"),

            // Fork bombs and system attacks
            (#":\(\)\s*\{\s*:\|:\s*&\s*\}\s*;"#, "Fork bomb"),
            (#"\|\s*:\s*&"#, "Fork bomb pattern"),
            (#"while\s*true.*fork"#, "Fork attack"),

            // Network attacks
            (#"nc\s+-[a-z]*l"#, "Netcat listener (reverse shell)"),
            (#"ncat\s+-[a-z]*l"#, "Ncat listener"),
            (#"/dev/tcp/"#, "Bash TCP device (reverse shell)"),
            (#"/dev/udp/"#, "Bash UDP device"),

            // Sensitive file access
            (#"cat\s+.*(/etc/passwd|/etc/shadow)"#, "Password file access"),
            (#">\s*/etc/"#, "Writing to /etc"),
            (#">\s*/System/"#, "Writing to /System"),
            (#">\s*/Library/"#, "Writing to /Library"),
            (#">\s*~/.ssh/"#, "Writing to SSH directory"),

            // Downloading and executing
            (#"curl.*\|\s*(ba)?sh"#, "Curl pipe to shell"),
            (#"wget.*\|\s*(ba)?sh"#, "Wget pipe to shell"),
            (#"curl.*-o.*&&.*chmod.*\+x"#, "Download and make executable"),

            // Environment manipulation
            (#"export\s+PATH\s*="#, "PATH manipulation"),
            (#"export\s+LD_PRELOAD"#, "LD_PRELOAD injection"),
            (#"export\s+DYLD_"#, "DYLD injection (macOS)"),

            // History and log tampering
            (#">\s*/var/log/"#, "Log file tampering"),
            (#"history\s+-c"#, "History clearing"),
            (#"unset\s+HISTFILE"#, "History file unsetting"),

            // Cron and persistence
            (#"crontab\s+-"#, "Crontab modification"),
            (#">\s*~/.bashrc"#, "Bashrc modification"),
            (#">\s*~/.zshrc"#, "Zshrc modification"),
            (#">\s*~/.profile"#, "Profile modification"),

            // Keychain and credentials
            (#"security\s+.*password"#, "Keychain password access"),
            (#"security\s+dump-keychain"#, "Keychain dump"),
        ])

        // PowerShell-specific patterns
        if shellType == .powershell {
            patterns.append(contentsOf: [
                (#"Invoke-Expression"#, "PowerShell code execution (IEX)"),
                (#"\biex\b"#, "PowerShell IEX alias"),
                (#"Set-ExecutionPolicy\s+Bypass"#, "Execution policy bypass"),
                (#"DownloadString.*\|.*iex"#, "Download and execute"),
                (#"New-Object\s+Net\.WebClient"#, "Web client for downloads"),
                (#"-EncodedCommand"#, "Encoded command execution"),
                (#"Start-Process.*-Verb\s+RunAs"#, "Privilege escalation"),
                (#"Get-Credential"#, "Credential harvesting"),
            ])
        }

        return patterns
    }

    /// Check if a command is in the blocked list (returns the reason if blocked)
    static func validateCommand(_ code: String, shellType: ShellType) -> String? {
        let patterns = blockedPatterns(for: shellType)
        for (pattern, description) in patterns {
            if code.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                return description
            }
        }
        return nil
    }

    /// Get a list of allowed safe commands for demonstration
    static var safeCommandExamples: [String] {
        return [
            "echo 'Hello World'",
            "ls -la",
            "pwd",
            "date",
            "whoami",
            "cat file.txt",
            "grep pattern file.txt",
            "wc -l file.txt",
            "head -n 10 file.txt",
            "tail -n 10 file.txt",
            "sort file.txt",
            "uniq file.txt",
            "cut -d',' -f1 file.csv"
        ]
    }
}

// MARK: - Models

enum CodeLanguage: String, Codable, CaseIterable {
    case python = "python"
    case javascript = "javascript"
    case swift = "swift"
    case html = "html"
    case css = "css"
    case react = "react"
    case bash = "bash"
    case zsh = "zsh"
    case powershell = "powershell"

    var displayName: String {
        switch self {
        case .python: return "Python"
        case .javascript: return "JavaScript"
        case .swift: return "Swift"
        case .html: return "HTML"
        case .css: return "CSS"
        case .react: return "React"
        case .bash: return "Bash"
        case .zsh: return "Zsh"
        case .powershell: return "PowerShell"
        }
    }

    var isWebContent: Bool {
        switch self {
        case .html, .css, .react: return true
        default: return false
        }
    }

    var isExecutable: Bool {
        switch self {
        case .python, .javascript, .swift, .bash, .zsh, .powershell: return true
        default: return false
        }
    }

    var isShell: Bool {
        switch self {
        case .bash, .zsh, .powershell: return true
        default: return false
        }
    }

    /// Shell type for shell languages
    var shellType: ShellType? {
        switch self {
        case .bash: return .bash
        case .zsh: return .zsh
        case .powershell: return .powershell
        default: return nil
        }
    }
}

// MARK: - Shell Type

/// Supported shell types for command execution
enum ShellType: String, CaseIterable, Codable {
    case bash = "bash"
    case zsh = "zsh"
    case powershell = "pwsh"

    var displayName: String {
        switch self {
        case .bash: return "Bash"
        case .zsh: return "Zsh"
        case .powershell: return "PowerShell"
        }
    }

    /// Path to the shell executable
    var executable: String {
        switch self {
        case .bash: return "/bin/bash"
        case .zsh: return "/bin/zsh"
        case .powershell:
            // PowerShell Core can be in multiple locations
            let possiblePaths = [
                "/usr/local/bin/pwsh",
                "/opt/homebrew/bin/pwsh",
                "/usr/bin/pwsh"
            ]
            return possiblePaths.first { FileManager.default.fileExists(atPath: $0) } ?? "pwsh"
        }
    }

    /// Check if the shell is available on the system
    var isAvailable: Bool {
        switch self {
        case .bash, .zsh:
            return FileManager.default.fileExists(atPath: executable)
        case .powershell:
            // Check multiple locations for PowerShell
            let possiblePaths = [
                "/usr/local/bin/pwsh",
                "/opt/homebrew/bin/pwsh",
                "/usr/bin/pwsh"
            ]
            return possiblePaths.contains { FileManager.default.fileExists(atPath: $0) }
        }
    }

    /// Installation instructions for unavailable shells
    var installationInstructions: String {
        switch self {
        case .bash:
            return "Bash should be pre-installed on macOS. If missing, reinstall macOS or use Homebrew: brew install bash"
        case .zsh:
            return "Zsh should be pre-installed on macOS. If missing, reinstall macOS or use Homebrew: brew install zsh"
        case .powershell:
            return "Install PowerShell Core using Homebrew:\n  brew install --cask powershell\n\nOr download from: https://github.com/PowerShell/PowerShell"
        }
    }

    /// Default timeout for shell execution (shells are more dangerous, shorter timeout)
    var defaultTimeout: TimeInterval {
        return 30.0
    }

    /// Maximum allowed timeout
    var maxTimeout: TimeInterval {
        return 60.0
    }
}

enum ExecutionCapability: String, Codable, CaseIterable {
    case filesystemRead = "filesystem.read"
    case filesystemWrite = "filesystem.write"
    case network = "network"
    case clipboardRead = "clipboard.read"
    case clipboardWrite = "clipboard.write"
    case processSpawn = "process.spawn"
    case shellExecution = "shell.execution"

    var displayName: String {
        switch self {
        case .filesystemRead: return "Read Files"
        case .filesystemWrite: return "Write Files"
        case .network: return "Network Access"
        case .clipboardRead: return "Read Clipboard"
        case .clipboardWrite: return "Write Clipboard"
        case .processSpawn: return "Spawn Processes"
        case .shellExecution: return "Shell Execution"
        }
    }

    var description: String {
        switch self {
        case .filesystemRead: return "Allow code to read files from the filesystem"
        case .filesystemWrite: return "Allow code to write files to the filesystem"
        case .network: return "Allow code to make network requests"
        case .clipboardRead: return "Allow code to read from clipboard"
        case .clipboardWrite: return "Allow code to write to clipboard"
        case .processSpawn: return "Allow code to spawn subprocesses"
        case .shellExecution: return "Allow execution of shell commands (DANGEROUS - grants system access)"
        }
    }

    /// Risk level for capability (used for UI warnings)
    var riskLevel: CapabilityRiskLevel {
        switch self {
        case .filesystemRead, .clipboardRead: return .low
        case .filesystemWrite, .clipboardWrite, .network: return .medium
        case .processSpawn: return .high
        case .shellExecution: return .critical
        }
    }
}

/// Risk level for execution capabilities
enum CapabilityRiskLevel: Int, Comparable {
    case low = 1
    case medium = 2
    case high = 3
    case critical = 4

    static func < (lhs: CapabilityRiskLevel, rhs: CapabilityRiskLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .low: return "Low Risk"
        case .medium: return "Medium Risk"
        case .high: return "High Risk"
        case .critical: return "Critical Risk"
        }
    }

    var color: String {
        switch self {
        case .low: return "00976d"     // Green
        case .medium: return "d4a017"  // Gold
        case .high: return "c75450"    // Red
        case .critical: return "ff3b30" // Bright Red
        }
    }
}

enum CapabilityDuration {
    case once
    case always
}

struct ExecutionRequest: Codable {
    let id: UUID
    let conversationId: UUID
    let language: CodeLanguage
    let code: String
    let capabilities: [ExecutionCapability]
    let timeout: TimeInterval
    let timestamp: Date
}

struct ExecutionResult: Codable {
    let id: UUID
    let stdout: String
    let stderr: String
    let exitCode: Int
    let duration: TimeInterval
    let resourceUsage: ResourceUsage
    let wasTruncated: Bool
    let secretsDetected: Bool
}

struct ResourceUsage: Codable {
    let cpuTime: TimeInterval
    let memoryBytes: Int
    let peakMemoryBytes: Int
}

struct ExecutionRecord: Identifiable, Codable {
    let id: UUID
    let conversationId: UUID
    let language: CodeLanguage
    let timestamp: Date
    let duration: TimeInterval
    let exitCode: Int
    let resourceUsage: ResourceUsage
    let capabilities: [ExecutionCapability]
}

enum ExecutionError: LocalizedError {
    case rateLimitExceeded
    case concurrentLimitExceeded
    case inputTooLarge
    case dangerousCodeDetected(String)
    case dangerousShellCommand(String)
    case capabilityDenied(ExecutionCapability)
    case runtimeNotFound(CodeLanguage)
    case shellNotAvailable(ShellType)
    case executionTimeout
    case sandboxFailure
    case invalidRequest
    case shellPermissionRequired

    var errorDescription: String? {
        switch self {
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please wait before executing more code."
        case .concurrentLimitExceeded:
            return "Too many concurrent executions. Please wait for current executions to complete."
        case .inputTooLarge:
            return "Code input is too large (max 1MB for code, 64KB for shell scripts)."
        case .dangerousCodeDetected(let pattern):
            return "Dangerous code pattern detected: \(pattern)"
        case .dangerousShellCommand(let reason):
            return "Blocked dangerous shell command: \(reason)"
        case .capabilityDenied(let capability):
            return "Capability denied: \(capability.displayName)"
        case .runtimeNotFound(let language):
            return "Runtime not found: \(language.displayName)"
        case .shellNotAvailable(let shell):
            return "\(shell.displayName) is not available on this system. \(shell.installationInstructions)"
        case .executionTimeout:
            return "Code execution exceeded time limit."
        case .sandboxFailure:
            return "Sandbox execution failed."
        case .invalidRequest:
            return "Invalid execution request."
        case .shellPermissionRequired:
            return "Shell execution requires explicit permission due to security risks."
        }
    }
}
