import Foundation
import CryptoKit

// MARK: - Extension Registry Service

/// Service for discovering and managing MCP Extensions from registries
@MainActor
class ExtensionRegistry: ObservableObject {
    static let shared = ExtensionRegistry()

    // Registry URLs
    @Published var registryURLs: [URL] = [
        URL(string: "https://registry.mcp.tools/v1")!,  // Default MCP registry
        URL(string: "https://vaizor.dev/extensions/v1")!  // Vaizor curated
    ]

    // State
    @Published var availableExtensions: [MCPExtension] = []
    @Published var installedExtensions: [InstalledExtension] = []
    @Published var featuredExtensions: FeaturedExtensions?
    @Published var isLoading = false
    @Published var lastError: String?
    @Published var lastRefresh: Date?

    // Search and filter
    @Published var searchQuery: String = ""
    @Published var selectedCategory: ExtensionCategory?
    @Published var selectedRuntime: ExtensionRuntime?

    // Paths
    private let extensionsDirectory: URL
    private let installedConfigPath: URL

    private init() {
        // Setup extensions directory
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        extensionsDirectory = appSupport.appendingPathComponent("Vaizor/Extensions")
        installedConfigPath = extensionsDirectory.appendingPathComponent("installed.json")

        // Create directory if needed
        try? FileManager.default.createDirectory(at: extensionsDirectory, withIntermediateDirectories: true)

        // Load installed extensions
        loadInstalledExtensions()

        // Load bundled extensions
        loadBundledExtensions()
    }

    // MARK: - Registry Operations

    /// Fetch extensions from all configured registries
    func refreshRegistry() async {
        isLoading = true
        lastError = nil

        // Start with bundled extensions to preserve them
        var allExtensions: [MCPExtension] = bundledExtensions

        for registryURL in registryURLs {
            do {
                let extensions = try await fetchExtensions(from: registryURL)
                allExtensions.append(contentsOf: extensions)
                AppLogger.shared.log("Fetched \(extensions.count) extensions from \(registryURL)", level: .info)
            } catch {
                AppLogger.shared.logError(error, context: "Failed to fetch from registry: \(registryURL)")
                // Continue with other registries - bundled extensions still available
            }
        }

        // Deduplicate by ID (keep first occurrence - bundled take priority)
        var seen = Set<String>()
        availableExtensions = allExtensions.filter { ext in
            if seen.contains(ext.id) { return false }
            seen.insert(ext.id)
            return true
        }

        lastRefresh = Date()
        isLoading = false

        AppLogger.shared.log("Registry refresh complete: \(availableExtensions.count) total extensions (\(bundledExtensions.count) bundled)", level: .info)
    }

    // MARK: - Bundled Extensions

    /// Built-in extensions that are always available
    private var bundledExtensions: [MCPExtension] = []

    /// Fetch extensions from a single registry
    private func fetchExtensions(from registryURL: URL) async throws -> [MCPExtension] {
        let listURL = registryURL.appendingPathComponent("extensions")

        let (data, response) = try await URLSession.shared.data(from: listURL)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ExtensionRegistryError.invalidResponse
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let registryResponse = try decoder.decode(ExtensionRegistryResponse.self, from: data)
        return registryResponse.extensions
    }

    /// Fetch featured extensions
    func fetchFeatured() async {
        guard let registryURL = registryURLs.first else { return }

        let featuredURL = registryURL.appendingPathComponent("featured")

        do {
            let (data, response) = try await URLSession.shared.data(from: featuredURL)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            featuredExtensions = try decoder.decode(FeaturedExtensions.self, from: data)
        } catch {
            AppLogger.shared.logError(error, context: "Failed to fetch featured extensions")
        }
    }

    /// Search extensions
    func search(_ query: String, category: ExtensionCategory? = nil, runtime: ExtensionRuntime? = nil) async {
        guard let registryURL = registryURLs.first,
              var components = URLComponents(url: registryURL.appendingPathComponent("search"), resolvingAgainstBaseURL: false) else { return }

        var queryItems: [URLQueryItem] = []

        if !query.isEmpty {
            queryItems.append(URLQueryItem(name: "q", value: query))
        }
        if let category = category {
            queryItems.append(URLQueryItem(name: "category", value: category.rawValue))
        }
        if let runtime = runtime {
            queryItems.append(URLQueryItem(name: "runtime", value: runtime.rawValue))
        }

        components.queryItems = queryItems

        guard let searchURL = components.url else { return }

        isLoading = true

        do {
            let (data, response) = try await URLSession.shared.data(from: searchURL)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw ExtensionRegistryError.invalidResponse
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let searchResponse = try decoder.decode(ExtensionRegistryResponse.self, from: data)
            availableExtensions = searchResponse.extensions
        } catch {
            AppLogger.shared.logError(error, context: "Extension search failed")
            lastError = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Filtering

    /// Filter available extensions based on current criteria
    var filteredExtensions: [MCPExtension] {
        var filtered = availableExtensions

        // Filter by search query
        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            filtered = filtered.filter { ext in
                ext.name.lowercased().contains(query) ||
                ext.description.lowercased().contains(query) ||
                ext.author.lowercased().contains(query) ||
                (ext.tags ?? []).contains { $0.lowercased().contains(query) }
            }
        }

        // Filter by category
        if let category = selectedCategory {
            filtered = filtered.filter { $0.category == category }
        }

        // Filter by runtime
        if let runtime = selectedRuntime {
            filtered = filtered.filter { $0.serverConfig.runtime == runtime }
        }

        return filtered
    }

    /// Group extensions by category
    var extensionsByCategory: [ExtensionCategory: [MCPExtension]] {
        Dictionary(grouping: filteredExtensions, by: { $0.category })
    }

    // MARK: - Installation State

    /// Check if an extension is installed
    func isInstalled(_ extensionId: String) -> Bool {
        installedExtensions.contains { $0.id == extensionId }
    }

    /// Check if an extension has an update available
    func hasUpdate(_ extensionId: String) -> Bool {
        guard let installed = installedExtensions.first(where: { $0.id == extensionId }),
              let available = availableExtensions.first(where: { $0.id == extensionId }) else {
            return false
        }

        return compareVersions(installed.installedVersion, available.version) < 0
    }

    /// Get installed extension by ID
    func getInstalled(_ extensionId: String) -> InstalledExtension? {
        installedExtensions.first { $0.id == extensionId }
    }

    // MARK: - Persistence

    /// Load installed extensions from disk
    private func loadInstalledExtensions() {
        guard FileManager.default.fileExists(atPath: installedConfigPath.path),
              let data = try? Data(contentsOf: installedConfigPath) else {
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            installedExtensions = try decoder.decode([InstalledExtension].self, from: data)
            AppLogger.shared.log("Loaded \(installedExtensions.count) installed extensions", level: .info)
        } catch {
            AppLogger.shared.logError(error, context: "Failed to load installed extensions")
        }
    }

    /// Save installed extensions to disk
    func saveInstalledExtensions() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted

            let data = try encoder.encode(installedExtensions)
            try data.write(to: installedConfigPath)
        } catch {
            AppLogger.shared.logError(error, context: "Failed to save installed extensions")
        }
    }

    /// Add an installed extension
    func addInstalled(_ installed: InstalledExtension) {
        installedExtensions.removeAll { $0.id == installed.id }
        installedExtensions.append(installed)
        saveInstalledExtensions()
    }

    /// Remove an installed extension
    func removeInstalled(_ extensionId: String) {
        installedExtensions.removeAll { $0.id == extensionId }
        saveInstalledExtensions()
    }

    /// Update enabled state
    func setEnabled(_ extensionId: String, enabled: Bool) {
        if let index = installedExtensions.firstIndex(where: { $0.id == extensionId }) {
            installedExtensions[index].isEnabled = enabled
            saveInstalledExtensions()
        }
    }

    // MARK: - Bundled Extensions

    /// Load bundled/default extensions
    private func loadBundledExtensions() {
        // Add some popular extensions as examples
        let bundledExtensions: [MCPExtension] = [
            MCPExtension(
                id: "mcp-filesystem",
                name: "Filesystem",
                description: "Access and manage local files and directories",
                version: "1.0.0",
                author: "Model Context Protocol",
                icon: "folder",
                iconURL: nil,
                homepage: "https://github.com/modelcontextprotocol/servers",
                repository: "https://github.com/modelcontextprotocol/servers",
                license: "MIT",
                serverConfig: MCPServerConfig(
                    command: "npx",
                    args: ["-y", "@modelcontextprotocol/server-filesystem", "~"],
                    env: nil,
                    runtime: .node,
                    workingDirectory: nil
                ),
                permissions: [.filesystem(paths: ["~"])],
                installSteps: nil,
                category: .utilities,
                tags: ["files", "filesystem", "storage"],
                screenshots: nil,
                readme: nil,
                checksum: nil,
                signature: nil,
                minAppVersion: nil,
                dependencies: nil
            ),
            MCPExtension(
                id: "mcp-github",
                name: "GitHub",
                description: "Interact with GitHub repositories, issues, and pull requests",
                version: "1.0.0",
                author: "Model Context Protocol",
                icon: "network",
                iconURL: nil,
                homepage: "https://github.com/modelcontextprotocol/servers",
                repository: "https://github.com/modelcontextprotocol/servers",
                license: "MIT",
                serverConfig: MCPServerConfig(
                    command: "npx",
                    args: ["-y", "@modelcontextprotocol/server-github"],
                    env: ["GITHUB_PERSONAL_ACCESS_TOKEN": ""],
                    runtime: .node,
                    workingDirectory: nil
                ),
                permissions: [.network(domains: ["api.github.com"]), .environment(variables: ["GITHUB_PERSONAL_ACCESS_TOKEN"])],
                installSteps: nil,
                category: .development,
                tags: ["github", "git", "repository", "pr"],
                screenshots: nil,
                readme: nil,
                checksum: nil,
                signature: nil,
                minAppVersion: nil,
                dependencies: nil
            ),
            MCPExtension(
                id: "mcp-brave-search",
                name: "Brave Search",
                description: "Web search using Brave Search API",
                version: "1.0.0",
                author: "Model Context Protocol",
                icon: "magnifyingglass",
                iconURL: nil,
                homepage: "https://github.com/modelcontextprotocol/servers",
                repository: "https://github.com/modelcontextprotocol/servers",
                license: "MIT",
                serverConfig: MCPServerConfig(
                    command: "npx",
                    args: ["-y", "@modelcontextprotocol/server-brave-search"],
                    env: ["BRAVE_API_KEY": ""],
                    runtime: .node,
                    workingDirectory: nil
                ),
                permissions: [.network(domains: ["api.search.brave.com"]), .environment(variables: ["BRAVE_API_KEY"])],
                installSteps: nil,
                category: .utilities,
                tags: ["search", "web", "brave"],
                screenshots: nil,
                readme: nil,
                checksum: nil,
                signature: nil,
                minAppVersion: nil,
                dependencies: nil
            ),
            MCPExtension(
                id: "mcp-sqlite",
                name: "SQLite",
                description: "Query and manage SQLite databases",
                version: "1.0.0",
                author: "Model Context Protocol",
                icon: "cylinder",
                iconURL: nil,
                homepage: "https://github.com/modelcontextprotocol/servers",
                repository: "https://github.com/modelcontextprotocol/servers",
                license: "MIT",
                serverConfig: MCPServerConfig(
                    command: "uvx",
                    args: ["mcp-server-sqlite", "--db-path", "~/database.db"],
                    env: nil,
                    runtime: .python,
                    workingDirectory: nil
                ),
                permissions: [.filesystem(paths: ["~/*.db"])],
                installSteps: nil,
                category: .data,
                tags: ["database", "sqlite", "sql"],
                screenshots: nil,
                readme: nil,
                checksum: nil,
                signature: nil,
                minAppVersion: nil,
                dependencies: nil
            ),
            MCPExtension(
                id: "mcp-slack",
                name: "Slack",
                description: "Interact with Slack workspaces, channels, and messages",
                version: "1.0.0",
                author: "Model Context Protocol",
                icon: "message",
                iconURL: nil,
                homepage: "https://github.com/modelcontextprotocol/servers",
                repository: "https://github.com/modelcontextprotocol/servers",
                license: "MIT",
                serverConfig: MCPServerConfig(
                    command: "npx",
                    args: ["-y", "@modelcontextprotocol/server-slack"],
                    env: ["SLACK_BOT_TOKEN": "", "SLACK_TEAM_ID": ""],
                    runtime: .node,
                    workingDirectory: nil
                ),
                permissions: [.network(domains: ["api.slack.com"]), .environment(variables: ["SLACK_BOT_TOKEN", "SLACK_TEAM_ID"])],
                installSteps: nil,
                category: .communication,
                tags: ["slack", "messaging", "team"],
                screenshots: nil,
                readme: nil,
                checksum: nil,
                signature: nil,
                minAppVersion: nil,
                dependencies: nil
            ),
            MCPExtension(
                id: "mcp-puppeteer",
                name: "Puppeteer",
                description: "Browser automation and web scraping",
                version: "1.0.0",
                author: "Model Context Protocol",
                icon: "globe",
                iconURL: nil,
                homepage: "https://github.com/modelcontextprotocol/servers",
                repository: "https://github.com/modelcontextprotocol/servers",
                license: "MIT",
                serverConfig: MCPServerConfig(
                    command: "npx",
                    args: ["-y", "@modelcontextprotocol/server-puppeteer"],
                    env: nil,
                    runtime: .node,
                    workingDirectory: nil
                ),
                permissions: [.network(domains: []), .execute(commands: ["chromium"])],
                installSteps: nil,
                category: .utilities,
                tags: ["browser", "automation", "scraping", "puppeteer"],
                screenshots: nil,
                readme: nil,
                checksum: nil,
                signature: nil,
                minAppVersion: nil,
                dependencies: nil
            )
        ]

        // Store bundled extensions and add to available list
        self.bundledExtensions = bundledExtensions
        availableExtensions = bundledExtensions
    }

    // MARK: - Verification

    /// Verify extension checksum
    func verifyChecksum(data: Data, expected: String) -> Bool {
        let hash = SHA256.hash(data: data)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        return hashString == expected.lowercased()
    }

    // MARK: - Version Comparison

    /// Compare semantic versions
    /// Returns: -1 if v1 < v2, 0 if equal, 1 if v1 > v2
    private func compareVersions(_ v1: String, _ v2: String) -> Int {
        let parts1 = v1.split(separator: ".").compactMap { Int($0) }
        let parts2 = v2.split(separator: ".").compactMap { Int($0) }

        let maxLength = max(parts1.count, parts2.count)

        for i in 0..<maxLength {
            let p1 = i < parts1.count ? parts1[i] : 0
            let p2 = i < parts2.count ? parts2[i] : 0

            if p1 < p2 { return -1 }
            if p1 > p2 { return 1 }
        }

        return 0
    }

    // MARK: - Registry Management

    /// Add a custom registry URL
    func addRegistry(_ url: URL) {
        if !registryURLs.contains(url) {
            registryURLs.append(url)
        }
    }

    /// Remove a registry URL
    func removeRegistry(_ url: URL) {
        registryURLs.removeAll { $0 == url }
    }
}

// MARK: - Errors

enum ExtensionRegistryError: LocalizedError {
    case invalidResponse
    case networkError(Error)
    case decodingError(Error)
    case notFound(String)
    case checksumMismatch

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from extension registry"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode extension data: \(error.localizedDescription)"
        case .notFound(let id):
            return "Extension not found: \(id)"
        case .checksumMismatch:
            return "Extension checksum verification failed"
        }
    }
}
