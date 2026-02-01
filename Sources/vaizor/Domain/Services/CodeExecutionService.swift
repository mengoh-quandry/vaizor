import Foundation

/// Service that executes code in a sandboxed environment
@MainActor
class CodeExecutionService {
    static let shared = CodeExecutionService()
    
    // Resource limits
    struct Limits {
        static let maxCPUTime: TimeInterval = 30.0
        static let maxMemory: Int = 512 * 1024 * 1024 // 512 MB
        static let maxOutputSize: Int = 10 * 1024 * 1024 // 10 MB
        static let maxFileSize: Int = 50 * 1024 * 1024 // 50 MB
        static let maxProcessCount: Int = 5
        static let maxWallClockTime: TimeInterval = 60.0
    }
    
    private var runtimeAdapters: [CodeLanguage: RuntimeAdapter] = [:]
    private var shellAdapters: [ShellType: ShellRuntimeAdapter] = [:]

    private init() {
        // Initialize runtime adapters
        runtimeAdapters[.python] = PythonRuntimeAdapter()

        // Initialize shell adapters
        for shell in ShellType.allCases {
            shellAdapters[shell] = ShellRuntimeAdapter(shellType: shell)
        }

        // Map shell languages to their adapters
        runtimeAdapters[.bash] = shellAdapters[.bash]
        runtimeAdapters[.zsh] = shellAdapters[.zsh]
        runtimeAdapters[.powershell] = shellAdapters[.powershell]

        AppLogger.shared.log("CodeExecutionService initialized with shell support", level: .info)
        logShellAvailability()
    }

    /// Log available shells for debugging
    private func logShellAvailability() {
        for (shell, available, path) in ShellType.systemShellStatus() {
            if available {
                AppLogger.shared.log("\(shell.displayName) available at: \(path ?? "unknown")", level: .debug)
            } else {
                AppLogger.shared.log("\(shell.displayName) not available", level: .debug)
            }
        }
    }
    
    /// Execute code request in sandbox
    func execute(request: ExecutionRequest) async throws -> ExecutionResult {
        guard let adapter = runtimeAdapters[request.language] else {
            throw ExecutionError.runtimeNotFound(request.language)
        }
        
        // Create ephemeral working directory
        let workDir = try createEphemeralWorkDir()
        defer {
            try? FileManager.default.removeItem(at: workDir)
        }
        
        // Prepare execution environment
        let environment = ExecutionEnvironment(
            workDir: workDir,
            capabilities: request.capabilities,
            timeout: request.timeout
        )
        
        // Execute with resource monitoring
        let startTime = Date()
        let result = try await adapter.execute(
            code: request.code,
            environment: environment
        )
        let duration = Date().timeIntervalSince(startTime)
        
        // Check resource limits
        if duration > Limits.maxWallClockTime {
            throw ExecutionError.executionTimeout
        }
        
        if result.resourceUsage.memoryBytes > Limits.maxMemory {
            throw ExecutionError.executionTimeout // Memory limit exceeded
        }
        
        // Detect and redact secrets
        let (sanitizedStdout, secretsDetected) = SecretDetector.shared.redact(result.stdout)
        let (sanitizedStderr, _) = SecretDetector.shared.redact(result.stderr)
        
        // Truncate output if needed
        let (finalStdout, wasTruncated) = truncateOutput(sanitizedStdout)
        let (finalStderr, _) = truncateOutput(sanitizedStderr)
        
        return ExecutionResult(
            id: request.id,
            stdout: finalStdout,
            stderr: finalStderr,
            exitCode: result.exitCode,
            duration: duration,
            resourceUsage: result.resourceUsage,
            wasTruncated: wasTruncated,
            secretsDetected: secretsDetected
        )
    }
    
    private func createEphemeralWorkDir() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let workDir = tempDir.appendingPathComponent("vaizor-exec-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        return workDir
    }
    
    private func truncateOutput(_ output: String) -> (String, Bool) {
        if output.count <= Limits.maxOutputSize {
            return (output, false)
        }
        
        let truncated = String(output.prefix(Limits.maxOutputSize))
        return (truncated + "\n\n[Output truncated - max size exceeded]", true)
    }
}

// MARK: - Runtime Adapter Protocol

protocol RuntimeAdapter {
    func execute(code: String, environment: ExecutionEnvironment) async throws -> RuntimeExecutionResult
}

struct ExecutionEnvironment {
    let workDir: URL
    let capabilities: [ExecutionCapability]
    let timeout: TimeInterval
}

struct RuntimeExecutionResult {
    let stdout: String
    let stderr: String
    let exitCode: Int
    let resourceUsage: ResourceUsage
}
