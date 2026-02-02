import Foundation
import GRDB

struct MCPServerRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "mcp_servers"

    var id: String
    var name: String
    var description: String
    var command: String
    var args: String                    // JSON-encoded [String]
    var path: String?
    var env: String?                    // JSON-encoded [String: String]
    var workingDirectory: String?
    var sourceConfig: String?           // DiscoverySource raw value

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case command
        case args
        case path
        case env
        case workingDirectory = "working_directory"
        case sourceConfig = "source_config"
    }
}

extension MCPServerRecord {
    init(_ server: MCPServer) {
        id = server.id
        name = server.name
        description = server.description
        command = server.command

        // Encode args array as JSON
        if let data = try? JSONEncoder().encode(server.args),
           let encoded = String(data: data, encoding: .utf8) {
            args = encoded
        } else {
            args = "[]"
        }

        path = server.path?.path

        // Encode env dictionary as JSON
        if let serverEnv = server.env,
           let data = try? JSONEncoder().encode(serverEnv),
           let encoded = String(data: data, encoding: .utf8) {
            env = encoded
        } else {
            env = nil
        }

        workingDirectory = server.workingDirectory
        sourceConfig = server.sourceConfig?.rawValue
    }

    func asModel() -> MCPServer {
        // Decode args
        let decodedArgs: [String]
        if let data = args.data(using: .utf8),
           let value = try? JSONDecoder().decode([String].self, from: data) {
            decodedArgs = value
        } else {
            decodedArgs = []
        }

        // Decode env
        let decodedEnv: [String: String]?
        if let envString = env,
           let data = envString.data(using: .utf8),
           let value = try? JSONDecoder().decode([String: String].self, from: data) {
            decodedEnv = value
        } else {
            decodedEnv = nil
        }

        // Decode sourceConfig
        let decodedSource: DiscoverySource?
        if let sourceString = sourceConfig {
            decodedSource = DiscoverySource(rawValue: sourceString)
        } else {
            decodedSource = nil
        }

        let url = path.map { URL(fileURLWithPath: $0) }

        return MCPServer(
            id: id,
            name: name,
            description: description,
            command: command,
            args: decodedArgs,
            path: url,
            env: decodedEnv,
            workingDirectory: workingDirectory,
            sourceConfig: decodedSource
        )
    }
}
