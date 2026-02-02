import Foundation
import GRDB

/// Database record for key-value settings storage
struct SettingsRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "settings"

    var key: String
    var value: String

    enum CodingKeys: String, CodingKey {
        case key
        case value
    }
}

// MARK: - Settings Repository

/// Repository for managing key-value settings in SQLite
actor SettingsRepository {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = DatabaseManager.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    // MARK: - String Values

    /// Get a string setting value
    func getString(_ key: String) async -> String? {
        do {
            return try await dbQueue.read { db in
                try SettingsRecord.fetchOne(db, key: key)?.value
            }
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to get setting '\(key)'")
            }
            return nil
        }
    }

    /// Set a string setting value
    func setString(_ key: String, value: String?) async {
        do {
            try await dbQueue.write { db in
                if let value = value {
                    let record = SettingsRecord(key: key, value: value)
                    try record.save(db)
                } else {
                    _ = try SettingsRecord.deleteOne(db, key: key)
                }
            }
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to set setting '\(key)'")
            }
        }
    }

    // MARK: - Bool Values

    /// Get a boolean setting value
    func getBool(_ key: String, default defaultValue: Bool = false) async -> Bool {
        guard let stringValue = await getString(key) else {
            return defaultValue
        }
        return stringValue == "true" || stringValue == "1"
    }

    /// Set a boolean setting value
    func setBool(_ key: String, value: Bool) async {
        await setString(key, value: value ? "true" : "false")
    }

    // MARK: - Int Values

    /// Get an integer setting value
    func getInt(_ key: String, default defaultValue: Int = 0) async -> Int {
        guard let stringValue = await getString(key),
              let intValue = Int(stringValue) else {
            return defaultValue
        }
        return intValue
    }

    /// Set an integer setting value
    func setInt(_ key: String, value: Int) async {
        await setString(key, value: String(value))
    }

    // MARK: - Double Values

    /// Get a double setting value
    func getDouble(_ key: String, default defaultValue: Double = 0.0) async -> Double {
        guard let stringValue = await getString(key),
              let doubleValue = Double(stringValue) else {
            return defaultValue
        }
        return doubleValue
    }

    /// Set a double setting value
    func setDouble(_ key: String, value: Double) async {
        await setString(key, value: String(value))
    }

    // MARK: - Date Values

    /// Get a date setting value
    func getDate(_ key: String) async -> Date? {
        guard let stringValue = await getString(key),
              let timestamp = Double(stringValue) else {
            return nil
        }
        return Date(timeIntervalSince1970: timestamp)
    }

    /// Set a date setting value
    func setDate(_ key: String, value: Date?) async {
        if let date = value {
            await setString(key, value: String(date.timeIntervalSince1970))
        } else {
            await setString(key, value: nil)
        }
    }

    // MARK: - JSON Values

    /// Get a JSON-encoded value
    func getJSON<T: Decodable>(_ key: String, type: T.Type) async -> T? {
        guard let stringValue = await getString(key),
              let data = stringValue.data(using: .utf8) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to decode JSON setting '\(key)'")
            }
            return nil
        }
    }

    /// Set a JSON-encoded value
    func setJSON<T: Encodable>(_ key: String, value: T?) async {
        guard let value = value else {
            await setString(key, value: nil)
            return
        }

        do {
            let data = try JSONEncoder().encode(value)
            if let jsonString = String(data: data, encoding: .utf8) {
                await setString(key, value: jsonString)
            }
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to encode JSON setting '\(key)'")
            }
        }
    }

    // MARK: - Bulk Operations

    /// Get all settings
    func getAllSettings() async -> [String: String] {
        do {
            return try await dbQueue.read { db in
                let records = try SettingsRecord.fetchAll(db)
                return Dictionary(uniqueKeysWithValues: records.map { ($0.key, $0.value) })
            }
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to get all settings")
            }
            return [:]
        }
    }

    /// Set multiple settings at once
    func setSettings(_ settings: [String: String]) async {
        do {
            try await dbQueue.write { db in
                for (key, value) in settings {
                    let record = SettingsRecord(key: key, value: value)
                    try record.save(db)
                }
            }
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to set multiple settings")
            }
        }
    }

    /// Delete a setting
    func deleteSetting(_ key: String) async {
        await setString(key, value: nil)
    }

    /// Delete all settings
    func deleteAllSettings() async {
        do {
            try await dbQueue.write { db in
                _ = try SettingsRecord.deleteAll(db)
            }
            await MainActor.run {
                AppLogger.shared.log("Deleted all settings", level: .info)
            }
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to delete all settings")
            }
        }
    }

    /// Get settings by prefix (useful for namespaced settings)
    func getSettings(withPrefix prefix: String) async -> [String: String] {
        do {
            return try await dbQueue.read { db in
                let records = try SettingsRecord
                    .filter(Column("key").like("\(prefix)%"))
                    .fetchAll(db)
                return Dictionary(uniqueKeysWithValues: records.map { ($0.key, $0.value) })
            }
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to get settings with prefix '\(prefix)'")
            }
            return [:]
        }
    }

    /// Delete settings by prefix
    func deleteSettings(withPrefix prefix: String) async {
        do {
            try await dbQueue.write { db in
                _ = try SettingsRecord
                    .filter(Column("key").like("\(prefix)%"))
                    .deleteAll(db)
            }
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to delete settings with prefix '\(prefix)'")
            }
        }
    }
}

// MARK: - Settings Keys

/// Centralized settings key definitions
enum SettingsKey {
    // API Keys
    static let anthropicApiKey = "api.anthropic.key"
    static let openaiApiKey = "api.openai.key"
    static let geminiApiKey = "api.gemini.key"

    // Provider Settings
    static let selectedProvider = "provider.selected"
    static let selectedModel = "provider.model"
    static let ollamaHost = "provider.ollama.host"

    // Chat Settings
    static let systemPromptPrefix = "chat.system_prompt"
    static let enableChainOfThought = "chat.chain_of_thought"
    static let enablePromptEnhancement = "chat.prompt_enhancement"
    static let temperature = "chat.temperature"
    static let maxTokens = "chat.max_tokens"

    // Built-in Tools
    static let builtInToolsEnabled = "tools.builtin.enabled"

    // MCP Settings
    static let mcpServersEnabled = "mcp.servers.enabled"

    // UI Settings
    static let showCostTracker = "ui.cost_tracker.show"
    static let artifactPanelPosition = "ui.artifact_panel.position"
    static let sidebarWidth = "ui.sidebar.width"

    // App Settings
    static let firstLaunchCompleted = "app.first_launch.completed"
    static let lastUsedVersion = "app.version.last"
}
