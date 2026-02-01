import Foundation
import GRDB

// MARK: - Extension Record (Database)

/// Database record for installed MCP extensions
struct ExtensionRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "installed_extensions"

    var id: String
    var name: String
    var description: String
    var version: String
    var author: String
    var icon: String?
    var category: String
    var runtimeType: String
    var command: String
    var args: String  // JSON array
    var env: String?  // JSON object
    var permissions: String  // JSON array
    var installPath: String
    var installDate: Date
    var isEnabled: Bool
    var extensionJson: String  // Full extension JSON

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let name = Column(CodingKeys.name)
        static let description = Column(CodingKeys.description)
        static let version = Column(CodingKeys.version)
        static let author = Column(CodingKeys.author)
        static let icon = Column(CodingKeys.icon)
        static let category = Column(CodingKeys.category)
        static let runtimeType = Column(CodingKeys.runtimeType)
        static let command = Column(CodingKeys.command)
        static let args = Column(CodingKeys.args)
        static let env = Column(CodingKeys.env)
        static let permissions = Column(CodingKeys.permissions)
        static let installPath = Column(CodingKeys.installPath)
        static let installDate = Column(CodingKeys.installDate)
        static let isEnabled = Column(CodingKeys.isEnabled)
        static let extensionJson = Column(CodingKeys.extensionJson)
    }
}

// MARK: - Conversion Methods

extension ExtensionRecord {
    /// Initialize from an InstalledExtension
    init(_ installed: InstalledExtension) throws {
        self.id = installed.id
        self.name = installed.extension_.name
        self.description = installed.extension_.description
        self.version = installed.installedVersion
        self.author = installed.extension_.author
        self.icon = installed.extension_.icon
        self.category = installed.extension_.category.rawValue
        self.runtimeType = installed.extension_.serverConfig.runtime.rawValue
        self.command = installed.extension_.serverConfig.command

        // Encode args as JSON
        let argsData = try JSONEncoder().encode(installed.extension_.serverConfig.args)
        self.args = String(data: argsData, encoding: .utf8) ?? "[]"

        // Encode env as JSON
        if let env = installed.extension_.serverConfig.env {
            let envData = try JSONEncoder().encode(env)
            self.env = String(data: envData, encoding: .utf8)
        } else {
            self.env = nil
        }

        // Encode permissions as JSON
        let permissionsData = try JSONEncoder().encode(installed.extension_.permissions)
        self.permissions = String(data: permissionsData, encoding: .utf8) ?? "[]"

        self.installPath = installed.installPath.path
        self.installDate = installed.installDate
        self.isEnabled = installed.isEnabled

        // Encode full extension as JSON for complete restoration
        let extensionData = try JSONEncoder().encode(installed.extension_)
        self.extensionJson = String(data: extensionData, encoding: .utf8) ?? "{}"
    }

    /// Convert to InstalledExtension
    func asModel() throws -> InstalledExtension {
        // Decode the full extension from JSON
        guard let extensionData = extensionJson.data(using: .utf8) else {
            throw ExtensionRecordError.invalidJson
        }

        let decoder = JSONDecoder()
        let extension_ = try decoder.decode(MCPExtension.self, from: extensionData)

        return InstalledExtension(
            id: id,
            extension_: extension_,
            installDate: installDate,
            isEnabled: isEnabled,
            installedVersion: version,
            installPath: URL(fileURLWithPath: installPath),
            serverId: nil
        )
    }
}

// MARK: - Error Types

enum ExtensionRecordError: LocalizedError {
    case invalidJson

    var errorDescription: String? {
        switch self {
        case .invalidJson:
            return "Invalid JSON data in extension record"
        }
    }
}
