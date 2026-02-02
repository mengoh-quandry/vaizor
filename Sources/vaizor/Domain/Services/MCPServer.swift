import Foundation
import AppKit

// MCP (Model Context Protocol) Server Manager
@MainActor
class MCPServerManager: ObservableObject {
    @Published var availableServers: [MCPServer] = []
    @Published var enabledServers: Set<String> = []

    private struct RunningServer {
        let process: Process
        let stdin: Pipe
        let stdout: Pipe
        let stderr: Pipe
    }

    private enum MCPError: LocalizedError {
        case serverNotRunning
        case noResponse
        case serverError(String)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .serverNotRunning:
                return "MCP server is not running"
            case .noResponse:
                return "No response from MCP server"
            case .serverError(let message):
                return "MCP server error: \(message)"
            case .invalidResponse:
                return "Invalid response from MCP server"
            }
        }
    }

    private var serverProcesses: [String: RunningServer] = [:]
    private var nextRequestId = 1
    private let configURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let vaizorDir = appSupport.appendingPathComponent("Vaizor")
        try? FileManager.default.createDirectory(at: vaizorDir, withIntermediateDirectories: true)
        configURL = vaizorDir.appendingPathComponent("mcp-servers.json")

        loadServers()
    }

    func discoverServers() {
        // Reload from saved config
        loadServers()
    }

    private func loadServers() {
        guard FileManager.default.fileExists(atPath: configURL.path),
              let data = try? Data(contentsOf: configURL),
              let servers = try? JSONDecoder().decode([MCPServer].self, from: data) else {
            availableServers = []
            return
        }

        availableServers = servers
    }

    private func saveServers() {
        guard let data = try? JSONEncoder().encode(availableServers) else { return }
        try? data.write(to: configURL)
    }

    func addServer(_ server: MCPServer) {
        availableServers.append(server)
        saveServers()
    }

    func removeServer(_ server: MCPServer) {
        stopServer(server)
        availableServers.removeAll { $0.id == server.id }
        saveServers()
    }

    func updateServer(_ server: MCPServer) {
        if let index = availableServers.firstIndex(where: { $0.id == server.id }) {
            let wasRunning = enabledServers.contains(server.id)
            if wasRunning {
                stopServer(availableServers[index])
            }

            availableServers[index] = server
            saveServers()

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
        guard !serverProcesses.keys.contains(server.id) else {
            return // Already running
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: server.command)
        process.arguments = server.args
        process.currentDirectoryURL = server.path

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        serverProcesses[server.id] = RunningServer(
            process: process,
            stdin: stdinPipe,
            stdout: stdoutPipe,
            stderr: stderrPipe
        )
        enabledServers.insert(server.id)

        print("Started MCP server: \(server.name)")
    }

    func stopServer(_ server: MCPServer) {
        if let running = serverProcesses[server.id] {
            running.process.terminate()
            serverProcesses.removeValue(forKey: server.id)
            enabledServers.remove(server.id)
            print("Stopped MCP server: \(server.name)")
        }
    }

    func callTool(server: MCPServer, toolName: String, arguments: [String: Any]) async throws -> [String: Any] {
        guard let running = serverProcesses[server.id] else {
            throw MCPError.serverNotRunning
        }

        let requestId = nextRequestId
        nextRequestId += 1

        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "tools/call",
            "params": [
                "name": toolName,
                "arguments": arguments
            ],
            "id": requestId
        ]

        let data = try JSONSerialization.data(withJSONObject: payload)
        if let jsonLine = String(data: data, encoding: .utf8) {
            let message = jsonLine + "\n"
            if let messageData = message.data(using: .utf8) {
                running.stdin.fileHandleForWriting.write(messageData)
            }
        }

        for try await line in running.stdout.fileHandleForReading.bytes.lines {
            guard let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue
            }

            if let id = json["id"] as? Int, id == requestId {
                if let result = json["result"] as? [String: Any] {
                    return result
                }

                if let error = json["error"] {
                    throw MCPError.serverError("\(error)")
                }

                throw MCPError.invalidResponse
            }
        }

        throw MCPError.noResponse
    }

    func importUnstructured(from folder: URL, config: LLMConfiguration, provider: any LLMProviderProtocol) async -> (imported: [MCPServer], errors: [String]) {
        var imported: [MCPServer] = []
        var errors: [String] = []

        // Collect a subset of files for context
        let fm = FileManager.default
        let exts = ["md","txt","json","yaml","yml","sh","js","ts","py"]
        var snippets: [(String, String)] = [] // (relativePath, content)
        if let enumerator = fm.enumerator(at: folder, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
            // Convert to array to avoid async iteration warning
            let urls = enumerator.compactMap { $0 as? URL }
            for url in urls {
                guard exts.contains(url.pathExtension.lowercased()) else { continue }
                let rel = url.path.replacingOccurrences(of: folder.path, with: "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                if let data = try? Data(contentsOf: url), data.count < 200_000, let text = String(data: data, encoding: .utf8) {
                    let snippet = String(text.prefix(4000))
                    snippets.append((rel, snippet))
                    if snippets.count >= 12 { break }
                }
            }
        }

        // Build prompt for LLM
        var prompt = "You are an assistant that converts unstructured project files into MCP server definitions.\n"
        prompt += "Given a codebase snapshot, output JSON array of servers with fields: id (string), name (string), description (string), command (string), args (array of strings), path (string absolute).\n"
        prompt += "Use commands and scripts you infer from files. Prefer commands like npx, node, python3, or binaries referenced. Use the provided folder as default path if unknown.\n"
        prompt += "Only output JSON array, no extra text.\n\n"
        prompt += "Folder: \(folder.path)\n\nFiles:\n"
        for (rel, content) in snippets {
            prompt += "--- \(rel) ---\n\(content)\n\n"
        }

        // Call LLM and collect JSON
        let jsonText = await streamLLM(to: provider, config: config, prompt: prompt)

        // Try to decode
        if let data = jsonText.data(using: .utf8) {
            do {
                if let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    // Convert dictionaries to MCPServer via JSONEncoder/Decoder pipeline
                    let serverData = try JSONSerialization.data(withJSONObject: arr)
                    var servers = try JSONDecoder().decode([MCPServer].self, from: serverData)
                    // Normalize paths
                    servers = servers.map { s in
                        let p = s.path.isFileURL ? s.path : URL(fileURLWithPath: s.path.path)
                        return MCPServer(id: s.id, name: s.name, description: s.description, command: s.command, args: s.args, path: p)
                    }
                    // Save and return
                    for s in servers {
                        // Avoid duplicates by id
                        if !availableServers.contains(where: { $0.id == s.id }) {
                            availableServers.append(s)
                            imported.append(s)
                        }
                    }
                    saveServers()
                }
            } catch {
                errors.append("Decode error: \(error.localizedDescription)")
            }
        } else {
            errors.append("Invalid UTF-8 from model")
        }

        return (imported, errors)
    }

    func parseUnstructured(from folder: URL, config: LLMConfiguration, provider: any LLMProviderProtocol) async -> (servers: [MCPServer], errors: [String]) {
        var servers: [MCPServer] = []
        var errors: [String] = []

        // Reuse logic from importUnstructured but do not save; only return parsed servers
        let fm = FileManager.default
        let exts = ["md","txt","json","yaml","yml","sh","js","ts","py"]
        var snippets: [(String, String)] = []
        if let enumerator = fm.enumerator(at: folder, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
            // Convert to array to avoid async iteration warning
            let urls = enumerator.compactMap { $0 as? URL }
            for url in urls {
                guard exts.contains(url.pathExtension.lowercased()) else { continue }
                let rel = url.path.replacingOccurrences(of: folder.path, with: "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                if let data = try? Data(contentsOf: url), data.count < 200_000, let text = String(data: data, encoding: .utf8) {
                    let snippet = String(text.prefix(4000))
                    snippets.append((rel, snippet))
                    if snippets.count >= 12 { break }
                }
            }
        }

        var prompt = "You are an assistant that converts unstructured project files into MCP server definitions.\n"
        prompt += "Given a codebase snapshot, output JSON array of servers with fields: id (string), name (string), description (string), command (string), args (array of strings), path (string absolute).\n"
        prompt += "Use commands and scripts you infer from files. Prefer commands like npx, node, python3, or binaries referenced. Use the provided folder as default path if unknown.\n"
        prompt += "Only output JSON array, no extra text.\n\n"
        prompt += "Folder: \(folder.path)\n\nFiles:\n"
        for (rel, content) in snippets { prompt += "--- \(rel) ---\n\(content)\n\n" }

        let jsonText = await streamLLM(to: provider, config: config, prompt: prompt)

        if let data = jsonText.data(using: .utf8) {
            do {
                if let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    let serverData = try JSONSerialization.data(withJSONObject: arr)
                    servers = try JSONDecoder().decode([MCPServer].self, from: serverData)
                }
            } catch { errors.append("Decode error: \(error.localizedDescription)") }
        } else {
            errors.append("Invalid UTF-8 from model")
        }

        return (servers, errors)
    }

    func commitImported(_ servers: [MCPServer]) {
        var imported: [MCPServer] = []
        for s in servers {
            let normalizedPath = s.path.isFileURL ? s.path : URL(fileURLWithPath: s.path.path)
            let normalized = MCPServer(id: s.id, name: s.name, description: s.description, command: s.command, args: s.args, path: normalizedPath)
            if !availableServers.contains(where: { $0.id == normalized.id }) {
                availableServers.append(normalized)
                imported.append(normalized)
            }
        }
        saveServers()
    }

    private func streamLLM(to provider: any LLMProviderProtocol, config: LLMConfiguration, prompt: String) async -> String {
        var output = ""
        do {
            try await provider.streamMessage(prompt, configuration: config, conversationHistory: []) { chunk in
                output += chunk
            }
        } catch {
            print("LLM import error: \(error)")
        }
        // Attempt to extract JSON array if extra text exists
        if let start = output.firstIndex(of: "["), let end = output.lastIndex(of: "]"), start < end {
            let jsonRange = start...end
            return String(output[jsonRange])
        }
        return output
    }
}

struct MCPServer: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let command: String
    let args: [String]
    let path: URL

    enum CodingKeys: String, CodingKey {
        case id, name, description, command, args, path
    }
}

// MCP Tool definition
struct MCPTool: Codable {
    let name: String
    let description: String
    let inputSchema: [String: Any]

    enum CodingKeys: String, CodingKey {
        case name, description, inputSchema
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        // Simplified - would need custom decoding for Any
        inputSchema = [:]
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
    }
}

// Enhanced Ollama Provider with MCP support
class OllamaProviderWithMCP: OllamaProvider {
    weak var mcpManager: MCPServerManager?
    weak var browserTool: BrowserTool?
    private let toolCallParser = ToolCallParser()

    override func streamMessage(
        _ text: String,
        configuration: LLMConfiguration,
        conversationHistory: [Message],
        onChunk: @escaping (String) -> Void
    ) async throws {
        try await streamMessage(
            text,
            configuration: configuration,
            conversationHistory: conversationHistory,
            onChunk: onChunk,
            onToolResult: { _ in }
        )
    }

    func streamMessage(
        _ text: String,
        configuration: LLMConfiguration,
        conversationHistory: [Message],
        onChunk: @escaping (String) -> Void,
        onToolResult: @escaping (String) -> Void
    ) async throws {
        let baseMessages = buildBaseMessages(
            configuration: configuration,
            conversationHistory: conversationHistory
        )

        let userMessage: [String: Any] = [
            "role": "user",
            "content": text
        ]

        let firstMessages = baseMessages + [userMessage]

        let detection = try await streamWithToolDetection(
            messages: firstMessages,
            configuration: configuration,
            onChunk: onChunk
        )

        guard let toolCall = detection.toolCall else { return }

        let toolName = toolCall.name
        let delimiter = "::"
        if let range = toolName.range(of: delimiter) {
            let serverToken = String(toolName[..<range.lowerBound]).lowercased()
            let actualToolName = String(toolName[range.upperBound...]).lowercased()
            if serverToken == "local" {
                let toolResultString = await handleLocalTool(toolName: actualToolName, arguments: toolCall.arguments)
                onToolResult(toolResultString)
                let assistantMessage: [String: Any] = ["role": "assistant", "content": detection.rawText]
                let toolMessage: [String: Any] = ["role": "tool", "content": toolResultString]
                let baseMessages = buildBaseMessages(configuration: configuration, conversationHistory: conversationHistory)
                let userMessage: [String: Any] = ["role": "user", "content": text]
                let followUpMessages = baseMessages + [userMessage, assistantMessage, toolMessage]
                _ = try await streamSimple(messages: followUpMessages, configuration: configuration, onChunk: onChunk)
                return
            }
        }

        guard let manager = mcpManager else { return }

        let (server, resolvedToolName) = try await resolveToolTarget(
            toolName: toolCall.name,
            manager: manager
        )

        let toolResultString: String
        do {
            let toolResult = try await manager.callTool(
                server: server,
                toolName: resolvedToolName,
                arguments: toolCall.arguments
            )
            toolResultString = formatToolResult(toolResult)
        } catch {
            let errorPayload: [String: Any] = [
                "error": error.localizedDescription
            ]
            toolResultString = formatToolResult(errorPayload)
        }
        onToolResult(toolResultString)

        let assistantMessage: [String: Any] = [
            "role": "assistant",
            "content": detection.rawText
        ]
        let toolMessage: [String: Any] = [
            "role": "tool",
            "content": toolResultString
        ]

        let followUpMessages = baseMessages + [userMessage, assistantMessage, toolMessage]

        _ = try await streamSimple(
            messages: followUpMessages,
            configuration: configuration,
            onChunk: onChunk
        )
    }

    private func handleLocalTool(toolName: String, arguments: [String: Any]) async -> String {
        guard let browserTool = browserTool else { return "error: no local tool" }
        var cmd = BrowserCommand(action: toolName, url: nil, selector: nil, value: nil, clear: nil, path: nil)
        if let v = arguments["action"] as? String { cmd.action = v }
        if let v = arguments["url"] as? String { cmd.url = v }
        if let v = arguments["selector"] as? String { cmd.selector = v }
        if let v = arguments["value"] as? String { cmd.value = v }
        if let v = arguments["clear"] as? Bool { cmd.clear = v }
        if let v = arguments["path"] as? String { cmd.path = v }
        return await browserTool.handle(cmd)
    }

    private struct ToolDetectionResult {
        let rawText: String
        let toolCall: ToolCallParser.ParsedToolCall?
    }

    private func buildBaseMessages(
        configuration: LLMConfiguration,
        conversationHistory: [Message]
    ) -> [[String: Any]] {
        var messages: [[String: Any]] = []

        if let systemPrompt = configuration.systemPrompt {
            messages.append([
                "role": "system",
                "content": systemPrompt
            ])
        }

        for message in conversationHistory {
            let role: String
            switch message.role {
            case .user:
                role = "user"
            case .assistant:
                role = "assistant"
            case .system:
                role = "system"
            case .tool:
                role = "tool"
            }

            messages.append([
                "role": role,
                "content": message.content
            ])
        }

        return messages
    }

    private func streamWithToolDetection(
        messages: [[String: Any]],
        configuration: LLMConfiguration,
        onChunk: @escaping (String) -> Void
    ) async throws -> ToolDetectionResult {
        let url = URL(string: "http://localhost:11434/api/chat")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": configuration.model,
            "messages": messages,
            "stream": true,
            "options": [
                "temperature": configuration.temperature,
                "num_predict": configuration.maxTokens
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(
                domain: "OllamaProvider",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to connect to Ollama"]
            )
        }

        let toolStartToken = "```toolcall"
        let toolEndToken = "```"

        var rawText = ""
        var buffer = ""
        var inToolCall = false
        var detectedToolCall: ToolCallParser.ParsedToolCall?

        for try await line in asyncBytes.lines {
            guard !line.isEmpty else { continue }

            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let messageContent = json["message"] as? [String: Any],
                  let content = messageContent["content"] as? String else {
                continue
            }

            rawText += content
            buffer += content

            if detectedToolCall != nil {
                continue
            }

            if !inToolCall {
                if let range = buffer.range(of: toolStartToken) {
                    let before = String(buffer[..<range.lowerBound])
                    if !before.isEmpty {
                        onChunk(before)
                    }
                    buffer = String(buffer[range.lowerBound...])
                    inToolCall = true
                } else {
                    let split = toolCallParser.splitBufferForToolStart(buffer)
                    if !split.emit.isEmpty {
                        onChunk(split.emit)
                    }
                    buffer = split.remainder
                }
            }

            if inToolCall, let endRange = buffer.range(of: toolEndToken, options: [], range: buffer.index(buffer.startIndex, offsetBy: toolStartToken.count)..<buffer.endIndex) {
                let startIndex = buffer.index(buffer.startIndex, offsetBy: toolStartToken.count)
                let contentStart = buffer.range(of: "\n", range: startIndex..<buffer.endIndex)?.upperBound ?? startIndex
                let jsonString = buffer[contentStart..<endRange.lowerBound]

                if let toolCall = toolCallParser.parseToolCallJSON(String(jsonString)) {
                    detectedToolCall = toolCall
                }

                buffer = String(buffer[endRange.upperBound...])
                inToolCall = false
                break
            }
        }

        if detectedToolCall == nil, !buffer.isEmpty {
            onChunk(buffer)
        }

        return ToolDetectionResult(rawText: rawText, toolCall: detectedToolCall)
    }

    private func streamSimple(
        messages: [[String: Any]],
        configuration: LLMConfiguration,
        onChunk: @escaping (String) -> Void
    ) async throws -> String {
        let url = URL(string: "http://localhost:11434/api/chat")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": configuration.model,
            "messages": messages,
            "stream": true,
            "options": [
                "temperature": configuration.temperature,
                "num_predict": configuration.maxTokens
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(
                domain: "OllamaProvider",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to connect to Ollama"]
            )
        }

        var fullResponse = ""

        for try await line in asyncBytes.lines {
            guard !line.isEmpty else { continue }

            if let data = line.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let messageContent = json["message"] as? [String: Any],
               let content = messageContent["content"] as? String {
                fullResponse += content
                onChunk(content)
                try? await Task.sleep(nanoseconds: 30_000_000)
            }
        }

        return fullResponse
    }

    private func resolveToolTarget(
        toolName: String,
        manager: MCPServerManager
    ) async throws -> (MCPServer, String) {
        let enabledServers: [MCPServer] = await MainActor.run {
            manager.availableServers.filter { manager.enabledServers.contains($0.id) }
        }
        let delimiter = "::"

        if let range = toolName.range(of: delimiter) {
            let serverToken = String(toolName[..<range.lowerBound])
            let actualToolName = String(toolName[range.upperBound...])
            if let server = matchServer(token: serverToken, servers: enabledServers) {
                return (server, actualToolName)
            }
        }

        throw NSError(
            domain: "OllamaProviderWithMCP",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Tool name must use <server>::<tool_name> and match an enabled server: \(toolName)"]
        )
    }

    private func matchServer(token: String, servers: [MCPServer]) -> MCPServer? {
        let lowered = token.lowercased()
        return servers.first {
            $0.id.lowercased() == lowered || $0.name.lowercased() == lowered
        }
    }

    private func formatToolResult(_ result: [String: Any]) -> String {
        if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted]),
           let json = String(data: data, encoding: .utf8) {
            return json
        }

        return "\(result)"
    }
}

