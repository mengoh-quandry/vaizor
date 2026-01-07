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
    
    func saveTemplate(_ template: ConversationTemplate) async {
        do {
            try await dbQueue.write { db in
                try TemplateRecord(template).insert(db)
            }
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to save template \(template.id)")
            }
        }
    }
    
    func deleteTemplate(_ templateId: UUID) async {
        do {
            try await dbQueue.write { db in
                _ = try TemplateRecord
                    .filter(Column("id") == templateId.uuidString)
                    .deleteAll(db)
            }
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to delete template \(templateId)")
            }
        }
    }
    
    func updateTemplate(_ template: ConversationTemplate) async {
        do {
            try await dbQueue.write { db in
                try TemplateRecord(template).update(db)
            }
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to update template \(template.id)")
            }
        }
    }
}
