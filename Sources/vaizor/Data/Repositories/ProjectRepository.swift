import Foundation
import GRDB

actor ProjectRepository {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = DatabaseManager.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    // MARK: - Project CRUD

    func loadProjects(includeArchived: Bool = false) async -> [Project] {
        do {
            return try await dbQueue.read { db in
                var query = ProjectRecord.order(Column("updated_at").desc)
                if !includeArchived {
                    query = query.filter(Column("is_archived") == false)
                }
                return try query.fetchAll(db).map { $0.asModel() }
            }
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to load projects")
            }
            return []
        }
    }

    func loadProject(id: UUID) async -> Project? {
        do {
            return try await dbQueue.read { db in
                try ProjectRecord
                    .filter(Column("id") == id.uuidString)
                    .fetchOne(db)?
                    .asModel()
            }
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to load project \(id)")
            }
            return nil
        }
    }

    @discardableResult
    func saveProject(_ project: Project) async -> Bool {
        do {
            try await dbQueue.write { db in
                try ProjectRecord(project).insert(db)
            }
            return true
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to save project \(project.id)")
            }
            return false
        }
    }

    @discardableResult
    func updateProject(_ project: Project) async -> Bool {
        do {
            try await dbQueue.write { db in
                try ProjectRecord(project).save(db)
            }
            return true
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to update project \(project.id)")
            }
            return false
        }
    }

    @discardableResult
    func deleteProject(_ projectId: UUID) async -> Bool {
        do {
            try await dbQueue.write { db in
                _ = try ProjectRecord
                    .filter(Column("id") == projectId.uuidString)
                    .deleteAll(db)

                // Also clear project_id from associated conversations
                try db.execute(
                    sql: "UPDATE conversations SET project_id = NULL WHERE project_id = ?",
                    arguments: [projectId.uuidString]
                )
            }
            await MainActor.run {
                AppLogger.shared.log("Deleted project \(projectId) and cleared conversation associations", level: .info)
            }
            return true
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to delete project \(projectId)")
            }
            return false
        }
    }

    @discardableResult
    func archiveProject(_ projectId: UUID, isArchived: Bool) async -> Bool {
        do {
            try await dbQueue.write { db in
                if var record = try ProjectRecord.fetchOne(db, key: projectId.uuidString) {
                    record.isArchived = isArchived
                    record.updatedAt = Date().timeIntervalSince1970
                    try record.update(db)
                }
            }
            return true
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to archive project \(projectId)")
            }
            return false
        }
    }

    // MARK: - Conversation Management

    func addConversationToProject(conversationId: UUID, projectId: UUID) async -> Bool {
        guard var project = await loadProject(id: projectId) else { return false }

        if !project.conversations.contains(conversationId) {
            project.conversations.append(conversationId)
            project.updatedAt = Date()

            // Also update the conversation's projectId
            do {
                try await dbQueue.write { db in
                    try db.execute(
                        sql: "UPDATE conversations SET project_id = ? WHERE id = ?",
                        arguments: [projectId.uuidString, conversationId.uuidString]
                    )
                }
            } catch {
                await MainActor.run {
                    AppLogger.shared.logError(error, context: "Failed to update conversation project_id")
                }
            }

            return await updateProject(project)
        }
        return true
    }

    func removeConversationFromProject(conversationId: UUID, projectId: UUID) async -> Bool {
        guard var project = await loadProject(id: projectId) else { return false }

        project.conversations.removeAll { $0 == conversationId }
        project.updatedAt = Date()

        // Also clear the conversation's projectId
        do {
            try await dbQueue.write { db in
                try db.execute(
                    sql: "UPDATE conversations SET project_id = NULL WHERE id = ?",
                    arguments: [conversationId.uuidString]
                )
            }
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to clear conversation project_id")
            }
        }

        return await updateProject(project)
    }

    func getConversationsForProject(_ projectId: UUID) async -> [UUID] {
        guard let project = await loadProject(id: projectId) else { return [] }
        return project.conversations
    }

    // MARK: - Memory Management

    func addMemoryEntry(_ entry: MemoryEntry, to projectId: UUID) async -> Bool {
        guard var project = await loadProject(id: projectId) else { return false }

        project.context.memory.append(entry)
        project.updatedAt = Date()

        return await updateProject(project)
    }

    func updateMemoryEntry(_ entry: MemoryEntry, in projectId: UUID) async -> Bool {
        guard var project = await loadProject(id: projectId) else { return false }

        if let index = project.context.memory.firstIndex(where: { $0.id == entry.id }) {
            project.context.memory[index] = entry
            project.updatedAt = Date()
            return await updateProject(project)
        }
        return false
    }

    func removeMemoryEntry(_ entryId: UUID, from projectId: UUID) async -> Bool {
        guard var project = await loadProject(id: projectId) else { return false }

        project.context.memory.removeAll { $0.id == entryId }
        project.updatedAt = Date()

        return await updateProject(project)
    }

    func getActiveMemories(for projectId: UUID) async -> [MemoryEntry] {
        guard let project = await loadProject(id: projectId) else { return [] }
        return project.context.memory.filter { $0.isActive }
    }

    // MARK: - File Management

    func addFile(_ file: ProjectFile, to projectId: UUID) async -> Bool {
        guard var project = await loadProject(id: projectId) else { return false }

        project.context.files.append(file)
        project.updatedAt = Date()

        return await updateProject(project)
    }

    func removeFile(_ fileId: UUID, from projectId: UUID) async -> Bool {
        guard var project = await loadProject(id: projectId) else { return false }

        project.context.files.removeAll { $0.id == fileId }
        project.updatedAt = Date()

        return await updateProject(project)
    }

    // MARK: - Context Management

    func updateProjectContext(_ context: ProjectContext, for projectId: UUID) async -> Bool {
        guard var project = await loadProject(id: projectId) else { return false }

        project.context = context
        project.updatedAt = Date()

        return await updateProject(project)
    }

    func getProjectContext(for projectId: UUID) async -> ProjectContext? {
        guard let project = await loadProject(id: projectId) else { return nil }
        return project.context
    }

    // MARK: - Search

    func searchProjects(query: String) async -> [Project] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return await loadProjects()
        }

        do {
            let searchPattern = "%\(query.lowercased())%"
            return try await dbQueue.read { db in
                try ProjectRecord
                    .filter(Column("name").lowercased.like(searchPattern))
                    .filter(Column("is_archived") == false)
                    .order(Column("updated_at").desc)
                    .fetchAll(db)
                    .map { $0.asModel() }
            }
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to search projects")
            }
            return []
        }
    }
}
