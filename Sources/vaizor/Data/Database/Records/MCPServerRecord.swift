import Foundation
import GRDB

struct MCPServerRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "mcp_servers"

    var id: String
    var name: String
    var description: String
    var command: String
    var args: String
    var path: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case command
        case args
        case path
    }
}

extension MCPServerRecord {
    init(_ server: MCPServer) {
        id = server.id
        name = server.name
        description = server.description
        command = server.command
        if let data = try? JSONEncoder().encode(server.args),
           let encoded = String(data: data, encoding: .utf8) {
            args = encoded
        } else {
            args = "[]"
        }
        path = server.path?.path
    }

    func asModel() -> MCPServer {
        let decodedArgs: [String]
        if let data = args.data(using: .utf8),
           let value = try? JSONDecoder().decode([String].self, from: data) {
            decodedArgs = value
        } else {
            decodedArgs = []
        }
        let url = path.map { URL(fileURLWithPath: $0) }
        return MCPServer(
            id: id,
            name: name,
            description: description,
            command: command,
            args: decodedArgs,
            path: url
        )
    }
}
