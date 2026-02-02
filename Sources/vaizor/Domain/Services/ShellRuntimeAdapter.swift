import Foundation

/// Shell runtime adapter for executing bash, zsh, and PowerShell commands
class ShellRuntimeAdapter: RuntimeAdapter {
    private let shellType: ShellType

    init(shellType: ShellType) {
        self.shellType = shellType
    }

    func execute(code: String, environment: ExecutionEnvironment) async throws -> RuntimeExecutionResult {
        // Verify shell is available
        guard shellType.isAvailable else {
            throw ExecutionError.shellNotAvailable(shellType)
        }

        // Validate shell code for dangerous patterns
        if let blockedReason = ShellSecurityValidator.validateCommand(code, shellType: shellType) {
            throw ExecutionError.dangerousShellCommand(blockedReason)
        }

        // Create temporary script file
        let scriptURL = createScriptFile(code: code, in: environment.workDir)
        try code.write(to: scriptURL, atomically: true, encoding: .utf8)

        // Prepare process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shellType.executable)
        process.arguments = buildArguments(scriptPath: scriptURL.path)
        process.currentDirectoryURL = environment.workDir

        // Set sandboxed environment
        process.environment = buildSandboxedEnvironment(workDir: environment.workDir)

        // Capture output
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Start process with timeout
        let startTime = Date()

        do {
            try process.run()
        } catch {
            await MainActor.run {
                AppLogger.shared.log("Shell execution failed to start: \(error)", level: .error)
            }
            throw ExecutionError.sandboxFailure
        }

        // Enforce timeout
        let timeout = min(environment.timeout, shellType.maxTimeout)
        let timeoutTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            if process.isRunning {
                await MainActor.run {
                    AppLogger.shared.log("Shell execution timed out after \(timeout)s", level: .warning)
                }
                process.terminate()
                // Force kill after grace period
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                if process.isRunning {
                    process.terminate()
                }
            }
        }

        process.waitUntilExit()
        timeoutTask.cancel()

        let duration = Date().timeIntervalSince(startTime)

        // Read output with size limits
        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        var stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        var stderr = String(data: stderrData, encoding: .utf8) ?? ""

        // Truncate if too large
        let maxOutput = 1024 * 1024 // 1 MB
        if stdout.count > maxOutput {
            stdout = String(stdout.prefix(maxOutput)) + "\n[Output truncated]"
        }
        if stderr.count > maxOutput {
            stderr = String(stderr.prefix(maxOutput)) + "\n[Error output truncated]"
        }

        // Check if timed out
        let timedOut = duration >= timeout && process.terminationStatus != 0

        // Get resource usage (approximate)
        let resourceUsage = ResourceUsage(
            cpuTime: duration,
            memoryBytes: estimateMemoryUsage(),
            peakMemoryBytes: estimateMemoryUsage()
        )

        if timedOut {
            stderr += "\n[Execution timed out after \(Int(timeout)) seconds]"
        }

        return RuntimeExecutionResult(
            stdout: stdout,
            stderr: stderr,
            exitCode: Int(process.terminationStatus),
            resourceUsage: resourceUsage
        )
    }

    // MARK: - Private Helpers

    private func createScriptFile(code: String, in workDir: URL) -> URL {
        let ext: String
        switch shellType {
        case .bash, .zsh:
            ext = "sh"
        case .powershell:
            ext = "ps1"
        }
        return workDir.appendingPathComponent("script.\(ext)")
    }

    private func buildArguments(scriptPath: String) -> [String] {
        switch shellType {
        case .bash:
            return [
                "--noprofile",  // Don't read profile files
                "--norc",       // Don't read .bashrc
                "-e",           // Exit on error
                scriptPath
            ]
        case .zsh:
            return [
                "--no-globalrcs",  // Don't read global startup files
                "--no-rcs",        // Don't read user startup files
                "-e",              // Exit on error
                scriptPath
            ]
        case .powershell:
            return [
                "-NoProfile",           // Don't load profile
                "-NonInteractive",      // Non-interactive mode
                "-ExecutionPolicy", "Bypass",  // Allow script execution
                "-File", scriptPath
            ]
        }
    }

    private func buildSandboxedEnvironment(workDir: URL) -> [String: String] {
        var env: [String: String] = [:]

        // Common sandboxed environment
        env["HOME"] = workDir.path
        env["TMPDIR"] = workDir.path
        env["TMP"] = workDir.path
        env["TEMP"] = workDir.path

        // Restrict PATH to essential commands only
        env["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin"

        // Shell-specific settings
        switch shellType {
        case .bash:
            env["BASH_ENV"] = ""  // Don't source any startup file
            env["ENV"] = ""
            env["HISTFILE"] = "/dev/null"  // Don't save history
            env["HISTSIZE"] = "0"

        case .zsh:
            env["ZDOTDIR"] = workDir.path  // Use work dir for zsh config
            env["HISTFILE"] = "/dev/null"
            env["HISTSIZE"] = "0"
            env["SAVEHIST"] = "0"

        case .powershell:
            env["PSModulePath"] = ""  // Restrict module loading
            env["POWERSHELL_TELEMETRY_OPTOUT"] = "1"
        }

        // Disable various shell features for security
        env["SHELL"] = shellType.executable
        env["TERM"] = "dumb"  // Basic terminal
        env["LANG"] = "en_US.UTF-8"
        env["LC_ALL"] = "en_US.UTF-8"

        return env
    }

    private func estimateMemoryUsage() -> Int {
        // Conservative estimate for shell processes
        return 30 * 1024 * 1024 // 30 MB
    }
}

// MARK: - Shell Availability Check

extension ShellType {
    /// Get all available shells on the current system
    static var availableShells: [ShellType] {
        return allCases.filter { $0.isAvailable }
    }

    /// Check system shell availability and return a summary
    static func systemShellStatus() -> [(shell: ShellType, available: Bool, path: String?)] {
        return allCases.map { shell in
            let available = shell.isAvailable
            let path: String? = available ? shell.executable : nil
            return (shell, available, path)
        }
    }
}
