import Foundation
import GRDB

actor FolderRepository {
    private let dbQueue: DatabaseQueue
    
    init(dbQueue: DatabaseQueue = DatabaseManager.shared.dbQueue) {
        self.dbQueue = dbQueue
    }
    
    func loadFolders() async -> [Folder] {
        do {
            return try await dbQueue.read { db in
                try FolderRecord
                    .order(Column("name").asc)
                    .fetchAll(db)
                    .map { $0.asModel() }
            }
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to load folders")
            }
            return []
        }
    }
    
    /// Save a folder to the database
    /// - Returns: true if save succeeded, false otherwise
    @discardableResult
    func saveFolder(_ folder: Folder) async -> Bool {
        do {
            try await dbQueue.write { db in
                try FolderRecord(folder).insert(db)
            }
            return true
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to save folder \(folder.id)")
            }
            return false
        }
    }

    /// Delete a folder from the database
    /// - Returns: true if deletion succeeded, false otherwise
    @discardableResult
    func deleteFolder(_ folderId: UUID) async -> Bool {
        do {
            try await dbQueue.write { db in
                _ = try FolderRecord
                    .filter(Column("id") == folderId.uuidString)
                    .deleteAll(db)
            }
            return true
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to delete folder \(folderId)")
            }
            return false
        }
    }
    
    func updateFolder(_ folder: Folder) async {
        do {
            try await dbQueue.write { db in
                // Use save() for upsert behavior - safer than update() which fails if record doesn't exist
                try FolderRecord(folder).save(db)
            }
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to update folder \(folder.id)")
            }
        }
    }
}
