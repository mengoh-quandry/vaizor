import Foundation
import GRDB

class WhiteboardRepository {
    private let dbQueue: DatabaseQueue
    
    init(dbQueue: DatabaseQueue = DatabaseManager.shared.dbQueue) {
        self.dbQueue = dbQueue
    }
    
    // MARK: - Create
    
    func save(_ whiteboard: Whiteboard) async throws {
        try await dbQueue.write { db in
            try WhiteboardRecord(whiteboard).save(db)
        }
        await AppLogger.shared.log("Saved whiteboard: \(whiteboard.id)", level: .info)
    }
    
    func create(title: String, conversationId: UUID? = nil) async throws -> Whiteboard {
        let whiteboard = Whiteboard.empty(title: title, conversationId: conversationId)
        try await save(whiteboard)
        return whiteboard
    }
    
    // MARK: - Read
    
    func fetchAll() async throws -> [Whiteboard] {
        try await dbQueue.read { db in
            try WhiteboardRecord
                .order(Column("updated_at").desc)
                .fetchAll(db)
                .map { $0.asModel() }
        }
    }
    
    func fetchById(_ id: UUID) async throws -> Whiteboard? {
        try await dbQueue.read { db in
            try WhiteboardRecord
                .filter(Column("id") == id.uuidString)
                .fetchOne(db)?
                .asModel()
        }
    }
    
    func fetchByConversationId(_ conversationId: UUID) async throws -> [Whiteboard] {
        try await dbQueue.read { db in
            try WhiteboardRecord
                .filter(Column("conversation_id") == conversationId.uuidString)
                .order(Column("updated_at").desc)
                .fetchAll(db)
                .map { $0.asModel() }
        }
    }
    
    func fetchRecent(limit: Int = 20) async throws -> [Whiteboard] {
        try await dbQueue.read { db in
            try WhiteboardRecord
                .order(Column("updated_at").desc)
                .limit(limit)
                .fetchAll(db)
                .map { $0.asModel() }
        }
    }
    
    func searchByTitle(_ query: String) async throws -> [Whiteboard] {
        try await dbQueue.read { db in
            let pattern = "%\(query)%"
            return try WhiteboardRecord
                .filter(Column("title").like(pattern))
                .order(Column("updated_at").desc)
                .fetchAll(db)
                .map { $0.asModel() }
        }
    }
    
    func fetchByTags(_ tags: [String]) async throws -> [Whiteboard] {
        try await dbQueue.read { db in
            let whiteboards = try WhiteboardRecord
                .order(Column("updated_at").desc)
                .fetchAll(db)
                .map { $0.asModel() }
            
            return whiteboards.filter { whiteboard in
                !Set(whiteboard.tags).isDisjoint(with: Set(tags))
            }
        }
    }
    
    // MARK: - Update
    
    func update(_ whiteboard: Whiteboard) async throws {
        try await dbQueue.write { db in
            var record = WhiteboardRecord(whiteboard)
            record.updatedAt = Date()
            try record.update(db)
        }
        await AppLogger.shared.log("Updated whiteboard: \(whiteboard.id)", level: .info)
    }
    
    func updateContent(_ id: UUID, content: String) async throws {
        try await dbQueue.write { db in
            try db.execute(
                sql: "UPDATE whiteboards SET content = ?, updated_at = ? WHERE id = ?",
                arguments: [content, Date().timeIntervalSince1970, id.uuidString]
            )
        }
        await AppLogger.shared.log("Updated whiteboard content: \(id)", level: .info)
    }
    
    func updateTitle(_ id: UUID, title: String) async throws {
        try await dbQueue.write { db in
            try db.execute(
                sql: "UPDATE whiteboards SET title = ?, updated_at = ? WHERE id = ?",
                arguments: [title, Date().timeIntervalSince1970, id.uuidString]
            )
        }
        await AppLogger.shared.log("Updated whiteboard title: \(id)", level: .info)
    }
    
    func updateThumbnail(_ id: UUID, thumbnail: Data?) async throws {
        try await dbQueue.write { db in
            try db.execute(
                sql: "UPDATE whiteboards SET thumbnail = ?, updated_at = ? WHERE id = ?",
                arguments: [thumbnail, Date().timeIntervalSince1970, id.uuidString]
            )
        }
    }
    
    func addTag(_ id: UUID, tag: String) async throws {
        guard let whiteboard = try await fetchById(id) else {
            throw WhiteboardError.notFound
        }
        
        var updatedWhiteboard = whiteboard
        if !updatedWhiteboard.tags.contains(tag) {
            updatedWhiteboard.tags.append(tag)
            updatedWhiteboard.updatedAt = Date()
            try await update(updatedWhiteboard)
        }
    }
    
    func removeTag(_ id: UUID, tag: String) async throws {
        guard let whiteboard = try await fetchById(id) else {
            throw WhiteboardError.notFound
        }
        
        var updatedWhiteboard = whiteboard
        updatedWhiteboard.tags.removeAll { $0 == tag }
        updatedWhiteboard.updatedAt = Date()
        try await update(updatedWhiteboard)
    }
    
    func toggleShared(_ id: UUID) async throws {
        guard let whiteboard = try await fetchById(id) else {
            throw WhiteboardError.notFound
        }
        
        var updatedWhiteboard = whiteboard
        updatedWhiteboard.isShared.toggle()
        updatedWhiteboard.updatedAt = Date()
        try await update(updatedWhiteboard)
    }
    
    // MARK: - Delete
    
    func delete(_ id: UUID) async throws {
        _ = try await dbQueue.write { db in
            try WhiteboardRecord
                .filter(Column("id") == id.uuidString)
                .deleteAll(db)
        }
        await AppLogger.shared.log("Deleted whiteboard: \(id)", level: .info)
    }
    
    func deleteByConversationId(_ conversationId: UUID) async throws {
        _ = try await dbQueue.write { db in
            try WhiteboardRecord
                .filter(Column("conversation_id") == conversationId.uuidString)
                .deleteAll(db)
        }
        await AppLogger.shared.log("Deleted whiteboards for conversation: \(conversationId)", level: .info)
    }
    
    func deleteAll() async throws {
        _ = try await dbQueue.write { db in
            try WhiteboardRecord.deleteAll(db)
        }
        await AppLogger.shared.log("Deleted all whiteboards", level: .warning)
    }
    
    // MARK: - Statistics
    
    func count() async throws -> Int {
        try await dbQueue.read { db in
            try WhiteboardRecord.fetchCount(db)
        }
    }
    
    func countByConversationId(_ conversationId: UUID) async throws -> Int {
        try await dbQueue.read { db in
            try WhiteboardRecord
                .filter(Column("conversation_id") == conversationId.uuidString)
                .fetchCount(db)
        }
    }
    
    // MARK: - Export/Import
    
    func export(_ id: UUID, to url: URL, format: ExportFormat) async throws {
        guard let whiteboard = try await fetchById(id) else {
            throw WhiteboardError.notFound
        }
        
        switch format {
        case .json:
            let data = try JSONEncoder().encode(whiteboard)
            try data.write(to: url)
            
        case .excalidraw:
            let data = whiteboard.content.data(using: .utf8) ?? Data()
            try data.write(to: url)
        }
        
        await AppLogger.shared.log("Exported whiteboard \(id) to \(url.path)", level: .info)
    }
    
    func `import`(from url: URL) async throws -> Whiteboard {
        let data = try Data(contentsOf: url)
        
        // Try to decode as full Whiteboard first
        if let whiteboard = try? JSONDecoder().decode(Whiteboard.self, from: data) {
            try await save(whiteboard)
            return whiteboard
        }
        
        // Otherwise, treat as Excalidraw JSON content
        guard let content = String(data: data, encoding: .utf8) else {
            throw WhiteboardError.invalidContent
        }
        
        let whiteboard = Whiteboard(
            title: url.deletingPathExtension().lastPathComponent,
            content: content
        )
        
        try await save(whiteboard)
        return whiteboard
    }
}

// MARK: - Export Format

enum ExportFormat {
    case json       // Full Whiteboard model
    case excalidraw // Just the Excalidraw content
}
