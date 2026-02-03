import Foundation

/// JavaScript runtime adapter for code execution using Node.js
class JavaScriptRuntimeAdapter: RuntimeAdapter {
    private let nodePath: String?

    init() {
        // Try to find Node.js in common locations
        let possiblePaths = [
            "/usr/local/bin/node",
            "/opt/homebrew/bin/node",
            "/usr/bin/node",
            "/opt/local/bin/node"
        ]

        nodePath = possiblePaths.first { FileManager.default.fileExists(atPath: $0) }
    }

    var isAvailable: Bool {
        nodePath != nil
    }

    func execute(code: String, environment: ExecutionEnvironment) async throws -> RuntimeExecutionResult {
        guard let nodePath = nodePath else {
            // Return error result instead of throwing
            return RuntimeExecutionResult(
                stdout: "",
                stderr: "Node.js is not installed. Please install Node.js to run JavaScript code.\n\nInstall with: brew install node",
                exitCode: 1,
                resourceUsage: ResourceUsage(cpuTime: 0, memoryBytes: 0, peakMemoryBytes: 0)
            )
        }

        // Create temporary JavaScript file
        let scriptURL = environment.workDir.appendingPathComponent("script.js")
        try code.write(to: scriptURL, atomically: true, encoding: .utf8)

        // Prepare process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: nodePath)
        process.arguments = [scriptURL.path]
        process.currentDirectoryURL = environment.workDir

        // Set environment variables (minimal, secure)
        var env: [String: String] = [:]
        env["NODE_ENV"] = "production"
        env["HOME"] = environment.workDir.path // Isolated home
        env["NODE_NO_WARNINGS"] = "1"

        process.environment = env

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
            memoryBytes: estimateMemoryUsage(),
            peakMemoryBytes: estimateMemoryUsage()
        )

        return RuntimeExecutionResult(
            stdout: stdout,
            stderr: stderr,
            exitCode: Int(process.terminationStatus),
            resourceUsage: resourceUsage
        )
    }

    private func estimateMemoryUsage() -> Int {
        // Approximate memory usage for Node.js
        return 80 * 1024 * 1024 // 80 MB estimate (Node is heavier than Python)
    }
}
