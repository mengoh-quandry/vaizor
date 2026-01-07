import Foundation

/// Python runtime adapter for code execution
class PythonRuntimeAdapter: RuntimeAdapter {
    private let pythonPath: String
    
    init() {
        // Try to find Python 3 in common locations
        let possiblePaths = [
            "/usr/bin/python3",
            "/usr/local/bin/python3",
            "/opt/homebrew/bin/python3",
            "/usr/bin/python"
        ]
        
        pythonPath = possiblePaths.first { FileManager.default.fileExists(atPath: $0) } ?? "python3"
    }
    
    func execute(code: String, environment: ExecutionEnvironment) async throws -> RuntimeExecutionResult {
        // Create temporary Python script file
        let scriptURL = environment.workDir.appendingPathComponent("script.py")
        try code.write(to: scriptURL, atomically: true, encoding: .utf8)
        
        // Prepare process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = ["-u", scriptURL.path] // -u for unbuffered output
        process.currentDirectoryURL = environment.workDir
        
        // Set environment variables (minimal, secure)
        var env: [String: String] = [:]
        env["PYTHONUNBUFFERED"] = "1"
        env["PYTHONDONTWRITEBYTECODE"] = "1"
        env["PYTHONNOUSERSITE"] = "1"
        env["HOME"] = environment.workDir.path // Isolated home
        
        process.environment = env
        
        // Note: Resource limits would be set via rlimit in XPC service
        // For now, we rely on timeout mechanism
        
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
            throw ExecutionError.sandboxFailure
        }
        
        // Wait with timeout
        let timeoutTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(environment.timeout * 1_000_000_000))
            if process.isRunning {
                process.terminate()
                // Force kill after grace period
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                if process.isRunning {
                    process.terminate()
                }
            }
        }
        
        process.waitUntilExit()
        timeoutTask.cancel()
        
        let duration = Date().timeIntervalSince(startTime)
        
        // Read output
        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""
        
        // Get resource usage (approximate)
        let resourceUsage = ResourceUsage(
            cpuTime: duration,
            memoryBytes: estimateMemoryUsage(process: process),
            peakMemoryBytes: estimateMemoryUsage(process: process)
        )
        
        return RuntimeExecutionResult(
            stdout: stdout,
            stderr: stderr,
            exitCode: Int(process.terminationStatus),
            resourceUsage: resourceUsage
        )
    }
    
    private func estimateMemoryUsage(process: Process) -> Int {
        // Approximate memory usage - in production, use task_info
        // For now, return a conservative estimate
        return 50 * 1024 * 1024 // 50 MB estimate
    }
}
