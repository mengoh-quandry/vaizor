import Foundation

// Enhanced MCP error handling and validation
enum MCPImportError: LocalizedError {
    case folderNotAccessible
    case noFilesFound
    case llmError(String)
    case parsingFailed(String)
    case invalidServerConfiguration(String)
    
    var errorDescription: String? {
        switch self {
        case .folderNotAccessible:
            return "Cannot access the selected folder. Check permissions."
        case .noFilesFound:
            return "No suitable files found in the folder for analysis."
        case .llmError(let message):
            return "LLM processing error: \(message)"
        case .parsingFailed(let message):
            return "Failed to parse server configuration: \(message)"
        case .invalidServerConfiguration(let message):
            return "Invalid server configuration: \(message)"
        }
    }
}

extension MCPServerManager {
    // Enhanced import with better error handling and validation
    @MainActor
    func importUnstructuredEnhanced(
        from folder: URL,
        config: LLMConfiguration,
        provider: any LLMProviderProtocol,
        progressHandler: @escaping (String) -> Void
    ) async -> Result<[MCPServer], MCPImportError> {
        
        progressHandler("Scanning folder...")
        
        // Validate folder access
        guard FileManager.default.isReadableFile(atPath: folder.path) else {
            return .failure(.folderNotAccessible)
        }
        
        // Collect files with better categorization
        let fm = FileManager.default
        let exts = ["md", "txt", "json", "yaml", "yml", "sh", "js", "ts", "py", "package.json"]
        var snippets: [(String, String)] = []
        var packageJsons: [String] = []
        
        progressHandler("Analyzing files...")
        
        if let enumerator = fm.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) {
            let urls = Array(enumerator.compactMap { $0 as? URL })
            for url in urls {
                let ext = url.pathExtension.lowercased()
                let filename = url.lastPathComponent.lowercased()
                
                guard exts.contains(ext) || filename == "package.json" else { continue }
                
                let rel = url.path.replacingOccurrences(of: folder.path, with: "")
                    .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                
                if let data = try? Data(contentsOf: url),
                   data.count < 200_000,
                   let text = String(data: data, encoding: .utf8) {
                    
                    // Special handling for package.json
                    if filename == "package.json" {
                        packageJsons.append(text)
                    }
                    
                    let snippet = String(text.prefix(4000))
                    snippets.append((rel, snippet))
                    
                    if snippets.count >= 15 { break }
                }
            }
        }
        
        guard !snippets.isEmpty else {
            return .failure(.noFilesFound)
        }
        
        progressHandler("Building LLM prompt...")
        
        // Enhanced prompt with better structure
        var prompt = """
        You are an expert at analyzing codebases and extracting MCP server configurations.
        
        Given a codebase snapshot, output a JSON array of server definitions.
        Each server must have these fields:
        - id: unique identifier (string)
        - name: descriptive name (string)
        - description: what the server does (string)
        - command: executable command (e.g., "npx", "node", "python3")
        - args: array of command arguments (array of strings)
        - path: absolute path (use "\(folder.path)" as base)
        
        IMPORTANT RULES:
        1. Only extract servers that you can clearly identify
        2. For npm packages, use "npx" with "-y" flag
        3. For Python scripts, use "python3" or "python"
        4. Ensure commands are commonly available
        5. Return ONLY valid JSON array, no markdown, no explanations
        
        Folder: \(folder.path)
        
        """
        
        // Add package.json insights
        if !packageJsons.isEmpty {
            prompt += "\n=== package.json files ===\n"
            for pkg in packageJsons.prefix(3) {
                prompt += "\(pkg)\n\n"
            }
        }
        
        prompt += "\n=== Code Files ===\n"
        for (rel, content) in snippets {
            prompt += "--- \(rel) ---\n\(content)\n\n"
        }
        
        prompt += """
        
        Now output the JSON array of MCP servers found:
        """
        
        progressHandler("Querying LLM...")
        
        // Call LLM
        let jsonText = await streamLLMEnhanced(
            to: provider,
            config: config,
            prompt: prompt,
            progressHandler: progressHandler
        )
        
        progressHandler("Parsing response...")
        
        // Enhanced JSON extraction
        guard let cleanJson = extractJSON(from: jsonText) else {
            return .failure(.parsingFailed("No valid JSON found in response"))
        }
        
        // Parse and validate
        guard let data = cleanJson.data(using: .utf8) else {
            return .failure(.parsingFailed("Invalid UTF-8 encoding"))
        }
        
        do {
            if let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                let serverData = try JSONSerialization.data(withJSONObject: arr)
                var servers = try JSONDecoder().decode([MCPServer].self, from: serverData)
                
                // Validate and normalize
                servers = try servers.map { server in
                    try validateAndNormalize(server: server, baseFolder: folder)
                }
                
                progressHandler("Successfully parsed \(servers.count) server(s)")
                return .success(servers)
            } else {
                return .failure(.parsingFailed("Response is not a JSON array"))
            }
        } catch {
            return .failure(.parsingFailed(error.localizedDescription))
        }
    }
    
    // Extract JSON from potentially messy LLM output
    private func extractJSON(from text: String) -> String? {
        // Try to find JSON array in the text
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove markdown code blocks
        if cleaned.hasPrefix("```json") {
            cleaned = cleaned.replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else if cleaned.hasPrefix("```") {
            cleaned = cleaned.replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Find array boundaries
        if let start = cleaned.firstIndex(of: "["),
           let end = cleaned.lastIndex(of: "]"),
           start < end {
            let jsonRange = start...end
            return String(cleaned[jsonRange])
        }
        
        return nil
    }
    
    // Validate and normalize server configuration
    private func validateAndNormalize(server: MCPServer, baseFolder: URL) throws -> MCPServer {
        // Validate required fields
        guard !server.name.isEmpty else {
            throw MCPImportError.invalidServerConfiguration("Server name cannot be empty")
        }

        guard !server.command.isEmpty else {
            throw MCPImportError.invalidServerConfiguration("Command cannot be empty for \(server.name)")
        }

        // Normalize path
        let normalizedPath: URL
        if let serverPath = server.path {
            if serverPath.path.isEmpty || serverPath.path == "/" {
                normalizedPath = baseFolder
            } else if serverPath.isFileURL {
                normalizedPath = serverPath
            } else {
                normalizedPath = URL(fileURLWithPath: serverPath.path)
            }
        } else {
            normalizedPath = baseFolder
        }

        return MCPServer(
            id: server.id,
            name: server.name,
            description: server.description,
            command: server.command,
            args: server.args,
            path: normalizedPath
        )
    }
    
    // Enhanced LLM streaming with progress updates
    private func streamLLMEnhanced(
        to provider: any LLMProviderProtocol,
        config: LLMConfiguration,
        prompt: String,
        progressHandler: @escaping (String) -> Void
    ) async -> String {
        var output = ""
        var chunkCount = 0
        
        do {
            try await provider.streamMessage(
                prompt,
                configuration: config,
                conversationHistory: [],
                onChunk: { chunk in
                    output += chunk
                    chunkCount += 1

                    if chunkCount % 20 == 0 {
                        progressHandler("Receiving response... (\(output.count) chars)")
                    }
                },
                onThinkingStatusUpdate: { _ in }
            )
        } catch {
            progressHandler("Error: \(error.localizedDescription)")
        }
        
        return output
    }
}
