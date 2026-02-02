import Foundation
import GRDB

actor TemplateRepository {
    private let dbQueue: DatabaseQueue
    
    init(dbQueue: DatabaseQueue = DatabaseManager.shared.dbQueue) {
        self.dbQueue = dbQueue
    }
    
    func loadTemplates() async -> [ConversationTemplate] {
        do {
            return try await dbQueue.read { db in
                try TemplateRecord
                    .order(Column("name").asc)
                    .fetchAll(db)
                    .map { $0.asModel() }
            }
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to load templates")
            }
            return []
        }
    }
    
    /// Save a template to the database
    /// - Returns: true if save succeeded, false otherwise
    @discardableResult
    func saveTemplate(_ template: ConversationTemplate) async -> Bool {
        do {
            try await dbQueue.write { db in
                try TemplateRecord(template).insert(db)
            }
            return true
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to save template \(template.id)")
            }
            return false
        }
    }

    /// Delete a template from the database
    /// - Returns: true if deletion succeeded, false otherwise
    @discardableResult
    func deleteTemplate(_ templateId: UUID) async -> Bool {
        do {
            try await dbQueue.write { db in
                _ = try TemplateRecord
                    .filter(Column("id") == templateId.uuidString)
                    .deleteAll(db)
            }
            return true
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to delete template \(templateId)")
            }
            return false
        }
    }
    
    func updateTemplate(_ template: ConversationTemplate) async {
        do {
            try await dbQueue.write { db in
                // Use save() for upsert behavior - safer than update() which fails if record doesn't exist
                try TemplateRecord(template).save(db)
            }
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to update template \(template.id)")
            }
        }
    }
}
