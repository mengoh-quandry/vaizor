import Foundation

/// Broker service that validates execution requests and enforces security policies
@MainActor
class ExecutionBroker: ObservableObject {
    static let shared = ExecutionBroker()
    
    @Published var executionHistory: [ExecutionRecord] = []
    @Published var capabilityPermissions: [String: Set<ExecutionCapability>] = [:] // conversationId -> capabilities
    
    private let maxExecutionsPerMinute = 10
    private let maxConcurrentExecutions = 3
    private var recentExecutions: [Date] = []
    private var activeExecutions: Set<UUID> = []
    
    private init() {}
    
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
}

// MARK: - Models

enum CodeLanguage: String, Codable {
    case python = "python"
    case javascript = "javascript"
    case swift = "swift"
    
    var displayName: String {
        switch self {
        case .python: return "Python"
        case .javascript: return "JavaScript"
        case .swift: return "Swift"
        }
    }
}

enum ExecutionCapability: String, Codable, CaseIterable {
    case filesystemRead = "filesystem.read"
    case filesystemWrite = "filesystem.write"
    case network = "network"
    case clipboardRead = "clipboard.read"
    case clipboardWrite = "clipboard.write"
    case processSpawn = "process.spawn"
    
    var displayName: String {
        switch self {
        case .filesystemRead: return "Read Files"
        case .filesystemWrite: return "Write Files"
        case .network: return "Network Access"
        case .clipboardRead: return "Read Clipboard"
        case .clipboardWrite: return "Write Clipboard"
        case .processSpawn: return "Spawn Processes"
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
    case capabilityDenied(ExecutionCapability)
    case runtimeNotFound(CodeLanguage)
    case executionTimeout
    case sandboxFailure
    case invalidRequest
    
    var errorDescription: String? {
        switch self {
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please wait before executing more code."
        case .concurrentLimitExceeded:
            return "Too many concurrent executions. Please wait for current executions to complete."
        case .inputTooLarge:
            return "Code input is too large (max 1MB)."
        case .dangerousCodeDetected(let pattern):
            return "Dangerous code pattern detected: \(pattern)"
        case .capabilityDenied(let capability):
            return "Capability denied: \(capability.displayName)"
        case .runtimeNotFound(let language):
            return "Runtime not found: \(language.displayName)"
        case .executionTimeout:
            return "Code execution exceeded time limit."
        case .sandboxFailure:
            return "Sandbox execution failed."
        case .invalidRequest:
            return "Invalid execution request."
        }
    }
}
