import Foundation
import GRDB

/// Repository for managing tool execution history
actor ToolRunRepository {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = DatabaseManager.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    // MARK: - Save Operations

    /// Save a tool run record
    func saveToolRun(_ toolRun: ToolRun) async {
        do {
            try await dbQueue.write { db in
                try ToolRunRecord(toolRun).insert(db)
            }
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to save tool run \(toolRun.id)")
            }
        }
    }

    /// Save multiple tool runs in a batch
    func saveToolRuns(_ toolRuns: [ToolRun]) async {
        guard !toolRuns.isEmpty else { return }

        do {
            try await dbQueue.write { db in
                for toolRun in toolRuns {
                    try ToolRunRecord(toolRun).insert(db)
                }
            }
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to save \(toolRuns.count) tool runs")
            }
        }
    }

    // MARK: - Query Operations

    /// Load tool runs for a conversation
    func loadToolRuns(
        for conversationId: UUID,
        limit: Int = 100
    ) async -> [ToolRun] {
        let conversationIdString = conversationId.uuidString
        do {
            return try await dbQueue.read { db in
                let records = try ToolRunRecord
                    .filter(Column("conversation_id") == conversationIdString)
                    .order(Column("created_at").desc)
                    .limit(limit)
                    .fetchAll(db)

                return records.reversed().map { $0.asModel() }
            }
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to load tool runs for conversation \(conversationIdString)")
            }
            return []
        }
    }

    /// Load tool runs for a specific message
    func loadToolRuns(for messageId: UUID) async -> [ToolRun] {
        let messageIdString = messageId.uuidString
        do {
            return try await dbQueue.read { db in
                let records = try ToolRunRecord
                    .filter(Column("message_id") == messageIdString)
                    .order(Column("created_at").asc)
                    .fetchAll(db)

                return records.map { $0.asModel() }
            }
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to load tool runs for message \(messageIdString)")
            }
            return []
        }
    }

    /// Get a specific tool run by ID
    func getToolRun(_ id: UUID) async -> ToolRun? {
        let idString = id.uuidString
        do {
            return try await dbQueue.read { db in
                try ToolRunRecord
                    .fetchOne(db, key: idString)?
                    .asModel()
            }
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to get tool run \(idString)")
            }
            return nil
        }
    }

    /// Get recent tool runs across all conversations
    func getRecentToolRuns(limit: Int = 50) async -> [ToolRun] {
        do {
            return try await dbQueue.read { db in
                let records = try ToolRunRecord
                    .order(Column("created_at").desc)
                    .limit(limit)
                    .fetchAll(db)

                return records.map { $0.asModel() }
            }
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to get recent tool runs")
            }
            return []
        }
    }

    /// Get tool runs by tool name
    func getToolRuns(byToolName toolName: String, limit: Int = 50) async -> [ToolRun] {
        do {
            return try await dbQueue.read { db in
                let records = try ToolRunRecord
                    .filter(Column("tool_name") == toolName)
                    .order(Column("created_at").desc)
                    .limit(limit)
                    .fetchAll(db)

                return records.map { $0.asModel() }
            }
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to get tool runs for tool \(toolName)")
            }
            return []
        }
    }

    /// Get tool runs by server ID
    func getToolRuns(byServerId serverId: String, limit: Int = 50) async -> [ToolRun] {
        do {
            return try await dbQueue.read { db in
                let records = try ToolRunRecord
                    .filter(Column("tool_server_id") == serverId)
                    .order(Column("created_at").desc)
                    .limit(limit)
                    .fetchAll(db)

                return records.map { $0.asModel() }
            }
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to get tool runs for server \(serverId)")
            }
            return []
        }
    }

    /// Get error tool runs
    func getErrorToolRuns(limit: Int = 50) async -> [ToolRun] {
        do {
            return try await dbQueue.read { db in
                let records = try ToolRunRecord
                    .filter(Column("is_error") == true)
                    .order(Column("created_at").desc)
                    .limit(limit)
                    .fetchAll(db)

                return records.map { $0.asModel() }
            }
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to get error tool runs")
            }
            return []
        }
    }

    // MARK: - Statistics

    /// Get tool usage statistics
    func getToolUsageStats() async -> [String: Int] {
        do {
            return try await dbQueue.read { db in
                let rows = try Row.fetchAll(db, sql: """
                    SELECT tool_name, COUNT(*) as count
                    FROM tool_runs
                    GROUP BY tool_name
                    ORDER BY count DESC
                """)

                var stats: [String: Int] = [:]
                for row in rows {
                    if let name = row["tool_name"] as? String,
                       let count = row["count"] as? Int {
                        stats[name] = count
                    }
                }
                return stats
            }
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to get tool usage stats")
            }
            return [:]
        }
    }

    /// Get error rate by tool
    func getToolErrorRates() async -> [String: Double] {
        do {
            return try await dbQueue.read { db in
                let rows = try Row.fetchAll(db, sql: """
                    SELECT
                        tool_name,
                        COUNT(*) as total,
                        SUM(CASE WHEN is_error = 1 THEN 1 ELSE 0 END) as errors
                    FROM tool_runs
                    GROUP BY tool_name
                """)

                var rates: [String: Double] = [:]
                for row in rows {
                    if let name = row["tool_name"] as? String,
                       let total = row["total"] as? Int,
                       let errors = row["errors"] as? Int,
                       total > 0 {
                        rates[name] = Double(errors) / Double(total)
                    }
                }
                return rates
            }
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to get tool error rates")
            }
            return [:]
        }
    }

    // MARK: - Delete Operations

    /// Delete a tool run by ID
    func deleteToolRun(_ id: UUID) async {
        do {
            try await dbQueue.write { db in
                _ = try ToolRunRecord
                    .filter(Column("id") == id.uuidString)
                    .deleteAll(db)
            }
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to delete tool run \(id)")
            }
        }
    }

    /// Delete all tool runs for a conversation
    func deleteToolRuns(for conversationId: UUID) async {
        do {
            try await dbQueue.write { db in
                _ = try ToolRunRecord
                    .filter(Column("conversation_id") == conversationId.uuidString)
                    .deleteAll(db)
            }
            await MainActor.run {
                AppLogger.shared.log("Deleted tool runs for conversation \(conversationId)", level: .info)
            }
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to delete tool runs for conversation \(conversationId)")
            }
        }
    }

    /// Delete old tool runs (cleanup)
    func deleteOldToolRuns(olderThan days: Int) async -> Int {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let cutoffTimestamp = cutoffDate.timeIntervalSince1970

        do {
            let deletedCount = try await dbQueue.write { db in
                try ToolRunRecord
                    .filter(Column("created_at") < cutoffTimestamp)
                    .deleteAll(db)
            }

            await MainActor.run {
                AppLogger.shared.log("Deleted \(deletedCount) tool runs older than \(days) days", level: .info)
            }

            return deletedCount
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to delete old tool runs")
            }
            return 0
        }
    }
}
