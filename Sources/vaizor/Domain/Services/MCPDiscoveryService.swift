import Foundation

/// Represents a server discovered from external config files
struct DiscoveredServer: Identifiable, Hashable {
    let id: String
    let name: String
    let command: String
    let args: [String]
    let env: [String: String]?
    let workingDirectory: String?
    let source: DiscoverySource
    let sourcePath: String
    var isAlreadyImported: Bool
    var securityWarning: String?  // Warning if command looks potentially unsafe

    /// Detected runtime based on command
    var runtime: DetectedRuntime {
        let cmd = command.lowercased()
        if cmd.contains("python") || cmd.hasSuffix("/python3") || cmd.hasSuffix("/python") {
            return .python
        } else if cmd.contains("node") || cmd.hasSuffix("/node") {
            return .node
        } else if cmd.contains("bun") || cmd.hasSuffix("/bun") {
            return .bun
        } else if cmd.contains("deno") || cmd.hasSuffix("/deno") {
            return .deno
        } else if cmd.hasSuffix(".sh") {
            return .shell
        } else {
            return .binary
        }
    }

    enum DetectedRuntime: String {
        case python, node, bun, deno, shell, binary

        var displayName: String {
            switch self {
            case .python: return "Python"
            case .node: return "Node.js"
            case .bun: return "Bun"
            case .deno: return "Deno"
            case .shell: return "Shell"
            case .binary: return "Binary"
            }
        }

        var icon: String {
            switch self {
            case .python: return "p.circle"
            case .node: return "n.circle"
            case .bun: return "b.circle"
            case .deno: return "d.circle"
            case .shell: return "terminal"
            case .binary: return "gearshape"
            }
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: DiscoveredServer, rhs: DiscoveredServer) -> Bool {
        lhs.id == rhs.id
    }
}

/// Service for discovering MCP servers from external configuration files
class MCPDiscoveryService {
    /// Known config file locations to scan
    private let configLocations: [(source: DiscoverySource, path: String)] = [
        (.claudeDesktop, "~/Library/Application Support/Claude/claude_desktop_config.json"),
        (.cursor, "~/.cursor/mcp.json"),
        (.claudeCode, "~/.claude/settings.json"),
        (.vscode, "~/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json"),
    ]

    /// Scan all known config locations for MCP servers
    func discoverServers(existingServers: [MCPServer] = []) async -> [DiscoveredServer] {
        var allDiscovered: [DiscoveredServer] = []
        let existingSignatures = Set(existingServers.map { serverSignature($0.command, $0.args) })

        for location in configLocations {
            let expandedPath = NSString(string: location.path).expandingTildeInPath
            let discovered = parseConfigFile(
                at: expandedPath,
                source: location.source,
                existingSignatures: existingSignatures
            )
            allDiscovered.append(contentsOf: discovered)
        }

        // Also check for .mcp.json in current directory (project dotfile)
        let currentDir = FileManager.default.currentDirectoryPath
        let dotfilePath = (currentDir as NSString).appendingPathComponent(".mcp.json")
        if FileManager.default.fileExists(atPath: dotfilePath) {
            let discovered = parseConfigFile(
                at: dotfilePath,
                source: .dotfile,
                existingSignatures: existingSignatures
            )
            allDiscovered.append(contentsOf: discovered)
        }

        return allDiscovered
    }

    /// Parse a single config file and return discovered servers
    private func parseConfigFile(
        at path: String,
        source: DiscoverySource,
        existingSignatures: Set<String>
    ) -> [DiscoveredServer] {
        guard FileManager.default.fileExists(atPath: path),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return []
        }

        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return []
            }

            // Handle different config formats
            let mcpServers: [String: Any]?

            if source == .claudeCode {
                // Claude Code stores MCP servers in a different structure
                mcpServers = json["mcpServers"] as? [String: Any]
            } else {
                // Standard format: { "mcpServers": { "name": { ... } } }
                mcpServers = json["mcpServers"] as? [String: Any]
            }

            guard let servers = mcpServers else {
                return []
            }

            var discovered: [DiscoveredServer] = []

            for (name, config) in servers {
                guard let serverConfig = config as? [String: Any],
                      let command = serverConfig["command"] as? String else {
                    continue
                }

                let args = serverConfig["args"] as? [String] ?? []
                let env = serverConfig["env"] as? [String: String]
                let cwd = serverConfig["cwd"] as? String

                let signature = serverSignature(command, args)
                let isAlreadyImported = existingSignatures.contains(signature)

                // Check for security warnings
                var securityWarning: String?
                if !isCommandSafe(command, args: args) {
                    securityWarning = "Command contains potentially dangerous patterns"
                }

                let server = DiscoveredServer(
                    id: "\(source.rawValue):\(name)",
                    name: name,
                    command: command,
                    args: args,
                    env: env,
                    workingDirectory: cwd,
                    source: source,
                    sourcePath: path,
                    isAlreadyImported: isAlreadyImported,
                    securityWarning: securityWarning
                )

                discovered.append(server)
            }

            return discovered
        } catch {
            Task { @MainActor in
                AppLogger.shared.log("Failed to parse MCP config at \(path): \(error)", level: .warning)
            }
            return []
        }
    }

    /// Generate a signature for duplicate detection
    private func serverSignature(_ command: String, _ args: [String]) -> String {
        let sortedArgs = args.sorted()
        return "\(command):\(sortedArgs.joined(separator: ":"))"
    }

    /// Convert a discovered server to an MCPServer for import
    func importServer(_ discovered: DiscoveredServer) -> MCPServer {
        MCPServer(
            id: UUID().uuidString,
            name: discovered.name,
            description: "Imported from \(discovered.source.displayName)",
            command: discovered.command,
            args: discovered.args,
            path: nil,
            env: discovered.env,
            workingDirectory: discovered.workingDirectory,
            sourceConfig: discovered.source
        )
    }

    /// Check if command exists and is executable
    func validateCommand(_ command: String) -> Bool {
        let expandedCommand = NSString(string: command).expandingTildeInPath

        // Check if it's an absolute path
        if command.hasPrefix("/") || command.hasPrefix("~") {
            return FileManager.default.isExecutableFile(atPath: expandedCommand)
        }

        // Otherwise check PATH
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [command]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// Check if a command appears safe (no shell injection patterns)
    /// Returns true if command looks safe, false if potentially dangerous
    func isCommandSafe(_ command: String, args: [String]) -> Bool {
        // Dangerous shell metacharacters
        let dangerousPatterns = [";", "|", "&", "$", "`", "(", ")", "{", "}", "<", ">", "\\n"]

        // Check command for dangerous patterns
        for pattern in dangerousPatterns {
            if command.contains(pattern) {
                return false
            }
        }

        // Check args for dangerous patterns
        for arg in args {
            for pattern in dangerousPatterns {
                if arg.contains(pattern) {
                    return false
                }
            }
        }

        // Warn about shell execution
        let shellCommands = ["/bin/sh", "/bin/bash", "/bin/zsh", "sh", "bash", "zsh"]
        let commandBasename = (command as NSString).lastPathComponent
        if shellCommands.contains(command) || shellCommands.contains(commandBasename) {
            // Shell with -c flag is particularly dangerous
            if args.contains("-c") {
                return false
            }
        }

        return true
    }

    /// Validate and sanitize a working directory path
    /// Returns nil if path is invalid or potentially dangerous
    func validateWorkingDirectory(_ path: String?) -> String? {
        guard let path = path, !path.isEmpty else {
            return nil
        }

        let expandedPath = NSString(string: path).expandingTildeInPath

        // Resolve to canonical path to prevent symlink attacks
        let url = URL(fileURLWithPath: expandedPath)
        guard let resolvedPath = try? url.resolvingSymlinksInPath().path else {
            return nil
        }

        // Ensure path exists and is a directory
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: resolvedPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return nil
        }

        // Block access to sensitive system directories
        let blockedPaths = ["/System", "/usr", "/bin", "/sbin", "/var", "/etc", "/private"]
        for blocked in blockedPaths {
            if resolvedPath.hasPrefix(blocked) {
                return nil
            }
        }

        return resolvedPath
    }
}

/// Group discovered servers by source for UI display
struct DiscoveredServerGroup: Identifiable {
    let source: DiscoverySource
    let servers: [DiscoveredServer]
    var isExpanded: Bool = true

    var id: String { source.rawValue }

    var importableCount: Int {
        servers.filter { !$0.isAlreadyImported }.count
    }
}

extension Array where Element == DiscoveredServer {
    /// Group servers by their discovery source
    func groupedBySource() -> [DiscoveredServerGroup] {
        let grouped = Dictionary(grouping: self) { $0.source }
        return grouped.map { source, servers in
            DiscoveredServerGroup(source: source, servers: servers.sorted { $0.name < $1.name })
        }.sorted { $0.servers.count > $1.servers.count }
    }
}
