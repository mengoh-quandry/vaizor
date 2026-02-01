import Foundation

// MARK: - MCP Extension Models

/// Represents an installable MCP Extension
struct MCPExtension: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let description: String
    let version: String
    let author: String
    let icon: String?
    let iconURL: String?
    let homepage: String?
    let repository: String?
    let license: String?
    let serverConfig: MCPServerConfig
    let permissions: [ExtensionPermission]
    let installSteps: [InstallStep]?
    let category: ExtensionCategory
    let tags: [String]?
    let screenshots: [String]?
    let readme: String?
    let checksum: String?
    let signature: String?
    let minAppVersion: String?
    let dependencies: [ExtensionDependency]?

    enum CodingKeys: String, CodingKey {
        case id, name, description, version, author, icon, iconURL, homepage
        case repository, license, serverConfig, permissions, installSteps
        case category, tags, screenshots, readme, checksum, signature
        case minAppVersion, dependencies
    }

    static func == (lhs: MCPExtension, rhs: MCPExtension) -> Bool {
        lhs.id == rhs.id && lhs.version == rhs.version
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(version)
    }
}

/// Server configuration for running the MCP server
struct MCPServerConfig: Codable, Hashable {
    let command: String
    let args: [String]
    let env: [String: String]?
    let runtime: ExtensionRuntime
    let workingDirectory: String?

    enum CodingKeys: String, CodingKey {
        case command, args, env, runtime, workingDirectory
    }
}

/// Runtime environment for the extension
enum ExtensionRuntime: String, Codable, Hashable {
    case node = "node"
    case python = "python"
    case binary = "binary"
    case deno = "deno"
    case bun = "bun"

    var displayName: String {
        switch self {
        case .node: return "Node.js"
        case .python: return "Python"
        case .binary: return "Native Binary"
        case .deno: return "Deno"
        case .bun: return "Bun"
        }
    }

    var installCommand: String? {
        switch self {
        case .node: return "npm install"
        case .python: return "pip install -r requirements.txt"
        case .deno: return nil
        case .bun: return "bun install"
        case .binary: return nil
        }
    }

    var checkCommand: String {
        switch self {
        case .node: return "node --version"
        case .python: return "python3 --version"
        case .binary: return ""
        case .deno: return "deno --version"
        case .bun: return "bun --version"
        }
    }
}

/// Permission types for extensions
enum ExtensionPermission: Codable, Hashable {
    case filesystem(paths: [String])
    case network(domains: [String])
    case tools(names: [String])
    case resources(uris: [String])
    case environment(variables: [String])
    case execute(commands: [String])

    var displayName: String {
        switch self {
        case .filesystem: return "File System Access"
        case .network: return "Network Access"
        case .tools: return "Tool Capabilities"
        case .resources: return "Resource Access"
        case .environment: return "Environment Variables"
        case .execute: return "Execute Commands"
        }
    }

    var icon: String {
        switch self {
        case .filesystem: return "folder"
        case .network: return "network"
        case .tools: return "wrench.and.screwdriver"
        case .resources: return "doc.text"
        case .environment: return "gearshape.2"
        case .execute: return "terminal"
        }
    }

    var description: String {
        switch self {
        case .filesystem(let paths):
            return paths.isEmpty ? "Full filesystem access" : "Access to: \(paths.joined(separator: ", "))"
        case .network(let domains):
            return domains.isEmpty ? "Full network access" : "Access to: \(domains.joined(separator: ", "))"
        case .tools(let names):
            return names.isEmpty ? "All tools" : "Tools: \(names.joined(separator: ", "))"
        case .resources(let uris):
            return uris.isEmpty ? "All resources" : "Resources: \(uris.joined(separator: ", "))"
        case .environment(let vars):
            return vars.isEmpty ? "All environment variables" : "Variables: \(vars.joined(separator: ", "))"
        case .execute(let cmds):
            return cmds.isEmpty ? "Execute any command" : "Commands: \(cmds.joined(separator: ", "))"
        }
    }

    var riskLevel: PermissionRiskLevel {
        switch self {
        case .filesystem(let paths):
            return paths.isEmpty ? .high : .medium
        case .network(let domains):
            return domains.isEmpty ? .high : .medium
        case .tools: return .low
        case .resources: return .low
        case .environment: return .medium
        case .execute(let cmds):
            return cmds.isEmpty ? .high : .medium
        }
    }
}

enum PermissionRiskLevel: String, Codable {
    case low, medium, high

    var color: String {
        switch self {
        case .low: return "00976d"      // Green
        case .medium: return "d4a017"   // Yellow/Orange
        case .high: return "ff4444"     // Red
        }
    }
}

/// Installation steps for extensions
struct InstallStep: Codable, Hashable {
    let type: InstallStepType
    let command: String?
    let args: [String]?
    let workingDirectory: String?
    let description: String?
    let optional: Bool?
    let condition: String?

    enum CodingKeys: String, CodingKey {
        case type, command, args, workingDirectory, description, optional, condition
    }
}

enum InstallStepType: String, Codable, Hashable {
    case download = "download"
    case extract = "extract"
    case npm = "npm"
    case pip = "pip"
    case shell = "shell"
    case copy = "copy"
    case chmod = "chmod"
    case verify = "verify"
}

/// Category for organizing extensions
enum ExtensionCategory: String, Codable, CaseIterable {
    case productivity = "productivity"
    case development = "development"
    case data = "data"
    case communication = "communication"
    case media = "media"
    case utilities = "utilities"
    case ai = "ai"
    case security = "security"
    case other = "other"

    var displayName: String {
        switch self {
        case .productivity: return "Productivity"
        case .development: return "Development"
        case .data: return "Data & Analytics"
        case .communication: return "Communication"
        case .media: return "Media"
        case .utilities: return "Utilities"
        case .ai: return "AI & ML"
        case .security: return "Security"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .productivity: return "chart.bar.doc.horizontal"
        case .development: return "hammer"
        case .data: return "chart.pie"
        case .communication: return "message"
        case .media: return "photo"
        case .utilities: return "wrench"
        case .ai: return "brain"
        case .security: return "lock.shield"
        case .other: return "square.grid.2x2"
        }
    }
}

/// Dependency on another extension or system package
struct ExtensionDependency: Codable, Hashable {
    let name: String
    let version: String?
    let type: DependencyType
    let optional: Bool?
}

enum DependencyType: String, Codable, Hashable {
    case extension_ = "extension"
    case npm = "npm"
    case pip = "pip"
    case system = "system"
}

// MARK: - Installed Extension

/// Represents an installed extension with state
struct InstalledExtension: Identifiable, Codable {
    let id: String
    let extension_: MCPExtension
    let installDate: Date
    var isEnabled: Bool
    var installedVersion: String
    var installPath: URL
    var serverId: String?  // Associated MCP server ID if running

    enum CodingKeys: String, CodingKey {
        case id
        case extension_ = "extension"
        case installDate, isEnabled, installedVersion, installPath, serverId
    }
}

// MARK: - Extension Registry Response

/// Response from extension registry API
struct ExtensionRegistryResponse: Codable {
    let extensions: [MCPExtension]
    let totalCount: Int
    let page: Int
    let pageSize: Int
    let lastUpdated: Date?
}

/// Featured extensions from registry
struct FeaturedExtensions: Codable {
    let featured: [MCPExtension]
    let popular: [MCPExtension]
    let recent: [MCPExtension]
}
