import Foundation
import GRDB

// MCP (Model Context Protocol) Server Manager
@MainActor
@preconcurrency
class MCPServerManager: ObservableObject {
    @Published var availableServers: [MCPServer] = []
    @Published var enabledServers: Set<String> = []
    @Published var availableTools: [MCPTool] = []
    @Published var serverErrors: [String: String] = [:] // Track errors by server ID

    private var serverProcesses: [String: MCPServerConnection] = [:]
    private let legacyConfigURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let vaizorDir = appSupport.appendingPathComponent("Vaizor")
        try? FileManager.default.createDirectory(at: vaizorDir, withIntermediateDirectories: true)
        legacyConfigURL = vaizorDir.appendingPathComponent("mcp-servers.json")

        loadServers()
    }

    func discoverServers() {
        // Reload from saved config
        loadServers()
    }

    private func loadServers() {
        do {
            var servers = try DatabaseManager.shared.dbQueue.read { db in
                try MCPServerRecord.fetchAll(db).map { $0.asModel() }
            }

            // If no servers in database, try to import from legacy JSON
            if servers.isEmpty {
                let imported = importLegacyServersIfNeeded()
                if !imported.isEmpty {
                    servers = imported
                    AppLogger.shared.log("Imported \(imported.count) MCP servers from legacy JSON", level: .info)
                } else {
                    // Check if legacy JSON exists but wasn't imported (maybe migration failed)
                    if FileManager.default.fileExists(atPath: legacyConfigURL.path) {
                        AppLogger.shared.log("Legacy MCP servers JSON found but import failed. Check logs for errors.", level: .warning)
                    }
                }
            }

            availableServers = servers
            
            // Only remove legacy JSON if we successfully loaded servers from database
            if !servers.isEmpty && FileManager.default.fileExists(atPath: legacyConfigURL.path) {
                // Keep legacy JSON as backup for now - don't delete immediately
                // User can manually delete it after confirming servers are working
                AppLogger.shared.log("MCP servers loaded from database. Legacy JSON kept as backup at: \(legacyConfigURL.path)", level: .info)
            }
            
            if servers.isEmpty {
                AppLogger.shared.log("No MCP servers found. Add servers in Settings → MCP Servers", level: .info)
            } else {
                AppLogger.shared.log("Loaded \(servers.count) MCP server(s) from database", level: .info)
            }
        } catch {
            AppLogger.shared.logError(error, context: "Failed to load MCP servers")
            availableServers = []
            
            // Try to recover from legacy JSON if database read failed
            let recovered = importLegacyServersIfNeeded()
            if !recovered.isEmpty {
                availableServers = recovered
                AppLogger.shared.log("Recovered \(recovered.count) MCP server(s) from legacy JSON after database error", level: .warning)
            }
        }

        // Servers are started on-demand to reduce launch overhead.
    }

    private func importLegacyServersIfNeeded() -> [MCPServer] {
        guard FileManager.default.fileExists(atPath: legacyConfigURL.path),
              let data = try? Data(contentsOf: legacyConfigURL),
              let servers = try? JSONDecoder().decode([MCPServer].self, from: data) else {
            return []
        }

        // Only import if we have servers to import
        guard !servers.isEmpty else {
            return []
        }

        do {
            // Check if servers already exist in database to avoid duplicates
            let existingIds = try DatabaseManager.shared.dbQueue.read { db in
                try MCPServerRecord.fetchAll(db).map { $0.id }
            }
            
            var importedCount = 0
            try DatabaseManager.shared.dbQueue.write { db in
                for server in servers {
                    // Skip if already exists
                    if existingIds.contains(server.id) {
                        continue
                    }
                    try MCPServerRecord(server).save(db)
                    importedCount += 1
                }
            }
            
            if importedCount > 0 {
                AppLogger.shared.log("Imported \(importedCount) new MCP server(s) from legacy JSON to database", level: .info)
            } else {
                AppLogger.shared.log("All MCP servers from legacy JSON already exist in database", level: .info)
            }
        } catch {
            AppLogger.shared.logError(error, context: "Failed to migrate MCP servers from legacy JSON")
            // Return servers anyway so they can be used even if database save failed
            return servers
        }

        return servers
    }

    private func upsertServer(_ server: MCPServer) {
        do {
            try DatabaseManager.shared.dbQueue.write { db in
                try MCPServerRecord(server).save(db)
            }
        } catch {
            AppLogger.shared.logError(error, context: "Failed to save MCP server")
        }
    }

    private func deleteServer(_ server: MCPServer) {
        do {
            _ = try DatabaseManager.shared.dbQueue.write { db in
                try MCPServerRecord.deleteOne(db, key: server.id)
            }
        } catch {
            AppLogger.shared.logError(error, context: "Failed to delete MCP server")
        }
    }

    func addServer(_ server: MCPServer) {
        availableServers.append(server)
        upsertServer(server)
    }

    func removeServer(_ server: MCPServer) {
        stopServer(server)
        availableServers.removeAll { $0.id == server.id }
        deleteServer(server)
    }

    func updateServer(_ server: MCPServer) {
        if let index = availableServers.firstIndex(where: { $0.id == server.id }) {
            let wasRunning = enabledServers.contains(server.id)
            if wasRunning {
                stopServer(availableServers[index])
            }

            availableServers[index] = server
            upsertServer(server)

            if wasRunning {
                Task {
                    try? await startServer(server)
                }
            }
        }
    }

    func testConnection(_ server: MCPServer) async -> (Bool, String) {
        do {
            let process = Process()

            // Check if command exists
            let whichProcess = Process()
            whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
            whichProcess.arguments = [server.command]

            let whichPipe = Pipe()
            whichProcess.standardOutput = whichPipe
            whichProcess.standardError = Pipe()

            try whichProcess.run()
            whichProcess.waitUntilExit()

            if whichProcess.terminationStatus != 0 {
                return (false, "Command '\(server.command)' not found in PATH")
            }

            let whichData = whichPipe.fileHandleForReading.readDataToEndOfFile()
            guard let commandPath = String(data: whichData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !commandPath.isEmpty else {
                return (false, "Command not found")
            }

            // Try to run the server briefly to test
            process.executableURL = URL(fileURLWithPath: commandPath)
            process.arguments = server.args

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            try process.run()

            // Give it a moment to start
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            if process.isRunning {
                process.terminate()
                return (true, "Connection successful")
            } else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                return (false, "Server failed to start: \(errorOutput.prefix(100))")
            }
        } catch {
            return (false, "Error: \(error.localizedDescription)")
        }
    }

    func startServer(_ server: MCPServer) async throws {
        AppLogger.shared.log("Starting MCP server: \(server.name) (ID: \(server.id))", level: .info)

        // Check if already running
        if serverProcesses.keys.contains(server.id) {
            AppLogger.shared.log("MCP server \(server.name) is already running", level: .info)
            // Already running, ensure it's in enabled set
            await MainActor.run {
                _ = enabledServers.insert(server.id)
            }
            return
        }

        // Track what we add for cleanup on error
        var connection: MCPServerConnection?
        var toolsAdded: [MCPTool] = []
        var connectionStarted = false

        do {
            // Resolve command path
            var commandPath = server.command
            AppLogger.shared.log("Resolving command path for: \(server.command)", level: .debug)
            if !commandPath.hasPrefix("/") {
                do {
                    commandPath = try await resolveCommandPath(server.command)
                    AppLogger.shared.log("Resolved command path to: \(commandPath)", level: .debug)
                } catch {
                    AppLogger.shared.logError(error, context: "Failed to resolve command path for \(server.command)")
                    throw error
                }
            }

            // Create MCP server connection
            AppLogger.shared.log("Creating MCP server connection with command: \(commandPath), args: \(server.args)", level: .debug)
            connection = try MCPServerConnection(
                command: commandPath,
                arguments: server.args,
                workingDirectory: server.path,
                onDisconnect: { [weak self] serverId in
                    Task { @MainActor in
                        self?.handleServerDisconnection(serverId: serverId)
                    }
                },
                serverId: server.id
            )
            AppLogger.shared.log("MCP server connection object created successfully", level: .debug)

            // Start the process
            AppLogger.shared.log("Starting MCP server process", level: .debug)
            try connection!.start()
            connectionStarted = true
            AppLogger.shared.log("MCP server process started", level: .debug)

            // Initialize the MCP server
            AppLogger.shared.log("Initializing MCP server protocol", level: .debug)
            try await connection!.initialize()
            AppLogger.shared.log("MCP server initialized successfully", level: .debug)

            // Discover available tools
            AppLogger.shared.log("Discovering MCP server tools", level: .debug)
            let tools = try await connection!.listTools()
            AppLogger.shared.log("Discovered \(tools.count) tools from MCP server", level: .info)

            // Atomic state update with cleanup tracking
            await MainActor.run {
                self.serverProcesses[server.id] = connection!
                self.enabledServers.insert(server.id)
                
                // Clear any previous errors for this server
                self.serverErrors.removeValue(forKey: server.id)

                // Add tools to available tools with server prefix
                for tool in tools {
                    var prefixedTool = tool
                    prefixedTool.serverId = server.id
                    prefixedTool.serverName = server.name
                    self.availableTools.append(prefixedTool)
                    toolsAdded.append(prefixedTool)
                }

                AppLogger.shared.log("MCP server \(server.name) started successfully with \(tools.count) tools", level: .info)
            }
        } catch {
            // Cleanup on any error
            AppLogger.shared.logError(error, context: "Failed to start MCP server \(server.name)")
            
            if connectionStarted {
                connection?.stop()
            }
            
            await MainActor.run {
                self.serverProcesses.removeValue(forKey: server.id)
                self.enabledServers.remove(server.id)
                for tool in toolsAdded {
                    self.availableTools.removeAll { $0.id == tool.id }
                }
                // Store error for UI display
                self.serverErrors[server.id] = error.localizedDescription
            }
            
            throw error
        }
    }
    
    private func handleServerDisconnection(serverId: String) {
        AppLogger.shared.log("MCP server disconnected unexpectedly (ID: \(serverId))", level: .warning)
        
        // Find server name for logging
        let serverName = availableServers.first(where: { $0.id == serverId })?.name ?? "Unknown"
        
        // Clean up state
        serverProcesses.removeValue(forKey: serverId)
        enabledServers.remove(serverId)
        availableTools.removeAll { $0.serverId == serverId }
        serverErrors[serverId] = "Server disconnected unexpectedly"
        
        AppLogger.shared.log("Cleaned up disconnected MCP server: \(serverName)", level: .info)
    }
    
    func clearError(for serverId: String) {
        serverErrors.removeValue(forKey: serverId)
    }

    private func resolveCommandPath(_ command: String) async throws -> String {
        let whichProcess = Process()
        whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        whichProcess.arguments = [command]

        let whichPipe = Pipe()
        whichProcess.standardOutput = whichPipe
        whichProcess.standardError = Pipe()

        try whichProcess.run()
        whichProcess.waitUntilExit()

        guard whichProcess.terminationStatus == 0 else {
            throw NSError(domain: "MCPServer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Command '\(command)' not found in PATH"])
        }

        let data = whichPipe.fileHandleForReading.readDataToEndOfFile()
        guard let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty else {
            throw NSError(domain: "MCPServer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Command not found"])
        }

        return path
    }

    func stopServer(_ server: MCPServer) {
        AppLogger.shared.log("Stopping MCP server: \(server.name) (ID: \(server.id))", level: .info)
        guard let connection = serverProcesses[server.id] else {
            AppLogger.shared.log("MCP server \(server.name) is not running", level: .warning)
            return
        }

        connection.stop()
        serverProcesses.removeValue(forKey: server.id)
        enabledServers.remove(server.id)

        // Remove tools from this server
        availableTools.removeAll { $0.serverId == server.id }

        AppLogger.shared.log("MCP server \(server.name) stopped", level: .info)
    }

    func callTool(toolName: String, arguments: [String: Any]) async -> MCPToolResult {
        // Check for built-in tools first
        if toolName == "web_search" {
            return await callBuiltInWebSearch(arguments: arguments)
        }
        
        if toolName == "execute_code" {
            return await callBuiltInCodeExecution(arguments: arguments)
        }
        
        // Find which server provides this tool
        guard let tool = availableTools.first(where: { $0.name == toolName }),
              let serverId = tool.serverId,
              let connection = serverProcesses[serverId] else {
            let errorMsg = "Tool '\(toolName)' not found or server not running"
            AppLogger.shared.log(errorMsg, level: .error)
            return MCPToolResult(
                content: [MCPContent(type: "text", text: errorMsg)],
                isError: true
            )
        }

        AppLogger.shared.log("Calling MCP tool: \(toolName) on server \(tool.serverName ?? "unknown")", level: .info)
        do {
            let safeArguments = wrapAnyCodable(arguments)
            return try await connection.callTool(name: toolName, arguments: safeArguments)
        } catch {
            AppLogger.shared.logError(error, context: "Failed to call tool \(toolName)")
            return MCPToolResult(
                content: [MCPContent(type: "text", text: "Error calling tool '\(toolName)': \(error.localizedDescription)")],
                isError: true
            )
        }
    }
    
    /// Call built-in code execution tool
    private func callBuiltInCodeExecution(arguments: [String: Any]) async -> MCPToolResult {
        AppLogger.shared.log("Calling built-in code execution tool", level: .info)
        
        guard let languageString = arguments["language"] as? String,
              let codeLanguage = CodeLanguage(rawValue: languageString),
              let code = arguments["code"] as? String else {
            return MCPToolResult(
                content: [MCPContent(type: "text", text: "Error: 'language' and 'code' parameters are required for code execution")],
                isError: true
            )
        }
        
        // Get conversation ID from context (would need to be passed)
        // For now, use a default UUID
        let conversationId = UUID() // TODO: Get from context
        
        let timeout = (arguments["timeout"] as? Double) ?? 30.0
        let capabilities = (arguments["capabilities"] as? [String])?.compactMap { ExecutionCapability(rawValue: $0) } ?? []
        
        do {
            let result = try await ExecutionBroker.shared.requestExecution(
                conversationId: conversationId,
                language: codeLanguage,
                code: code,
                requestedCapabilities: capabilities,
                timeout: timeout
            )
            
            var output = "## Code Execution Result\n\n"
            output += "**Exit Code:** \(result.exitCode)\n"
            output += "**Duration:** \(String(format: "%.2f", result.duration))s\n"
            output += "**Memory:** \(formatBytes(result.resourceUsage.memoryBytes))\n\n"
            
            if !result.stdout.isEmpty {
                output += "### Output\n```\n\(result.stdout)\n```\n\n"
            }
            
            if !result.stderr.isEmpty {
                output += "### Errors\n```\n\(result.stderr)\n```\n\n"
            }
            
            if result.secretsDetected {
                output += "⚠️ **Note:** Secrets detected and redacted in output\n"
            }
            
            return MCPToolResult(
                content: [MCPContent(type: "text", text: output)],
                isError: result.exitCode != 0
            )
        } catch {
            AppLogger.shared.logError(error, context: "Code execution failed")
            return MCPToolResult(
                content: [MCPContent(type: "text", text: "Error executing code: \(error.localizedDescription)")],
                isError: true
            )
        }
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    /// Call built-in web search tool
    private func callBuiltInWebSearch(arguments: [String: Any]) async -> MCPToolResult {
        AppLogger.shared.log("Calling built-in web search tool", level: .info)
        
        guard let query = arguments["query"] as? String ?? arguments["q"] as? String else {
            return MCPToolResult(
                content: [MCPContent(type: "text", text: "Error: 'query' parameter is required for web_search")],
                isError: true
            )
        }
        
        let maxResults = (arguments["max_results"] as? Int) ?? (arguments["maxResults"] as? Int) ?? 5
        
        do {
            let results = try await WebSearchService.shared.search(query, maxResults: maxResults)
            
            if results.isEmpty {
                return MCPToolResult(
                    content: [MCPContent(type: "text", text: "No search results found for: \(query)")],
                    isError: false
                )
            }
            
            // Format results as markdown
            var resultText = "## Web Search Results for: \(query)\n\n"
            for (index, result) in results.enumerated() {
                resultText += "### \(index + 1). \(result.title)\n"
                resultText += "**URL:** \(result.url)\n"
                resultText += "**Snippet:** \(result.snippet)\n"
                resultText += "**Source:** \(result.source)\n\n"
            }
            
            return MCPToolResult(
                content: [MCPContent(type: "text", text: resultText)],
                isError: false
            )
        } catch {
            AppLogger.shared.logError(error, context: "Web search failed")
            return MCPToolResult(
                content: [MCPContent(type: "text", text: "Error performing web search: \(error.localizedDescription)")],
                isError: true
            )
        }
    }

    func ensureServersStarted() async {
        guard enabledServers.isEmpty else { return }
        for server in availableServers {
            do {
                try await startServer(server)
                AppLogger.shared.log("Started MCP server on demand: \(server.name)", level: .info)
            } catch {
                AppLogger.shared.logError(error, context: "Failed to start MCP server on demand \(server.name)")
            }
        }
    }
}

struct MCPServer: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let command: String
    let args: [String]
    let path: URL?

    enum CodingKeys: String, CodingKey {
        case id, name, description, command, args, path
    }
    
    init(id: String = UUID().uuidString, name: String, description: String, command: String, args: [String] = [], path: URL? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.command = command
        self.args = args
        self.path = path
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        command = try container.decode(String.self, forKey: .command)
        args = try container.decode([String].self, forKey: .args)
        path = try container.decodeIfPresent(URL.self, forKey: .path)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(command, forKey: .command)
        try container.encode(args, forKey: .args)
        try container.encodeIfPresent(path, forKey: .path)
    }
}

// MCP Tool definition
struct MCPTool: Codable, Identifiable, @unchecked Sendable {
    let name: String
    let description: String
    let inputSchema: AnyCodable
    var serverId: String?
    var serverName: String?

    var id: String { "\(serverId ?? ""):\(name)" }

    enum CodingKeys: String, CodingKey {
        case name, description, inputSchema
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        inputSchema = try container.decode(AnyCodable.self, forKey: .inputSchema)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(inputSchema, forKey: .inputSchema)
    }

    init(name: String, description: String, inputSchema: AnyCodable, serverId: String? = nil, serverName: String? = nil) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
        self.serverId = serverId
        self.serverName = serverName
    }
}

// Result from MCP tool execution
struct MCPToolResult {
    let content: [MCPContent]
    let isError: Bool

    init(content: [MCPContent], isError: Bool = false) {
        self.content = content
        self.isError = isError
    }
}

// MCP content can be text or other types
struct MCPContent: Codable, @unchecked Sendable {
    let type: String
    let text: String?

    init(type: String = "text", text: String) {
        self.type = type
        self.text = text
    }
}

struct ParsedToolCall: @unchecked Sendable {
    let id: String
    let name: String
    let arguments: [String: Any]
}

// Helper for encoding/decoding Any values
struct AnyCodable: Codable, @unchecked Sendable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        if let intValue = value as? Int {
            try container.encode(intValue)
        } else if let doubleValue = value as? Double {
            try container.encode(doubleValue)
        } else if let boolValue = value as? Bool {
            try container.encode(boolValue)
        } else if let stringValue = value as? String {
            try container.encode(stringValue)
        } else if let arrayValue = value as? [Any] {
            try container.encode(arrayValue.map { AnyCodable($0) })
        } else if let dictValue = value as? [String: Any] {
            try container.encode(dictValue.mapValues { AnyCodable($0) })
        } else {
            try container.encodeNil()
        }
    }
}

private func wrapAnyCodable(_ dict: [String: Any]) -> [String: AnyCodable] {
    dict.mapValues { AnyCodable($0) }
}

private func unwrapAnyCodable(_ dict: [String: AnyCodable]) -> [String: Any] {
    dict.mapValues { $0.value }
}

private actor StreamAccumulator {
    private var value = ""

    func append(_ chunk: String) {
        value += chunk
    }

    func current() -> String {
        value
    }
}

// MCP Server Connection - Handles JSON-RPC communication via stdio
@preconcurrency
class MCPServerConnection {
    private let process: Process
    private let stdinPipe = Pipe()
    private let stdoutPipe = Pipe()
    private var messageId = 0
    private var pendingRequests: [Int: CheckedContinuation<[String: AnyCodable], Error>] = [:]
    private let requestsLock = NSLock()
    private let onDisconnect: ((String) -> Void)?
    private let serverId: String

    init(command: String, arguments: [String], workingDirectory: URL?, onDisconnect: ((String) -> Void)? = nil, serverId: String = "") throws {
        self.onDisconnect = onDisconnect
        self.serverId = serverId
        Task { @MainActor in
            AppLogger.shared.log("Creating MCPServerConnection with command: \(command), args: \(arguments)", level: .debug)
        }
        process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments

        if let workingDirectory = workingDirectory {
            process.currentDirectoryURL = workingDirectory
            Task { @MainActor in
                AppLogger.shared.log("Set working directory: \(workingDirectory.path)", level: .debug)
            }
        }

        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        
        // Capture stderr for logging
        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        
        // Read stderr in background for error logging
        Task { [weak self] in
            await self?.readStderr(stderrPipe)
        }
        
        Task { @MainActor in
            AppLogger.shared.log("MCPServerConnection initialized", level: .debug)
        }
    }

    func start() throws {
        Task { @MainActor in
            AppLogger.shared.log("Starting MCP server process", level: .debug)
        }
        do {
            try process.run()
            let pid = process.processIdentifier
            Task { @MainActor in
                AppLogger.shared.log("MCP server process started (PID: \(pid))", level: .info)
            }
            
            // Start reading responses in background
            Task { [weak self] in
                await self?.readResponses()
            }
        } catch {
            Task { @MainActor in
                AppLogger.shared.logError(error, context: "Failed to start MCP server process")
            }
            throw error
        }
    }

    func stop() {
        let pid = process.processIdentifier
        Task { @MainActor in
            AppLogger.shared.log("Stopping MCP server process (PID: \(pid))", level: .info)
        }
        process.terminate()
    }
    
    private func readStderr(_ pipe: Pipe) async {
        let handle = pipe.fileHandleForReading
        while process.isRunning {
            guard let data = try? handle.read(upToCount: 1024), !data.isEmpty else {
                try? await Task.sleep(nanoseconds: 100_000_000)
                continue
            }
            if let stderrText = String(data: data, encoding: .utf8),
               !stderrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Task { @MainActor in
                    AppLogger.shared.log("MCP server stderr received", level: .warning)
                }
            }
        }
    }

    func initialize() async throws {
        await AppLogger.shared.log("Sending initialize request to MCP server", level: .debug)
        let params = wrapAnyCodable([
            "protocolVersion": "2024-11-05",
            "capabilities": [:],
            "clientInfo": [
                "name": "Vaizor",
                "version": "1.0.0"
            ]
        ])

        do {
            let response = try await sendRequest(method: "initialize", params: params)
            let responseDescription = String(describing: response)
            await AppLogger.shared.log("Received initialize response: \(responseDescription)", level: .debug)

            // Send initialized notification (no response expected)
            try sendNotification(method: "initialized", params: [:])
            await AppLogger.shared.log("Sent initialized notification", level: .debug)
        } catch {
            await AppLogger.shared.logError(error, context: "Failed to initialize MCP server")
            throw error
        }
    }

    func listTools() async throws -> [MCPTool] {
        await AppLogger.shared.log("Requesting tools list from MCP server", level: .debug)
        do {
            let response = try await sendRequest(method: "tools/list", params: [:])
            await AppLogger.shared.log("Received tools list response", level: .debug)

            guard let tools = response["tools"]?.value as? [[String: Any]] else {
                await AppLogger.shared.log("No tools found in response or invalid format", level: .warning)
                return []
            }

            await AppLogger.shared.log("Found \(tools.count) tools in response", level: .info)
            
            let decodedTools = tools.compactMap { toolDict -> MCPTool? in
                guard let name = toolDict["name"] as? String,
                      let description = toolDict["description"] as? String else {
                    let toolDescription = String(describing: toolDict)
                    Task { @MainActor in
                        AppLogger.shared.log("Tool missing name or description: \(toolDescription)", level: .warning)
                    }
                    return nil
                }

                let inputSchema = toolDict["inputSchema"] ?? [:]
                let toolData: [String: Any] = [
                    "name": name,
                    "description": description,
                    "inputSchema": inputSchema
                ]

                guard let jsonData = try? JSONSerialization.data(withJSONObject: toolData),
                      let tool = try? JSONDecoder().decode(MCPTool.self, from: jsonData) else {
                    Task { @MainActor in
                        AppLogger.shared.log("Failed to decode tool: \(name)", level: .warning)
                    }
                    return nil
                }

                Task { @MainActor in
                    AppLogger.shared.log("Decoded tool: \(name)", level: .debug)
                }
                return tool
            }
            
            await AppLogger.shared.log("Successfully decoded \(decodedTools.count) tools", level: .info)
            return decodedTools
        } catch {
            await AppLogger.shared.logError(error, context: "Failed to list tools from MCP server")
            throw error
        }
    }

    func callTool(name: String, arguments: [String: AnyCodable]) async throws -> MCPToolResult {
        await AppLogger.shared.log("Calling MCP tool: \(name) (arg keys: \(arguments.count))", level: .info)
        let params: [String: Any] = [
            "name": name,
            "arguments": unwrapAnyCodable(arguments)
        ]

        do {
            let response = try await sendRequest(method: "tools/call", params: wrapAnyCodable(params), timeout: 60)
            await AppLogger.shared.log("Received tool call response for \(name)", level: .debug)

            guard let content = response["content"]?.value as? [[String: Any]] else {
                let error = NSError(domain: "MCPServer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid tool response format"])
                await AppLogger.shared.logError(error, context: "Tool \(name) returned invalid response format")
                throw error
            }

            let mcpContent = content.compactMap { dict -> MCPContent? in
                guard let type = dict["type"] as? String else {
                    let dictDescription = String(describing: dict)
                    Task { @MainActor in
                        AppLogger.shared.log("Content item missing type: \(dictDescription)", level: .warning)
                    }
                    return nil
                }
                let text = dict["text"] as? String
                return MCPContent(type: type, text: text ?? "")
            }

            let isError = response["isError"]?.value as? Bool ?? false
            await AppLogger.shared.log("Tool \(name) execution completed (error: \(isError), content items: \(mcpContent.count))", level: .info)
            return MCPToolResult(content: mcpContent, isError: isError)
        } catch {
            await AppLogger.shared.logError(error, context: "Failed to call MCP tool \(name)")
            // Return error result instead of throwing, so LLM can handle it
            let errorMessage = error.localizedDescription
            await AppLogger.shared.log("Returning error result for tool \(name)", level: .warning)
            return MCPToolResult(
                content: [MCPContent(type: "text", text: "Error executing tool '\(name)': \(errorMessage)")],
                isError: true
            )
        }
    }
    
    private func sendRequest(method: String, params: [String: AnyCodable], timeout: TimeInterval = 15) async throws -> [String: AnyCodable] {
        return try await withCheckedThrowingContinuation { continuation in
            let id = requestsLock.withLock {
                messageId += 1
                let id = messageId
                pendingRequests[id] = continuation
                return id
            }

            let request: [String: Any] = [
                "jsonrpc": "2.0",
                "id": id,
                "method": method,
                "params": unwrapAnyCodable(params)
            ]

            Task { @MainActor in
                AppLogger.shared.log("Sending JSON-RPC request: method=\(method), id=\(id)", level: .debug)
            }
            
            if timeout > 0 {
                Task { [weak self] in
                    try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    guard let self else { return }
                    let pending = self.requestsLock.withLock {
                        self.pendingRequests.removeValue(forKey: id)
                    }
                    if let pending {
                        let error = NSError(domain: "MCPServer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Request timed out"])
                        pending.resume(throwing: error)
                    }
                }
            }
            
            do {
                let data = try JSONSerialization.data(withJSONObject: request)
                guard let jsonString = String(data: data, encoding: .utf8) else {
                    let error = NSError(domain: "MCPServer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode request as UTF-8"])
                    Task { @MainActor in
                        AppLogger.shared.logError(error, context: "Failed to encode JSON-RPC request")
                    }
                    _ = requestsLock.withLock {
                        pendingRequests.removeValue(forKey: id)
                    }
                    continuation.resume(throwing: error)
                    return
                }
                
                var requestString = jsonString
                requestString += "\n"
                
                guard let requestData = requestString.data(using: .utf8) else {
                    let error = NSError(domain: "MCPServer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode request string"])
                    Task { @MainActor in
                        AppLogger.shared.logError(error, context: "Failed to encode request string")
                    }
                    _ = requestsLock.withLock {
                        pendingRequests.removeValue(forKey: id)
                    }
                    continuation.resume(throwing: error)
                    return
                }
                
                do {
                    try stdinPipe.fileHandleForWriting.write(contentsOf: requestData)
                    Task { @MainActor in
                        AppLogger.shared.log("Request written successfully", level: .debug)
                    }
                } catch {
                    Task { @MainActor in
                        AppLogger.shared.logError(error, context: "Failed to write request to stdin")
                    }
                    _ = requestsLock.withLock {
                        pendingRequests.removeValue(forKey: id)
                    }
                    continuation.resume(throwing: error)
                }
            } catch {
                Task { @MainActor in
                    AppLogger.shared.logError(error, context: "Failed to serialize JSON-RPC request")
                }
                _ = requestsLock.withLock {
                    pendingRequests.removeValue(forKey: id)
                }
                continuation.resume(throwing: error)
            }
        }
    }

    private func sendNotification(method: String, params: [String: AnyCodable]) throws {
        let notification: [String: Any] = [
            "jsonrpc": "2.0",
            "method": method,
            "params": unwrapAnyCodable(params)
        ]

        let data = try JSONSerialization.data(withJSONObject: notification)
        guard var jsonString = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "MCPServer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode JSON string to UTF-8"])
        }
        jsonString += "\n"

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw NSError(domain: "MCPServer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode JSON data"])
        }
        stdinPipe.fileHandleForWriting.write(jsonData)
    }

    private nonisolated func readResponses() async {
        Task { @MainActor in
            AppLogger.shared.log("Starting to read MCP server responses", level: .debug)
        }
        let handle = stdoutPipe.fileHandleForReading

        while process.isRunning {
            guard let line = try? handle.readLine() else {
                // Check if process is still running before sleeping
                guard process.isRunning else { break }
                try? await Task.sleep(nanoseconds: 100_000_000)
                continue
            }

            guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }

            guard let data = line.data(using: .utf8) else {
                Task { @MainActor in
                    AppLogger.shared.log("Failed to convert line to UTF-8 data", level: .warning)
                }
                continue
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                Task { @MainActor in
                    AppLogger.shared.log("Failed to parse JSON from server response", level: .warning)
                }
                continue
            }

            guard let id = json["id"] as? Int else {
                Task { @MainActor in
                    AppLogger.shared.log("Response missing ID, likely a notification", level: .debug)
                }
                continue
            }

            Task { @MainActor in
                AppLogger.shared.log("Processing response with ID: \(id)", level: .debug)
            }

            let continuation: CheckedContinuation<[String: AnyCodable], Error>? = requestsLock.withLock {
                pendingRequests.removeValue(forKey: id)
            }

            guard let continuation = continuation else {
                Task { @MainActor in
                    AppLogger.shared.log("No pending request found for ID: \(id)", level: .warning)
                }
                continue
            }

            if let error = json["error"] as? [String: Any] {
                let message = error["message"] as? String ?? "Unknown error"
                let code = error["code"] as? Int ?? -1
                Task { @MainActor in
                    AppLogger.shared.log("MCP server returned error for request \(id): \(message) (code: \(code))", level: .error)
                }
                let nsError = NSError(domain: "MCPServer", code: code, userInfo: [NSLocalizedDescriptionKey: message])
                continuation.resume(throwing: nsError)
            } else if let result = json["result"] as? [String: Any] {
                Task { @MainActor in
                    AppLogger.shared.log("MCP server returned success for request \(id)", level: .debug)
                }
                continuation.resume(returning: wrapAnyCodable(result))
            } else {
                Task { @MainActor in
                    AppLogger.shared.log("MCP server returned empty result for request \(id)", level: .debug)
                }
                continuation.resume(returning: [:])
            }
        }
        
        Task { @MainActor in
            AppLogger.shared.log("MCP server response reader stopped (process no longer running)", level: .info)
        }
        
        let pending = requestsLock.withLock {
            let pending = pendingRequests
            pendingRequests.removeAll()
            return pending
        }
        if !pending.isEmpty {
            let error = NSError(domain: "MCPServer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Server disconnected"])
            for (_, continuation) in pending {
                continuation.resume(throwing: error)
            }
        }
        
        // Notify about disconnection if callback provided
        if !serverId.isEmpty {
            onDisconnect?(serverId)
        }
    }
}

extension FileHandle {
    func readLine() throws -> String? {
        var data = Data()

        while true {
            guard let bytesRead = try? read(upToCount: 1), !bytesRead.isEmpty else {
                break
            }

            if bytesRead[0] == UInt8(ascii: "\n") {
                break
            }
            data.append(bytesRead[0])
        }

        return data.isEmpty ? nil : String(data: data, encoding: .utf8)
    }
}

// Enhanced Ollama Provider with MCP support
class OllamaProviderWithMCP: OllamaProvider, @unchecked Sendable {
    weak var mcpManager: MCPServerManager?
    
    /// Generate dynamic system prompt that lists all available tools grouped by server
    /// Cached to avoid regenerating when tools haven't changed
    @MainActor private static var cachedSystemPrompt: (toolsHash: Int, prompt: String)?

    override func streamMessage(
        _ text: String,
        configuration: LLMConfiguration,
        conversationHistory: [Message],
        onChunk: @escaping @Sendable (String) -> Void,
        onThinkingStatusUpdate: @escaping @Sendable (String) -> Void
    ) async throws {
        // Check if MCP tools are available and get them on main actor
        var availableTools = await MainActor.run {
            mcpManager?.availableTools ?? []
        }

        let shouldUseToolsPrompt = shouldUseTools(for: text)

        guard shouldUseToolsPrompt else {
            // No MCP tools, use standard Ollama
            try await super.streamMessage(text, configuration: configuration, conversationHistory: conversationHistory, onChunk: onChunk, onThinkingStatusUpdate: onThinkingStatusUpdate)
            return
        }
        
        if availableTools.isEmpty {
            if let manager = await MainActor.run(resultType: MCPServerManager?.self, body: { mcpManager }) {
                await manager.ensureServersStarted()
            }
            availableTools = await MainActor.run {
                mcpManager?.availableTools ?? []
            }
        }
        
        // Add built-in web search tool
        var tools = availableTools.map { tool -> [String: Any] in
            var schema = tool.inputSchema.value as? [String: Any] ?? [:]
            schema["type"] = "object"

            return [
                "type": "function",
                "function": [
                    "name": tool.name,
                    "description": tool.description,
                    "parameters": schema
                ]
            ]
        }
        
        // Add built-in web search tool
        tools.append([
            "type": "function",
            "function": [
                "name": "web_search",
                "description": "Search the web for current information. Use this when you need up-to-date information, facts, or recent events.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "query": [
                            "type": "string",
                            "description": "The search query"
                        ],
                        "max_results": [
                            "type": "integer",
                            "description": "Maximum number of results (default: 5)",
                            "default": 5
                        ]
                    ],
                    "required": ["query"]
                ]
            ]
        ])
        
        // Add built-in code execution tool
        tools.append([
            "type": "function",
            "function": [
                "name": "execute_code",
                "description": "Execute code in a sandboxed environment. Use this when you need to run Python, JavaScript, or Swift code to perform calculations, process data, or test code snippets.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "language": [
                            "type": "string",
                            "enum": ["python", "javascript", "swift"],
                            "description": "Programming language"
                        ],
                        "code": [
                            "type": "string",
                            "description": "The code to execute"
                        ],
                        "timeout": [
                            "type": "number",
                            "description": "Timeout in seconds (default: 30)",
                            "default": 30
                        ],
                        "capabilities": [
                            "type": "array",
                            "items": [
                                "type": "string",
                                "enum": ["filesystem.read", "filesystem.write", "network", "clipboard.read", "clipboard.write", "process.spawn"]
                            ],
                            "description": "Required capabilities (will prompt user for permission)"
                        ]
                    ],
                    "required": ["language", "code"]
                ]
            ]
        ])

        guard !tools.isEmpty else {
            try await super.streamMessage(text, configuration: configuration, conversationHistory: conversationHistory, onChunk: onChunk, onThinkingStatusUpdate: onThinkingStatusUpdate)
            return
        }

        // Call Ollama with tools and handle tool calls
        try await streamMessageWithTools(
            text,
            configuration: configuration,
            conversationHistory: conversationHistory,
            tools: tools,
            onChunk: onChunk,
            onThinkingStatusUpdate: onThinkingStatusUpdate
        )
    }

    private func shouldUseTools(for prompt: String) -> Bool {
        let lower = prompt.lowercased()

        if lower.hasPrefix("/mcp") || lower.hasPrefix("/tool") || lower.hasPrefix("/tools") {
            return true
        }

        if lower.contains("http://") || lower.contains("https://") {
            return true
        }

        let actionKeywords = [
            "search", "lookup", "look up", "find", "fetch", "download",
            "open", "read", "write", "save", "create", "delete", "remove",
            "list", "enumerate", "scan", "run", "execute", "query", "call",
            "invoke", "upload", "update", "edit", "modify"
        ]

        let targetKeywords = [
            "file", "files", "folder", "directory", "path",
            "url", "website", "web", "internet", "online",
            "api", "endpoint",
            "database", "db", "sql", "table",
            "repo", "repository", "github",
            "filesystem", "shell", "command", "terminal",
            "log", "logs", "system"
        ]

        // If query contains "search" + web-related terms, enable tools (for web search)
        if lower.contains("search") && (lower.contains("web") || lower.contains("internet") || lower.contains("online") || lower.contains("current") || lower.contains("recent") || lower.contains("latest")) {
            return true
        }

        let hasAction = actionKeywords.contains { lower.contains($0) }
        let hasTarget = targetKeywords.contains { lower.contains($0) }
        return hasAction && hasTarget
    }
    
    private func generateSystemPrompt(tools: [[String: Any]], mcpManager: MCPServerManager?) async -> String {
        // Get tools on MainActor since mcpManager is @MainActor
        let availableTools = await MainActor.run {
            mcpManager?.availableTools ?? []
        }
        
        // Create built-in tools for system prompt (don't modify actual availableTools array)
        let webSearchTool = MCPTool(
            name: "web_search",
            description: "Search the web for current information. Use this when you need up-to-date information, facts, or recent events.",
            inputSchema: AnyCodable([
                "type": "object",
                "properties": [
                    "query": [
                        "type": "string",
                        "description": "The search query"
                    ],
                    "max_results": [
                        "type": "integer",
                        "description": "Maximum number of results (default: 5)",
                        "default": 5
                    ]
                ],
                "required": ["query"]
            ]),
            serverId: "builtin",
            serverName: "Vaizor Built-in"
        )
        
        let executeCodeTool = MCPTool(
            name: "execute_code",
            description: "Execute code in a sandboxed environment. Use this when you need to run Python, JavaScript, or Swift code.",
            inputSchema: AnyCodable([
                "type": "object",
                "properties": [
                    "language": [
                        "type": "string",
                        "enum": ["python", "javascript", "swift"],
                        "description": "Programming language"
                    ],
                    "code": [
                        "type": "string",
                        "description": "The code to execute"
                    ]
                ],
                "required": ["language", "code"]
            ]),
            serverId: "builtin",
            serverName: "Vaizor Built-in"
        )
        
        // Combine MCP tools with built-in tools for prompt generation only
        var allToolsForPrompt = availableTools
        allToolsForPrompt.append(webSearchTool)
        allToolsForPrompt.append(executeCodeTool)
        
        guard !allToolsForPrompt.isEmpty else {
            return """
            You are a helpful AI assistant with access to web search and code execution. Use web_search tool when you need current information, and execute_code when you need to run code.
            """
        }
        
        // Check cache - use hash of tool IDs and names to detect changes
        let toolsHash = allToolsForPrompt.map { "\($0.id)-\($0.name)" }.joined().hashValue
        let cached = await MainActor.run { Self.cachedSystemPrompt }
        if let cached, cached.toolsHash == toolsHash {
            return cached.prompt
        }
        
        var prompt = """
        You are a helpful AI assistant with access to various tools and capabilities from different sources.
        
        You have access to the following tools:
        """
        
        // Group tools by server
        let toolsByServer = Dictionary(grouping: allToolsForPrompt) { $0.serverName ?? "Unknown" }
        
        for (serverName, serverTools) in toolsByServer.sorted(by: { $0.key < $1.key }) {
            prompt += "\n\n**\(serverName) Tools:**\n"
            for tool in serverTools.sorted(by: { $0.name < $1.name }) {
                let formattedName = formatToolName(tool.name)
                prompt += "- \(formattedName): \(tool.description)\n"
            }
        }
        
        prompt += """
        
        
        **Important Guidelines:**
        - You can use tools from any of the available sources above
        - Different tools may come from different MCP servers
        - Use the most appropriate tool for each task
        - You can chain multiple tool calls together sequentially to complete complex tasks
        - If a tool fails, try alternative approaches or explain the limitation to the user
        - When describing your capabilities, mention that you can help with various tasks using the available tools, not just one specific domain
        
        When a user asks "what can you do" or similar questions, provide a comprehensive overview of your capabilities across all available tool sets, not just one domain.
        """
        
        // Cache the result
        let promptValue = prompt
        await MainActor.run {
            Self.cachedSystemPrompt = (toolsHash: toolsHash, prompt: promptValue)
        }
        
        return prompt
    }

    private func streamMessageWithTools(
        _ text: String,
        configuration: LLMConfiguration,
        conversationHistory: [Message],
        tools: [[String: Any]],
        onChunk: @escaping @Sendable (String) -> Void,
        onThinkingStatusUpdate: @escaping @Sendable (String) -> Void
    ) async throws {
        let url = URL(string: "http://localhost:11434/api/chat")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var messages: [[String: Any]] = []

        // Generate and use dynamic system prompt if tools are available
        let systemPrompt: String
        if let existingPrompt = configuration.systemPrompt {
            systemPrompt = existingPrompt
        } else {
            systemPrompt = await generateSystemPrompt(tools: tools, mcpManager: mcpManager)
        }
        messages.append(["role": "system", "content": systemPrompt])

        for message in conversationHistory {
            messages.append([
                "role": message.role == .user ? "user" : "assistant",
                "content": message.content
            ])
        }

        messages.append(["role": "user", "content": text])

        let body: [String: Any] = [
            "model": configuration.model,
            "messages": messages,
            "stream": true,
            "tools": tools,
            "options": [
                "temperature": configuration.temperature,
                "num_predict": configuration.maxTokens
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // Use concurrent URLSession configuration for better performance
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.httpMaximumConnectionsPerHost = 10
        sessionConfig.timeoutIntervalForRequest = 300
        sessionConfig.timeoutIntervalForResource = 600
        let session = URLSession(configuration: sessionConfig)
        
        let (asyncBytes, response) = try await session.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "OllamaProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to connect to Ollama"])
        }

        var toolCalls: [[String: Any]] = []
        var accumulatedContent = ""

        for try await line in asyncBytes.lines {
            guard !line.isEmpty else { continue }

            if let data = line.data(using: String.Encoding.utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

                // Check for tool calls
                if let message = json["message"] as? [String: Any],
                   let calls = message["tool_calls"] as? [[String: Any]] {
                    toolCalls.append(contentsOf: calls)
                }

                // Stream regular content
                if let messageContent = json["message"] as? [String: Any],
                   let content = messageContent["content"] as? String, !content.isEmpty {
                    accumulatedContent += content
                    onChunk(content)
                }
            }
        }

        // Execute tool calls if any and send results back to LLM
        if !toolCalls.isEmpty {
        await AppLogger.shared.log("Tool calls detected, executing and continuing conversation", level: .info)
            try await executeToolCallsAndContinue(
                toolCalls: toolCalls,
                accumulatedContent: accumulatedContent,
                originalUserPrompt: text,
                configuration: configuration,
                conversationHistory: conversationHistory,
                tools: tools,
                onChunk: onChunk,
                onThinkingStatusUpdate: onThinkingStatusUpdate
            )
        }
    }

    /// Format tool name for display: converts snake_case to Title Case
    private func formatToolName(_ name: String) -> String {
        return name
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
    }
    
    /// Generate intelligible status message via LLM call
    private func generateStatusMessage(
        toolName: String,
        arguments: [String: Any],
        configuration: LLMConfiguration,
        onThinkingStatusUpdate: @escaping @Sendable (String) -> Void
    ) async -> String {
        let formattedName = formatToolName(toolName)
        
        // Format arguments for prompt
        let argsString = arguments.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
        
        let prompt = """
        Given this tool call:
        Tool: \(formattedName)
        Arguments: \(argsString.isEmpty ? "none" : argsString)
        
        Generate a single, clear, natural sentence (max 10 words) describing what this action is doing from the user's perspective.
        Examples:
        - "Looking up user information in the database"
        - "Searching the web for current weather data"
        - "Reading configuration file to understand system settings"
        
        Only return the sentence, nothing else.
        """
        
        // Quick LLM call with timeout
        do {
            let statusConfig = LLMConfiguration(
                provider: configuration.provider,
                model: configuration.model,
                temperature: 0.3, // Lower temperature for more consistent status messages
                maxTokens: 20,
                systemPrompt: nil,
                enableChainOfThought: false,
                enablePromptEnhancement: false
            )
            
            let statusAccumulator = StreamAccumulator()
            
            // Use withTimeout pattern - race between LLM call and timeout
            do {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    group.addTask {
                        try await super.streamMessage(
                            prompt,
                            configuration: statusConfig,
                            conversationHistory: [],
                            onChunk: { chunk in
                                Task {
                                    await statusAccumulator.append(chunk)
                                }
                            },
                            onThinkingStatusUpdate: { _ in }
                        )
                    }
                    
                    group.addTask {
                        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 second timeout
                        throw NSError(domain: "StatusGeneration", code: -1, userInfo: [NSLocalizedDescriptionKey: "Timeout"])
                    }
                    
                    _ = try await group.next()
                    group.cancelAll()
                }
                
                let trimmed = await statusAccumulator.current().trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty && trimmed.count < 100 {
                    return trimmed
                }
            } catch {
                // Fall through to fallback - timeout or LLM error
            }
        }
        
        // Fallback: use formatted tool name
        return "Using \(formattedName)..."
    }

    private func executeToolCallsAndContinue(
        toolCalls: [[String: Any]],
        accumulatedContent: String,
        originalUserPrompt: String,
        configuration: LLMConfiguration,
        conversationHistory: [Message],
        tools: [[String: Any]],
        onChunk: @escaping @Sendable (String) -> Void,
        onThinkingStatusUpdate: @escaping @Sendable (String) -> Void,
        iteration: Int = 0,
        maxIterations: Int = 10,
        consecutiveErrors: Int = 0,
        maxConsecutiveErrors: Int = 3
    ) async throws {
        // Check stopping conditions
        guard iteration < maxIterations else {
            await AppLogger.shared.log("Maximum tool call iterations (\(maxIterations)) reached, stopping", level: .warning)
            onThinkingStatusUpdate("Stopped: Maximum iterations reached")
            onChunk("\n\n[Unable to complete task: Maximum tool call iterations reached. Please try a simpler request.]")
            return
        }
        
        guard consecutiveErrors < maxConsecutiveErrors else {
            await AppLogger.shared.log("Too many consecutive errors (\(consecutiveErrors)), stopping", level: .warning)
            onThinkingStatusUpdate("Stopped: Too many errors")
            onChunk("\n\n[Unable to complete task: Multiple tool call errors occurred. Please check your request and try again.]")
            return
        }
        await AppLogger.shared.log("Executing \(toolCalls.count) tool calls (iteration \(iteration + 1)) and continuing conversation", level: .info)
        guard let mcpManager = mcpManager else {
            await AppLogger.shared.log("MCP manager not available", level: .error)
            return
        }

        // Execute all tool calls in parallel where possible, but respect dependencies
        var toolResults: [[String: Any]] = []
        var currentConsecutiveErrors = consecutiveErrors
        
        // Parse all tool calls first
        let parsedCalls: [ParsedToolCall] = toolCalls.compactMap { toolCall in
            guard let function = toolCall["function"] as? [String: Any],
                  let name = function["name"] as? String,
                  let callId = toolCall["id"] as? String else {
                return nil
            }
            return ParsedToolCall(
                id: callId,
                name: name,
                arguments: function["arguments"] as? [String: Any] ?? [:]
            )
        }
        
        // Generate status messages for all tools sequentially (parallelization can be added later)
        // For now, generate them one at a time to avoid complexity
        var statusMessages: [String] = []
        for parsedCall in parsedCalls {
            let message = await generateStatusMessage(
                toolName: parsedCall.name,
                arguments: parsedCall.arguments,
                configuration: configuration,
                onThinkingStatusUpdate: { _ in }
            )
            statusMessages.append(message)
        }
        
        // Update status for first tool
        if let firstStatus = statusMessages.first {
            await MainActor.run {
                onThinkingStatusUpdate(firstStatus)
            }
        }
        
        // Execute tool calls in parallel when possible (tools from different servers can run concurrently)
        // For now, execute all tools in parallel since they're typically independent
        let executionResults = await withTaskGroup(of: (index: Int, result: MCPToolResult, callId: String, name: String).self) { group in
            for (index, parsedCall) in parsedCalls.enumerated() {
                group.addTask {
                    await AppLogger.shared.log("Executing tool call: \(parsedCall.name) with ID: \(parsedCall.id)", level: .info)
                    let result = await mcpManager.callTool(toolName: parsedCall.name, arguments: parsedCall.arguments)
                    return (index, result, parsedCall.id, parsedCall.name)
                }
            }
            
            var results: [(index: Int, result: MCPToolResult, callId: String, name: String)] = []
            for await result in group {
                results.append(result)
            }
            return results.sorted { $0.index < $1.index }
        }
        
        // Process results and update status (batch MainActor calls)
        var finalToolResults: [[String: Any]] = []
        
        for (index, execResult, callId, name) in executionResults {
            let resultText = execResult.content.compactMap { $0.text }.joined(separator: "\n")
            
            if execResult.isError {
                currentConsecutiveErrors += 1
                await AppLogger.shared.log("Tool \(name) returned error (length: \(resultText.count))", level: .warning)
            } else {
                if index == 0 {
                    currentConsecutiveErrors = 0 // Reset on first success
                }
                await AppLogger.shared.log("Tool \(name) executed successfully, result length: \(resultText.count)", level: .info)
            }
            
            finalToolResults.append([
                "tool_call_id": callId,
                "name": name,
                "content": resultText
            ])
        }
        
        toolResults = finalToolResults
        
        // Batch all UI updates in a single MainActor call
        let toolNames = toolResults.compactMap { $0["name"] as? String }.map { formatToolName($0) }
        let finalStatusMessage: String
        if toolNames.count == 1 {
            finalStatusMessage = "Processing \(toolNames[0]) results..."
        } else if toolNames.count > 1 {
            finalStatusMessage = "Processing results from \(toolNames.joined(separator: ", "))..."
        } else {
            finalStatusMessage = "Processing tool results..."
        }
        
        await MainActor.run {
            onThinkingStatusUpdate(finalStatusMessage)
        }

        // Send tool results back to Ollama WITH the original user prompt so it can use them in its response
        await AppLogger.shared.log("Sending tool results back to Ollama with original prompt for continuation", level: .info)
        // Create a new request with the tool results as a tool message
        let url = URL(string: "http://localhost:11434/api/chat")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        await AppLogger.shared.log("Created continuation request to Ollama", level: .debug)

        var messages: [[String: Any]] = []

        if let systemPrompt = configuration.systemPrompt {
            messages.append(["role": "system", "content": systemPrompt])
        }

        // Include conversation history (excluding the last user message since we'll add it explicitly)
        // Properly handle all message types including tool messages from previous iterations
        for message in conversationHistory.dropLast() {
            var messageDict: [String: Any] = [
                "content": message.content
            ]
            
            switch message.role {
            case .user:
                messageDict["role"] = "user"
            case .assistant:
                messageDict["role"] = "assistant"
            case .tool:
                messageDict["role"] = "tool"
                // Preserve tool_call_id and name if available
                if let toolCallId = message.toolCallId {
                    messageDict["tool_call_id"] = toolCallId
                }
                if let toolName = message.toolName {
                    messageDict["name"] = toolName
                }
            case .system:
                messageDict["role"] = "system"
            }
            
            messages.append(messageDict)
        }

        // Add the original user prompt explicitly
        messages.append([
            "role": "user",
            "content": originalUserPrompt
        ])

        // Add the assistant message with tool calls
        messages.append([
            "role": "assistant",
            "content": accumulatedContent,
            "tool_calls": toolCalls
        ])

        // Add tool results as tool messages (Ollama expects these in a specific format)
        for result in toolResults {
            if let toolCallId = result["tool_call_id"] as? String {
                messages.append([
                    "role": "tool",
                    "content": result["content"] as? String ?? "",
                    "name": result["name"] as? String ?? "",
                    "tool_call_id": toolCallId
                ])
            }
        }
        
        await AppLogger.shared.log("Message sequence: \(messages.count) messages (user prompt + assistant with tools + \(toolResults.count) tool results)", level: .debug)

        let body: [String: Any] = [
            "model": configuration.model,
            "messages": messages,
            "stream": true,
            "tools": tools, // Keep tools available for additional calls
            "options": [
                "temperature": configuration.temperature,
                "num_predict": configuration.maxTokens
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // Use concurrent URLSession configuration
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.httpMaximumConnectionsPerHost = 10
        sessionConfig.timeoutIntervalForRequest = 300
        sessionConfig.timeoutIntervalForResource = 600
        let session = URLSession(configuration: sessionConfig)
        
        // Add timeout to prevent hanging
        do {
            let requestToSend = request
            let (asyncBytes, response) = try await withThrowingTaskGroup(of: (URLSession.AsyncBytes, URLResponse).self) { group in
                group.addTask {
                    try await session.bytes(for: requestToSend)
                }
                
                group.addTask {
                    try await Task.sleep(nanoseconds: 60_000_000_000) // 60 seconds
                    throw NSError(domain: "OllamaProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Request timed out after 60 seconds"])
                }
                
                guard let result = try await group.next() else {
                    throw NSError(domain: "OllamaProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Request failed"])
                }
                
                group.cancelAll()
                return result
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                let errorMsg = "Failed to continue conversation with Ollama (status: \((response as? HTTPURLResponse)?.statusCode ?? -1))"
                await AppLogger.shared.log(errorMsg, level: .error)
                onChunk("\n\n[Error: \(errorMsg)]")
                return
            }

            // Stream the LLM's response and check for additional tool calls
            var newToolCalls: [[String: Any]] = []
            var newAccumulatedContent = ""
            
            for try await line in asyncBytes.lines {
                let lineString = String(line)
                guard !lineString.isEmpty else { continue }

                if let data = lineString.data(using: String.Encoding.utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    
                    // Check for additional tool calls
                    if let messageContent = json["message"] as? [String: Any],
                       let calls = messageContent["tool_calls"] as? [[String: Any]] {
                        newToolCalls.append(contentsOf: calls)
                    }
                    
                    // Stream regular content
                    if let messageContent = json["message"] as? [String: Any],
                       let content = messageContent["content"] as? String, !content.isEmpty {
                        newAccumulatedContent += content
                        onChunk(content)
                    }
                }
            }
            
            // If LLM wants to make more tool calls, execute them recursively
            if !newToolCalls.isEmpty {
                await AppLogger.shared.log("LLM requested \(newToolCalls.count) additional tool call(s) in iteration \(iteration + 1)", level: .info)
                
                // Build updated conversation history with tool results
                let conversationId = conversationHistory.first?.conversationId ?? UUID()
                var updatedHistory = conversationHistory
                
                // Add assistant message with accumulated content
                updatedHistory.append(Message(
                    conversationId: conversationId,
                    role: .assistant,
                    content: accumulatedContent
                ))
                
                // Add tool result messages to history with metadata preserved
                for result in toolResults {
                    if let content = result["content"] as? String {
                        let toolCallId = result["tool_call_id"] as? String
                        let toolName = result["name"] as? String
                        updatedHistory.append(Message(
                            conversationId: conversationId,
                            role: .tool,
                            content: content,
                            toolCallId: toolCallId,
                            toolName: toolName
                        ))
                    }
                }
                
                // Recursively execute the new tool calls
                try await executeToolCallsAndContinue(
                    toolCalls: newToolCalls,
                    accumulatedContent: newAccumulatedContent,
                    originalUserPrompt: originalUserPrompt,
                    configuration: configuration,
                    conversationHistory: updatedHistory,
                    tools: tools,
                    onChunk: onChunk,
                    onThinkingStatusUpdate: onThinkingStatusUpdate,
                    iteration: iteration + 1,
                    maxIterations: maxIterations,
                    consecutiveErrors: currentConsecutiveErrors,
                    maxConsecutiveErrors: maxConsecutiveErrors
                )
            } else {
                await AppLogger.shared.log("No additional tool calls requested, conversation complete after \(iteration + 1) iteration(s)", level: .info)
                await MainActor.run {
                    onThinkingStatusUpdate("Formulating final response...")
                }
            }
        } catch {
            await AppLogger.shared.logError(error, context: "Failed to continue conversation after tool execution")
            onChunk("\n\n[Error: Failed to get response from LLM after tool execution. \(error.localizedDescription)]")
        }
    }
}
