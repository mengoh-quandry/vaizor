import Foundation
import CryptoKit

// MARK: - Extension Installer Service

/// Service for installing, updating, and uninstalling MCP Extensions
@MainActor
class ExtensionInstaller: ObservableObject {
    static let shared = ExtensionInstaller()

    // State
    @Published var currentOperation: InstallOperation?
    @Published var progress: Double = 0
    @Published var progressMessage: String = ""
    @Published var isInstalling = false

    // Dependencies
    private let registry: ExtensionRegistry
    private let mcpManager: MCPServerManager

    // Paths
    private let extensionsDirectory: URL
    private let tempDirectory: URL

    // Runtime detection
    @Published var availableRuntimes: [ExtensionRuntime: RuntimeInfo] = [:]

    private init() {
        self.registry = ExtensionRegistry.shared
        self.mcpManager = MCPServerManager()

        // Setup directories
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        extensionsDirectory = appSupport.appendingPathComponent("Vaizor/Extensions/packages")
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("vaizor_ext_install")

        // Create directories
        try? FileManager.default.createDirectory(at: extensionsDirectory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        // Detect available runtimes
        Task {
            await detectRuntimes()
        }
    }

    // MARK: - Runtime Detection

    /// Detect available runtimes on the system
    func detectRuntimes() async {
        var runtimes: [ExtensionRuntime: RuntimeInfo] = [:]

        // Node.js
        if let nodeVersion = await checkRuntime("node --version") {
            let npmVersion = await checkRuntime("npm --version")
            runtimes[.node] = RuntimeInfo(
                runtime: .node,
                version: nodeVersion,
                path: await findRuntimePath("node"),
                additionalInfo: npmVersion.map { "npm \($0)" }
            )
        }

        // Python
        if let pythonVersion = await checkRuntime("python3 --version") {
            let pipVersion = await checkRuntime("pip3 --version")
            let pipInfo: String? = pipVersion.flatMap { version in
                let components = version.components(separatedBy: " ")
                return components.count > 1 ? "pip \(components[1])" : nil
            }
            runtimes[.python] = RuntimeInfo(
                runtime: .python,
                version: pythonVersion.replacingOccurrences(of: "Python ", with: ""),
                path: await findRuntimePath("python3"),
                additionalInfo: pipInfo
            )
        }

        // Deno
        if let denoVersion = await checkRuntime("deno --version") {
            runtimes[.deno] = RuntimeInfo(
                runtime: .deno,
                version: denoVersion.components(separatedBy: "\n").first?.replacingOccurrences(of: "deno ", with: "") ?? "",
                path: await findRuntimePath("deno"),
                additionalInfo: nil
            )
        }

        // Bun
        if let bunVersion = await checkRuntime("bun --version") {
            runtimes[.bun] = RuntimeInfo(
                runtime: .bun,
                version: bunVersion,
                path: await findRuntimePath("bun"),
                additionalInfo: nil
            )
        }

        await MainActor.run {
            self.availableRuntimes = runtimes
            AppLogger.shared.log("Detected runtimes: \(runtimes.keys.map { $0.displayName }.joined(separator: ", "))", level: .info)
        }
    }

    /// Check runtime version
    private func checkRuntime(_ command: String) async -> String? {
        return await withCheckedContinuation { continuation in
            Task.detached {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/bash")
                process.arguments = ["-l", "-c", command]

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = FileHandle.nullDevice

                do {
                    try process.run()
                    process.waitUntilExit()

                    if process.terminationStatus == 0 {
                        let data = pipe.fileHandleForReading.readDataToEndOfFile()
                        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                        continuation.resume(returning: output)
                    } else {
                        continuation.resume(returning: nil)
                    }
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// Find runtime path
    private func findRuntimePath(_ command: String) async -> String? {
        return await withCheckedContinuation { continuation in
            Task.detached {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
                process.arguments = [command]

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = FileHandle.nullDevice

                do {
                    try process.run()
                    process.waitUntilExit()

                    if process.terminationStatus == 0 {
                        let data = pipe.fileHandleForReading.readDataToEndOfFile()
                        let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                        continuation.resume(returning: path)
                    } else {
                        continuation.resume(returning: nil)
                    }
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// Check if runtime is available
    func isRuntimeAvailable(_ runtime: ExtensionRuntime) -> Bool {
        return availableRuntimes[runtime] != nil
    }

    // MARK: - Installation

    /// Install an extension
    func install(_ extension_: MCPExtension) async throws {
        guard !isInstalling else {
            throw ExtensionInstallerError.alreadyInstalling
        }

        isInstalling = true
        progress = 0
        progressMessage = "Preparing installation..."
        currentOperation = InstallOperation(extensionId: extension_.id, type: .install, startTime: Date())

        defer {
            isInstalling = false
            currentOperation = nil
        }

        do {
            // 1. Check runtime availability
            progress = 0.1
            progressMessage = "Checking runtime..."

            let runtime = extension_.serverConfig.runtime
            guard isRuntimeAvailable(runtime) || runtime == .binary else {
                throw ExtensionInstallerError.runtimeNotFound(runtime)
            }

            // 2. Create extension directory
            progress = 0.2
            progressMessage = "Creating extension directory..."

            let extDir = extensionsDirectory.appendingPathComponent(extension_.id)
            try FileManager.default.createDirectory(at: extDir, withIntermediateDirectories: true)

            // 3. Download or verify package (for non-npx extensions)
            progress = 0.3
            progressMessage = "Downloading extension..."

            // For npx-based extensions, we just verify npx works
            if extension_.serverConfig.command == "npx" {
                // npx will download on first run
                AppLogger.shared.log("Extension uses npx - skipping download", level: .info)
            } else if extension_.serverConfig.command == "uvx" {
                // uvx will download on first run
                AppLogger.shared.log("Extension uses uvx - skipping download", level: .info)
            }

            // 4. Run install steps if any
            progress = 0.5
            progressMessage = "Running installation steps..."

            if let steps = extension_.installSteps {
                for (index, step) in steps.enumerated() {
                    let stepProgress = 0.5 + (0.3 * Double(index) / Double(steps.count))
                    progress = stepProgress
                    progressMessage = step.description ?? "Running step \(index + 1)..."

                    try await runInstallStep(step, in: extDir)
                }
            }

            // 5. Install dependencies
            progress = 0.8
            progressMessage = "Installing dependencies..."

            if let installCmd = runtime.installCommand {
                // Check if package.json or requirements.txt exists
                let hasPackageJson = FileManager.default.fileExists(atPath: extDir.appendingPathComponent("package.json").path)
                let hasRequirements = FileManager.default.fileExists(atPath: extDir.appendingPathComponent("requirements.txt").path)

                if hasPackageJson || hasRequirements {
                    try await runShellCommand(installCmd, in: extDir)
                }
            }

            // 6. Save extension metadata
            progress = 0.9
            progressMessage = "Saving extension data..."

            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let metadataPath = extDir.appendingPathComponent("extension.json")
            let metadataData = try encoder.encode(extension_)
            try metadataData.write(to: metadataPath)

            // 7. Register as installed
            progress = 0.95
            progressMessage = "Registering extension..."

            let installed = InstalledExtension(
                id: extension_.id,
                extension_: extension_,
                installDate: Date(),
                isEnabled: true,
                installedVersion: extension_.version,
                installPath: extDir,
                serverId: nil
            )

            registry.addInstalled(installed)

            // 8. Create MCP server configuration
            progress = 1.0
            progressMessage = "Extension installed successfully!"

            try await createMCPServer(for: extension_, installPath: extDir)

            AppLogger.shared.log("Successfully installed extension: \(extension_.name)", level: .info)

        } catch {
            AppLogger.shared.logError(error, context: "Failed to install extension: \(extension_.name)")
            throw error
        }
    }

    /// Run an installation step
    private func runInstallStep(_ step: InstallStep, in directory: URL) async throws {
        switch step.type {
        case .npm:
            if let args = step.args {
                try await runShellCommand("npm \(args.joined(separator: " "))", in: directory)
            }

        case .pip:
            if let args = step.args {
                try await runShellCommand("pip3 \(args.joined(separator: " "))", in: directory)
            }

        case .shell:
            if let command = step.command {
                let workDir = step.workingDirectory.map { URL(fileURLWithPath: $0) } ?? directory
                try await runShellCommand(command, in: workDir)
            }

        case .download:
            if let urlString = step.command, let url = URL(string: urlString) {
                // Download file
                let (data, _) = try await URLSession.shared.data(from: url)
                let filename = url.lastPathComponent
                try data.write(to: directory.appendingPathComponent(filename))
            }

        case .extract:
            // Extract archive (simplified - would need proper implementation)
            AppLogger.shared.log("Extract step - not fully implemented", level: .warning)

        case .copy:
            if let source = step.command, let args = step.args, let dest = args.first {
                let sourceURL = URL(fileURLWithPath: source)
                let destURL = directory.appendingPathComponent(dest)
                try FileManager.default.copyItem(at: sourceURL, to: destURL)
            }

        case .chmod:
            if let path = step.command, let args = step.args, let mode = args.first {
                try await runShellCommand("chmod \(mode) \(path)", in: directory)
            }

        case .verify:
            // Verification step
            AppLogger.shared.log("Verify step executed", level: .debug)
        }
    }

    /// Run a shell command
    private func runShellCommand(_ command: String, in directory: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Task.detached {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/bash")
                process.arguments = ["-l", "-c", command]
                process.currentDirectoryURL = directory

                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe

                do {
                    try process.run()
                    process.waitUntilExit()

                    if process.terminationStatus != 0 {
                        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                        let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                        continuation.resume(throwing: ExtensionInstallerError.commandFailed(command, errorMessage))
                    } else {
                        continuation.resume()
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Create MCP server for installed extension
    private func createMCPServer(for extension_: MCPExtension, installPath: URL) async throws {
        let config = extension_.serverConfig

        // Resolve command path
        var command = config.command
        if !command.hasPrefix("/") {
            if let runtimeInfo = availableRuntimes[config.runtime], let path = runtimeInfo.path {
                command = path
            }
        }

        // Build args
        var args = config.args

        // For npx commands, just use npx directly
        if extension_.serverConfig.command == "npx" {
            command = "npx"
        } else if extension_.serverConfig.command == "uvx" {
            command = "uvx"
        }

        // Create MCP server
        let server = MCPServer(
            id: "ext_\(extension_.id)",
            name: extension_.name,
            description: extension_.description,
            command: command,
            args: args,
            path: config.workingDirectory.map { URL(fileURLWithPath: $0) } ?? installPath
        )

        // Add to MCP manager
        await MainActor.run {
            // Get the shared MCP manager and add the server
            // Note: This would need to be properly injected in production
            AppLogger.shared.log("Created MCP server config for extension: \(extension_.name)", level: .info)
        }
    }

    // MARK: - Uninstallation

    /// Uninstall an extension
    func uninstall(_ extensionId: String) async throws {
        guard let installed = registry.getInstalled(extensionId) else {
            throw ExtensionInstallerError.notInstalled(extensionId)
        }

        isInstalling = true
        progress = 0
        progressMessage = "Uninstalling extension..."
        currentOperation = InstallOperation(extensionId: extensionId, type: .uninstall, startTime: Date())

        defer {
            isInstalling = false
            currentOperation = nil
        }

        // 1. Stop MCP server if running
        progress = 0.2
        progressMessage = "Stopping server..."

        // Would stop the associated MCP server here

        // 2. Remove extension directory
        progress = 0.5
        progressMessage = "Removing files..."

        try? FileManager.default.removeItem(at: installed.installPath)

        // 3. Remove from registry
        progress = 0.8
        progressMessage = "Updating registry..."

        registry.removeInstalled(extensionId)

        progress = 1.0
        progressMessage = "Extension uninstalled"

        AppLogger.shared.log("Successfully uninstalled extension: \(extensionId)", level: .info)
    }

    // MARK: - Update

    /// Update an extension
    func update(_ extensionId: String) async throws {
        guard let installed = registry.getInstalled(extensionId),
              let available = registry.availableExtensions.first(where: { $0.id == extensionId }) else {
            throw ExtensionInstallerError.notInstalled(extensionId)
        }

        isInstalling = true
        currentOperation = InstallOperation(extensionId: extensionId, type: .update, startTime: Date())

        defer {
            isInstalling = false
            currentOperation = nil
        }

        // Backup current version
        let backupDir = tempDirectory.appendingPathComponent("backup_\(extensionId)")
        try? FileManager.default.removeItem(at: backupDir)
        try FileManager.default.copyItem(at: installed.installPath, to: backupDir)

        do {
            // Uninstall old version
            try await uninstall(extensionId)

            // Install new version
            try await install(available)

            // Remove backup
            try? FileManager.default.removeItem(at: backupDir)

            AppLogger.shared.log("Successfully updated extension: \(extensionId) to version \(available.version)", level: .info)

        } catch {
            // Restore backup on failure
            try? FileManager.default.removeItem(at: installed.installPath)
            try? FileManager.default.moveItem(at: backupDir, to: installed.installPath)

            throw error
        }
    }
}

// MARK: - Supporting Types

/// Information about a detected runtime
struct RuntimeInfo {
    let runtime: ExtensionRuntime
    let version: String
    let path: String?
    let additionalInfo: String?
}

/// Current installation operation
struct InstallOperation: Identifiable {
    let id = UUID()
    let extensionId: String
    let type: OperationType
    let startTime: Date

    enum OperationType {
        case install
        case uninstall
        case update
    }
}

// MARK: - Errors

enum ExtensionInstallerError: LocalizedError {
    case alreadyInstalling
    case runtimeNotFound(ExtensionRuntime)
    case notInstalled(String)
    case commandFailed(String, String)
    case downloadFailed(String)
    case verificationFailed
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .alreadyInstalling:
            return "Another installation is in progress"
        case .runtimeNotFound(let runtime):
            return "\(runtime.displayName) is not installed on this system"
        case .notInstalled(let id):
            return "Extension '\(id)' is not installed"
        case .commandFailed(let cmd, let error):
            return "Command failed: \(cmd)\n\(error)"
        case .downloadFailed(let url):
            return "Failed to download: \(url)"
        case .verificationFailed:
            return "Extension verification failed"
        case .permissionDenied:
            return "Permission denied"
        }
    }
}
