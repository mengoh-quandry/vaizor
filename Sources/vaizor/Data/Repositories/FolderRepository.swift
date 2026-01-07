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
    
    func saveFolder(_ folder: Folder) async {
        do {
            try await dbQueue.write { db in
                try FolderRecord(folder).insert(db)
            }
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to save folder \(folder.id)")
            }
        }
    }
    
    func deleteFolder(_ folderId: UUID) async {
        do {
            try await dbQueue.write { db in
                _ = try FolderRecord
                    .filter(Column("id") == folderId.uuidString)
                    .deleteAll(db)
            }
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to delete folder \(folderId)")
            }
        }
    }
    
    func updateFolder(_ folder: Folder) async {
        do {
            try await dbQueue.write { db in
                try FolderRecord(folder).update(db)
            }
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to update folder \(folder.id)")
            }
        }
    }
}
